# UHF Media — réécriture Flutter : spécification de conception

- Date : 2026-10-01
- Statut : en relecture
- Remplace : `video_studio_player.py` (PyQt5 + libmpv), déplacé et conservé dans `legacy/`

## 1. Objectif

Réécrire l'application en application Flutter native pour Windows, avec une parité fonctionnelle complète avec le script Python, quatre ajouts validés, et une interface minimaliste, moderne et élégante qui ne ressemble pas à un design généré par IA.

### Critères de réussite

1. Toutes les fonctions de l'inventaire (section 3) fonctionnent dans l'application Flutter.
2. `flutter build windows --release` produit un dossier autonome (exe, libmpv, ffmpeg, ffprobe) ; l'installeur Inno Setup l'installe sans droits administrateur.
3. Interface cohérente avec la direction visuelle « Signal » (section 6), sans emoji, en turc, français et anglais.
4. La logique pure est couverte par des tests unitaires ; `flutter analyze` et `flutter test` passent en CI.

### Hors périmètre

- macOS, Linux, mobile, web.
- Choix d'une licence pour le dépôt (décision du propriétaire, à prendre séparément).
- Toute fonction absente du script Python et non listée en section 4.

## 2. Décisions techniques

| Sujet | Choix | Raison |
|---|---|---|
| Plateforme | Windows 10/11 x64 uniquement | Cible actuelle ; code spécifique Windows isolé derrière des interfaces |
| Framework | Flutter 3.41 stable, Dart 3.11 | Version installée |
| Moteur vidéo | `media_kit` 1.2.x + `media_kit_video` + `media_kit_libs_video` | libmpv, comme le Python : les propriétés mpv se transposent telles quelles via `NativePlayer.setProperty/getProperty/command`. Rendu en texture : les surcouches sont des widgets Flutter |
| Reconnaissance musicale | Port Dart de `shazamio-core` (MIT) + client HTTP de l'endpoint utilisé par `shazamio` | Pas de chaîne native ; vérifiable octet par octet contre l'implémentation Python |
| État | `ChangeNotifier` / `ValueNotifier` intégrés | Une fenêtre, un lecteur ; Riverpod 3.4 exigerait Dart 3.12 |
| Fenêtre | `window_manager` | Barre de titre masquée (bordure et coins Windows 11 conservés), toujours au premier plan, plein écran |
| Instance unique | `windows_single_instance` | Transmet les arguments de la 2ᵉ instance à la première |
| Glisser-déposer | `desktop_drop` | |
| Dialogue de fichier | `file_picker` | |
| FFT | `fftea` | Pur Dart |
| HTTP | `http` | Client injectable pour les tests |
| Dossiers | `path_provider` + `win32` (`SHGetKnownFolderPath`, `FOLDERID_Desktop`) | Bureau réel, OneDrive compris |
| Traductions | `flutter_localizations` + gen-l10n, ARB tr / fr / en | Langue système par défaut, repli anglais, choix manuel possible |
| Persistance | Fichiers JSON dans `%APPDATA%\UHF Media\` | Aucune dépendance |
| ffmpeg / ffprobe | Build BtbN GPL partagé, version figée | libx264 + NVENC / QSV / AMF |
| Installeur | Inno Setup 6, installation par utilisateur | Pas d'UAC ; associations dans HKCU |
| Nom | « UHF Media », exe `uhf_media.exe` | Remplace « HuluMedia » et « VideoStudioPlayer » |

Risques connus :

- `media_kit` : dernière publication pub.dev en décembre 2025, un seul mainteneur actif. Le reste de l'application ne dépend de media_kit qu'à travers `PlayerService`, ce qui permet un remplacement localisé si nécessaire.
- L'endpoint Shazam n'est pas officiel (même situation que le script Python) et peut changer sans préavis. L'échec est géré comme une erreur réseau ; le fichier n'est jamais modifié.

## 3. Inventaire de parité (repris du script Python)

### Lecture

- Ouverture par dialogue, glisser-déposer et argument de ligne de commande.
- Instance unique : une 2ᵉ instance transmet son fichier à la fenêtre existante et la ramène au premier plan.
- Lecture / pause, barre de progression cliquable, saut de ±3 s.
- Volume (curseur, molette ±5).
- Sélection de la piste audio.
- Sous-titres : pistes internes, désactivés par défaut à l'ouverture, ajout d'un fichier externe par glisser-déposer, taille (50–300 %) et position (0–100) réglables en direct avec annulation.
- Mono gauche / droite (`af=lavfi=[pan=stereo|c0=c0|c1=c0]` et équivalent droit), réinitialisé à chaque ouverture.
- Désentrelacement de lecture activé seulement si la source est entrelacée.
- En fin de fichier : retour au début, en pause.
- Capture PNG avec sous-titres sur le Bureau.
- Plein écran (double-clic, Échap pour quitter), masquant toute l'interface.
- Toujours au premier plan.
- Fenêtre sans barre de titre native, déplaçable, redimensionnable, double-clic sur la barre pour agrandir.
- Écran d'accueil « UHF » (police pixel 5×7, barre de signal jaune dont le dernier trait clignote toutes les 500 ms).

### Studio

- Rotation 90° horaire, 90° antihoraire, 180°, avec aperçu en direct (`video-rotate`).
- Recadrage : cadre déplaçable et redimensionnable (8 poignées + déplacement), cadre par défaut à 70 % centré, taille minimale 20 px, affichage des dimensions de sortie et du ratio réduit.
- Découpe : plage sur la timeline, poignées d'entrée et de sortie, déplacement de la plage entière, clic hors plage qui déplace la poignée la plus proche, écart minimal 0,5 % de la durée, aperçu en direct pendant le glissement (pause + saut), réglage ±1 s, plage initiale de 60 s depuis la position de lecture, affichage HH:MM:SS.
- Export ffmpeg en une seule passe :
  - filtres dans l'ordre : `yadif` (si besoin), `crop`, rotation (`transpose=1`, `transpose=2`, `hflip,vflip`) ;
  - recadrage converti de l'espace affiché vers les pixels source non tournés, dimensions paires, bornées à l'image ;
  - source entrelacée sans rotation : entrelacement conservé (`-flags:v +ildct+ilme`, `-x264opts tff=1|bff=1`, `-r` source, `-fps_mode cfr`), y du recadrage pair, hauteur multiple de 4, CPU obligatoire ;
  - source entrelacée avec rotation : `yadif=mode=send_field:parity=auto:deint=interlaced` en tête, sortie progressive ;
  - encodeur matériel détecté une fois (`h264_nvenc` > `h264_qsv` > `h264_amf`), utilisé seulement si le débit source est connu, la source en 8 bits et non entrelacée à conserver ; `format=yuv420p` ajouté au filtre ; `-rc:v vbr -preset p4` pour NVENC ;
  - débit source conservé (`-b:v`, `-maxrate`, `-bufsize` = 2 × débit ; `-minrate` en CPU, `-preset medium`) ; débit inconnu : `libx264 -crf 16 -preset slow` ;
  - découpe : un seul `-ss` avant `-i`, `-t` après ;
  - pistes : vidéo sélectionnée et audio sélectionnée par leur `ff-index` mpv, sous-titres conservés ; `-c:a copy`, `-map_metadata 0`, `-pix_fmt yuv420p` ;
  - échec en encodage matériel : nouvel essai automatique en CPU ; annulation : pas de nouvel essai.
- Message si aucune modification n'est sélectionnée ; refus si la découpe dure moins de 0,1 s ou si le recadrage fait moins de 2 px.

### Musique

- Extraction de 10 s depuis la position de lecture avec ffmpeg.
- Silence (RMS < 0,01) : pas d'envoi, résultat « non reconnu ».
- Reconnaissance Shazam en arrière-plan.
- Renommage optionnel en `Artiste - Titre.ext`, caractères `\/*?:"<>|` retirés, suffixe ` (n)` en cas de collision, aucun renommage si le nom est identique.
- Aucune modification du fichier en cas d'échec, de silence ou d'absence de résultat.

## 4. Ajouts validés

1. **Installeur et association de fichiers** : Inno Setup, installation par utilisateur dans `%LOCALAPPDATA%\Programs\UHF Media`, raccourci menu Démarrer, désinstalleur, ProgID `UHFMedia.Video` avec commande `"{app}\uhf_media.exe" "%1"`, `OpenWithProgids` pour mp4, mkv, mov, avi, m4v, webm, `Applications\uhf_media.exe\SupportedTypes`. Windows 10/11 interdit de s'imposer comme application par défaut : l'utilisateur confirme une fois via « Ouvrir avec ».
2. **Ratios de recadrage** : Libre, 16:9, 9:16, 1:1, 4:3. Le ratio s'applique à l'image de sortie (après rotation). Changer de ratio recentre un cadre au plus grand dans 70 % de l'image ; les poignées conservent le ratio.
3. **Réglages mémorisés** : volume, coupure du son, taille et position des sous-titres, taille / position / état agrandi de la fenêtre, toujours au premier plan, langue, renommage automatique, dernier dossier ouvert.
4. **Reprise de lecture** : position par chemin absolu, sauvegardée toutes les 5 s, au changement de fichier et à la fermeture ; appliquée si elle est à plus de 10 s du début et à plus de 30 s de la fin ; effacée en fin de fichier ; 500 entrées au plus, les plus anciennes supprimées ; clé migrée lors d'un renommage par l'identification musicale.

## 5. Améliorations et corrections par rapport au Python

- Renommage pendant la lecture : si Windows refuse (fichier ouvert par le lecteur), le lecteur ferme le fichier, renomme, puis rouvre à la même position et dans le même état de lecture.
- Conteneur de sortie : `.mp4` pour les sources mp4, mov, m4v ; `.mkv` pour toutes les autres (H.264 n'est pas valide en webm).
- Sous-titres en sortie mp4 : pistes texte converties en `mov_text`, pistes image (PGS, VobSub) ignorées ; en mkv, copie.
- Suffixes de sortie neutres : `_crop`, `_rot90`, `_rot270`, `_rot180`, `_trim`, combinés dans cet ordre ; suffixe ` (n)` si le fichier existe.
- Progression réelle de l'export (`-progress pipe:1`) avec pourcentage, temps restant et annulation, sans fenêtre modale.
- Fichiers de sous-titres externes acceptés : `.srt`, `.ass`, `.ssa`, `.vtt`.
- Dialogue d'ouverture : vidéos (mp4, mkv, mov, avi, m4v, webm, ts, mts, m2ts, wmv, flv) et audio (mp3, flac, m4a, wav, ogg, opus).
- Lectures ffprobe regroupées en un seul appel JSON (`-show_streams -show_format`).
- Avancer ou reculer d'une image (`frame-step`, `frame-back-step`).

## 6. Direction visuelle « Signal »

### Principe

La vidéo domine, l'interface s'efface. L'identité vient de l'écran UHF existant (télévision analogique, matériel de régie), employée avec retenue : l'écran d'accueil est le seul moment de couleur vive.

### Jetons

| Jeton | Valeur | Usage |
|---|---|---|
| `ink` | `#0D0D0C` | Fond de fenêtre, fond vidéo |
| `surface` | `#161614` | Panneaux |
| `raised` | `#1F1E1B` | Menus, cartes de résultat |
| `line` | `#2B2A27` | Filets 1 px, pistes de curseurs |
| `text` | `#ECE9E2` | Texte principal, icônes actives |
| `textMuted` | `#8C8981` | Texte secondaire, icônes au repos |
| `signal` | `#E8412C` | Seul accent : tête de lecture, plage de découpe, réglages actifs, bouton Exporter |
| `signalYellow` | `#F5D90A` | Écran d'accueil uniquement |
| `danger` | `#E8412C` sur `raised` + libellé explicite | Erreurs (pas de second rouge) |

- Typographie : IBM Plex Sans (interface, 400 et 500), IBM Plex Mono (timecodes, dimensions, débits, pourcentages), police pixel 5×7 pour le logo. Polices OFL embarquées en assets. Corps de base 13 px, petits libellés 11 px.
- Icônes : Material Symbols Sharp, graisse 300, 18 px (paquet `material_symbols_icons`). Boutons de fenêtre dessinés (traits 1 px).
- Formes : rayon 2–3 px ; ni ombre, ni dégradé, ni flou, ni lueur.
- Mouvement : 120–160 ms, `Curves.easeOut`, fondus et glissements de 4–8 px ; aucun rebond.
- Interdits : dégradés violets, verre dépoli, cartes très arrondies avec ombre, Inter, Lucide, emoji, texte en dégradé, pilules décoratives.

### Organisation de l'écran

- **Barre de titre** (30 px) : nom du fichier centré en `textMuted` ; à droite, épingler, réduire, agrandir, fermer (survol de fermer en `signal`). Zone de déplacement sur toute la largeur restante.
- **Mode Lecture** : vidéo plein cadre. Contrôles superposés en bas, sur un voile `ink` à 90 %, masqués après 2,5 s sans mouvement de souris pendant la lecture, toujours visibles en pause :
  - timeline pleine largeur (2 px, 4 px au survol, progression en `signal`, tête de lecture blanche, infobulle de temps au survol) ;
  - lecture / pause, timecode mono `00:41:12 / 01:48:30`, espace, volume, piste audio, sous-titres, menu ⋯, bouton Studio, plein écran.
  - Menu ⋯ : capture, identifier la musique, mono G / D, réglages des sous-titres, renommage automatique, toujours au premier plan, langue.
- **Mode Studio** (bouton ou `E`) : panneau ancré sous la vidéo (la vidéo se réduit, rien ne la recouvre) :
  - timeline avec plage de découpe (remplissage `signal` à 25 %, bords `signal` 2 px), entrée / sortie en mono avec −1 s / +1 s, durée de la plage ;
  - rangée : rotation (0°, 90°, −90°, 180°), cadre (désactivé, Libre, 16:9, 9:16, 1:1, 4:3), dimensions de sortie, bouton Exporter ;
  - pendant l'export, la rangée laisse place à une barre de progression, au pourcentage, au temps restant et à Annuler.
- **Cadre de recadrage** : extérieur voilé (`ink` à 70 %), contour 1 px `text`, poignées d'angle en équerre, poignées de côté en traits courts, lignes des tiers pendant le déplacement, étiquette mono `1080 × 1920 · 9:16` au-dessus du cadre.
- **Écran d'accueil** : logo UHF pixel en `signal`, barre de signal en `signalYellow`, invite « Glisse une vidéo ici · Ctrl+O » en `textMuted`.
- **Messages** : en bas à gauche, sur `raised`, une ligne, une action optionnelle, disparition après 4 s (8 s s'il y a une action).
- **Carte de musique** : en bas à gauche, artiste et titre, actions *Renommer le fichier* et *Copier* (ou *Annuler* après renommage automatique).

## 7. Raccourcis clavier

| Touche | Action |
|---|---|
| `Espace` | Lecture / pause |
| `←` / `→` | −3 s / +3 s |
| `Shift+←` / `Shift+→` | Image précédente / suivante |
| `↑` / `↓`, molette | Volume ±5 |
| `M` | Couper le son |
| `F`, double-clic | Plein écran |
| `Échap` | Quitter le plein écran, fermer le menu ouvert |
| `Ctrl+O` | Ouvrir |
| `S` | Capture |
| `Ctrl+I` | Identifier la musique |
| `Ctrl+T` | Toujours au premier plan |
| `E` | Mode Studio |
| `I` / `O` (Studio) | Entrée / sortie de découpe à la position de lecture |
| `R` (Studio) | Rotation suivante |
| `C` (Studio) | Recadrage activé / désactivé |
| `Ctrl+E` (Studio) | Exporter |

Les contrôles ne prennent pas le focus clavier : les raccourcis s'appliquent toujours à la fenêtre (comportement du Python).

## 8. Architecture

```
lib/
  main.dart                  instance unique, window_manager, chargement des réglages, arguments
  app/                       UhfApp (MaterialApp), thème, l10n, raccourcis (Shortcuts/Actions)
  core/
    media/                   PlayerService (façade media_kit), TrackInfo, parseTrackList
    ffmpeg/                  FfmpegLocator, ProbeService + ProbeResult, ExportPlan,
                             ExportCommandBuilder (pur), ExportRunner, HwEncoderDetector
    shazam/                  SignatureGenerator (pur), signature_format, ShazamClient, Recognizer
    geometry/                CropMath (pur), AspectPreset, Rotation
    settings/                SettingsStore, ResumeStore (JSON, écriture atomique)
    files/                   SafeRename (pur pour le calcul du nom), KnownFolders, revealInExplorer
    util/                    formatage des temps, ratio réduit, journal
  features/
    shell/                   ShellController, TitleBar, IdleScreen, DropZone, plein écran
    player/                  PlayerController, VideoStage, ControlsOverlay, Timeline,
                             VolumeControl, TrackMenus, SubtitleSettingsSheet
    studio/                  StudioController, StudioPanel, TrimTimeline, CropOverlay, ExportBar
    music_id/                MusicIdController, ResultCard
  ui/                        tokens, typographie, icônes, UhfButton, UhfChip, UhfSlider,
                             UhfMenu, UhfToast
  l10n/                      app_en.arb (modèle), app_fr.arb, app_tr.arb
assets/fonts/                IBM Plex Sans, IBM Plex Mono (+ licences OFL)
test/                        miroir de lib/ ; fixtures/ (JSON ffprobe, WAV, signatures)
tool/                        fetch_ffmpeg.ps1, gen_signature_fixtures.py
third_party/ffmpeg/          ffmpeg.exe, ffprobe.exe, DLL (exclu de git)
windows/                     runner ; CMake copie third_party/ffmpeg dans le bundle
installer/                   uhf_media.iss
legacy/                      video_studio_player.py, README d'origine
```

### Flux

L'interface écoute des contrôleurs (`ChangeNotifier`). Les contrôleurs appellent des services. Les services encapsulent media_kit, les processus ffmpeg / ffprobe, HTTP et le système de fichiers. Les modules purs (`CropMath`, `ExportCommandBuilder`, `SignatureGenerator`, `SafeRename`, formatage) n'importent ni Flutter ni `dart:io` et se testent directement.

### Interfaces clés

- `PlayerService` : `open(path)`, `play/pause/toggle`, `seek(Duration)`, `seekRelative`, `frameStep(forward)`, `setVolume`, `setMute`, `setAudioTrack(id)`, `setSubtitleTrack(id | off)`, `addSubtitle(path)`, `setSubtitleScale/Pos`, `setPan(PanMode)`, `setRotation(Rotation)`, `setDeinterlace(bool)`, `screenshotTo(path)`, `close()` ; flux `position`, `duration`, `playing`, `completed`, `videoSize`, `tracks` ; `readTrackList()` lit `track-list/N/{type,id,ff-index,selected,title,lang}`.
- `ProbeService.probe(path) → ProbeResult` : débit vidéo (flux puis conteneur), ordre de trame (`tff` / `bff` / progressif), fréquence d'images en fraction, profondeur de bits (`bits_per_raw_sample` puis `pix_fmt`), liste des flux de sous-titres avec type texte / image.
- `ExportCommandBuilder.build(ExportPlan, ProbeResult, EncoderChoice) → List<String>` : fonction pure, aucune I/O.
- `ExportRunner.run(args, totalDuration) → Stream<ExportProgress>` + `cancel()`.
- `SignatureGenerator.fromPcm16kMono(Int16List) → Uint8List` (format binaire de signature Shazam) et `dataUri`.
- `ShazamClient.recognize(signature, sampleMs) → RecognitionResult?` (titre, artiste).
- `CropMath.displayToSource(cropRatio, rotation, sourceSize, {preserveInterlace}) → IntRect` ; `CropMath.fitPreset(preset, displaySize) → Rect`.

### Instance unique et arguments

`main` appelle `WindowsSingleInstance.ensureSingleInstance(args, 'uhf_media', onSecondWindow: …)` avant de créer la fenêtre. Le rappel ramène la fenêtre au premier plan et ouvre le fichier reçu s'il existe.

### Extraction audio pour Shazam

`ffmpeg -v error -ss <pos> -t 10 -i <fichier> -ac 1 -ar 16000 -f s16le -` : sortie directement en 16 kHz mono 16 bits, sans rééchantillonnage en Dart. Le seuil de silence est calculé sur ces échantillons normalisés.

## 9. Gestion des erreurs

| Cas | Comportement |
|---|---|
| ffmpeg ou ffprobe absent | Lecture normale ; le panneau Studio et l'identification indiquent le dossier attendu |
| libmpv ne se charge pas | Écran d'erreur au démarrage avec le chemin attendu |
| Fichier illisible | Message ; le fichier précédent reste ouvert |
| Export : échec GPU | Nouvel essai CPU automatique, signalé en une ligne |
| Export : échec CPU | Message lisible + *Copier le détail* (fin de la sortie ffmpeg) |
| Export : annulation | Fichier partiel supprimé ; message « Export annulé » |
| Shazam : réseau, silence, aucun résultat | Message ; fichier intact |
| Renommage refusé après fermeture du fichier | Message ; réouverture du fichier d'origine à la même position |
| JSON de réglages corrompu | Réglages par défaut ; fichier corrompu renommé `.bak` |

Messages : une phrase, sans exception brute, à la deuxième personne, sans point d'exclamation. Journal tournant dans `%APPDATA%\UHF Media\logs\` (5 fichiers de 1 Mo).

## 10. Tests

### Unitaires

- `CropMath` : quatre rotations, chaque ratio, dimensions paires, bornes, ajustements entrelacés (y pair, hauteur multiple de 4), valeurs connues issues du Python.
- `ExportCommandBuilder` : commandes de référence pour GPU, CPU avec et sans débit, entrelacé conservé, désentrelacé avec rotation, 10 bits, découpe, sortie mp4 avec sous-titres texte et image, sortie mkv.
- `SignatureGenerator` : signatures identiques octet par octet à celles de `shazamio-core` (Python, `.venv`) pour trois WAV de test générés par `tool/gen_signature_fixtures.py` (ton, bruit, mélange).
- `ShazamClient` : requête construite (URL, corps JSON) et analyse des réponses (trouvé, non trouvé, erreur) avec un client HTTP simulé.
- `SafeRename`, formatage des temps, ratio réduit, `parseTrackList`, analyse du JSON ffprobe, `SettingsStore`, `ResumeStore` (seuils, limite de 500, migration de clé).

### Widgets

- Timeline de découpe : glissements, clic hors plage, écart minimal, réglage ±1 s.
- Cadre de recadrage : poignées, déplacement, bornes, verrouillage du ratio.
- Contrôles : masquage après 2,5 s en lecture, visibles en pause.

### CI

GitHub Actions, `windows-latest` : `flutter pub get`, `flutter analyze`, `flutter test`.

### Recette manuelle

MKV multi-pistes audio, vidéo entrelacée (DV ou TS), HEVC 10 bits, vidéo verticale de téléphone, sous-titres glissés, recadrage + rotation + découpe combinés, renommage pendant la lecture, 2ᵉ instance, reprise de lecture, installation et « Ouvrir avec ».

## 11. Build et distribution

- `tool/fetch_ffmpeg.ps1` : télécharge une version BtbN figée (`win64-gpl-shared`), vérifie le SHA-256, extrait `ffmpeg.exe`, `ffprobe.exe` et les DLL dans `third_party/ffmpeg/`.
- CMake (`windows/CMakeLists.txt`) : installe le contenu de `third_party/ffmpeg/` à côté de l'exe s'il est présent.
- `flutter build windows --release` → `build/windows/x64/runner/Release/`.
- `installer/uhf_media.iss` : prend ce dossier, version lue depuis `pubspec.yaml`. Prérequis : `winget install JRSoftware.InnoSetup`.
- Documentation : README réécrit (anglais), `THIRD_PARTY_NOTICES.md` (ffmpeg GPL avec lien vers les sources, `shazamio-core` MIT, media_kit MIT, polices OFL, Material Symbols Apache 2.0).
- `.gitignore` : ajout de `third_party/ffmpeg/`, `build/`, `.dart_tool/`, sorties de l'installeur.

## 12. Organisation du dépôt

- Projet Flutter à la racine.
- `video_studio_player.py` et l'ancien README déplacés dans `legacy/` et conservés.
- `CLAUDE.md` : aucune mention de Claude comme co-auteur dans les commits et PR.
