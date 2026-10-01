# UHF Media — Plan 3 : Studio et identification musicale

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Livrer le mode Studio (rotation avec aperçu, découpe sur la timeline, cadre de recadrage avec ratios, export ffmpeg avec progression, annulation et repli CPU) et l'identification musicale (extraction 10 s, reconnaissance Shazam, carte de résultat, renommage pendant la lecture).

**Architecture:** Les règles pures restent dans `lib/core` (`TrimSelection` dans `features/studio` car propre à l'interface, `dragCrop`, `ProgressParser`, `ExportCommandBuilder`). Les processus vivent dans `lib/core/system` derrière deux interfaces, `Exporter` (`ExportService`) et `MusicIdentifier` (`MusicRecognizer`), simulées dans les tests. L'état vit dans `StudioController` et `MusicIdController` (`ChangeNotifier`), qui émettent des événements traduits en messages par `AppShell`. `PlayerController` gagne la rotation, le résultat ffprobe, les `ff-index` sélectionnés et le renommage du fichier ouvert.

**Tech Stack:** Flutter 3.41.4, Dart 3.11.1, paquets du plan 2 (aucun nouveau), ffmpeg / ffprobe externes, `http` (déjà présent) pour Shazam.

**Spec:** `docs/superpowers/specs/2026-10-01-uhf-media-flutter-design.md` (sections 3 « Studio » et « Musique », 4.2, 4.4, 5, 6 « Mode Studio », « Cadre de recadrage », « Carte de musique », 7, 8, 9).

## Global Constraints

- Tout ce qui figure dans « Global Constraints » des plans 1 et 2 s'applique (couleurs, polices, rayons 2–3 px, ni ombre ni dégradé ni emoji, tr/fr/en, Conventional Commits sans `Co-Authored-By`, contrôles sans focus clavier).
- `lib/core/{geometry,ffmpeg,files,shazam,util,media}` n'importent ni `package:flutter` ni `dart:io` (sauf `media_kit_engine.dart`). Les processus sont dans `lib/core/system`.
- `signal` (#E8412C) est le seul accent : plage de découpe (remplissage 25 %, bords 2 px), réglages actifs, bouton Exporter. Cadre de recadrage : extérieur `ink` à 70 %, contour 1 px `text`, poignées d'angle en équerre, poignées de côté en traits courts, lignes des tiers pendant le déplacement, étiquette mono `1080 × 1920 · 9:16`.
- Raccourcis livrés ici (spec §7) : `E` (Studio), `I` / `O` (entrée / sortie, Studio), `R` (rotation suivante, Studio), `C` (cadre, Studio), `Ctrl+E` (exporter, Studio), `Ctrl+I` (identifier la musique). Les bascules (`E`, `R`, `C`) utilisent `includeRepeats: false`.
- Découpe : écart minimal 0,5 % de la durée, réglage ±1 s, plage initiale de 60 s depuis la position de lecture, aperçu pendant le glissement (pause + saut). Cadre : 70 % centré par défaut, 20 px minimum, ratios Libre, 16:9, 9:16, 1:1, 4:3 appliqués à l'image de sortie.
- Export : un seul `-ss` avant `-i`, sortie `_crop` / `_rot90` / `_rot270` / `_rot180` / `_trim` (ordre fixe), ` (n)` si le fichier existe, échec GPU → nouvel essai CPU automatique sauf annulation, fichier partiel supprimé à l'annulation et à l'échec.
- Musique : `ffmpeg -v error -ss <pos> -t 10 -i <fichier> -ac 1 -ar 16000 -f s16le -` ; silence (RMS < 0,01) → « non reconnu » sans requête ; le fichier n'est jamais modifié en cas d'échec ; renommage `Artiste - Titre.ext` via `renameTarget` (plan 1).
- Renommage pendant la lecture : essai direct ; si Windows refuse, fermer, renommer, rouvrir à la même position et dans le même état de lecture ; si le renommage échoue encore, rouvrir l'original à la même position. Clé de reprise migrée.
- Messages : une phrase, deuxième personne, sans point d'exclamation, sans exception brute.

## Review Focus

1. **Ouvrir un autre fichier pendant un export** : l'export continue sur le fichier d'origine, la progression reste affichée, les réglages Studio (rotation, découpe, cadre) repartent de zéro pour le nouveau fichier. Test dans la tâche 10.
2. **Annuler avant que ffmpeg ait démarré** (clic sur *Annuler* juste après *Exporter*) : ffmpeg est tué dès qu'il démarre, aucun nouvel essai CPU, fichier partiel supprimé. Tests dans les tâches 4 et 5.
3. **Rotation avec un cadre actif** : le cadre est recentré au ratio choisi dans l'image tournée ; il ne déborde jamais de l'image et la sortie garde le ratio. Test dans la tâche 9.
4. **Fichier sans vidéo** (mp3, flac) : le Studio reste fermé (bouton désactivé, `E` sans effet) ; l'identification musicale fonctionne. Tests dans les tâches 9 et 16.
5. **Résultat musical arrivé après l'ouverture d'un autre fichier** : la carte concerne le fichier identifié ; *Renommer le fichier* ne renomme jamais le fichier ouvert entre-temps. Test dans la tâche 16.

---

## File Structure

| Fichier | Responsabilité |
|---|---|
| `lib/core/system/process_runner.dart` | Retour au mode normal (code de sortie conservé) |
| `lib/core/ffmpeg/probe_result.dart` | + `videoSize`, `audioStreams` (`AudioStreamInfo`) |
| `lib/core/ffmpeg/export_command_builder.dart` | `isMp4Family` partagé, audio FLAC pour LPCM Blu-ray / DVD en mkv |
| `lib/core/ffmpeg/export_progress.dart` | `ProgressParser` (lignes `-progress pipe:1`) |
| `lib/core/geometry/crop_math.dart` | + `displayedPictureSize` |
| `lib/core/geometry/crop_drag.dart` | `CropHandle`, `dragCrop` (poignées, déplacement, bornes, ratio) |
| `lib/core/system/export_runner.dart` | `ExportRunner`, `ExportJob`, `ExportOutcome` |
| `lib/core/system/export_service.dart` | `ExportInput`, interface `Exporter`, `ExportService` (encodeur matériel, nom de sortie, repli CPU) |
| `lib/core/system/music_recognizer.dart` | `MusicOutcome`, interface `MusicIdentifier`, `MusicRecognizer`, `pcm16FromBytes` |
| `lib/l10n/app_{en,fr,tr}.arb` | Textes Studio et musique |
| `lib/features/player/player_controller.dart` | + rotation, `probe`, `videoFfIndex` / `audioFfIndex`, `pause`, `renameOpenFile` |
| `lib/features/studio/trim_selection.dart` | `TrimSelection`, `TrimHandle` (pur) |
| `lib/features/studio/studio_controller.dart` | `StudioController`, `StudioEvent`, `ExportProgress` |
| `lib/features/studio/trim_timeline.dart` | Timeline de découpe |
| `lib/features/studio/crop_overlay.dart` | Cadre de recadrage |
| `lib/ui/uhf_chip.dart` | Puce à état (rotation, découpe) |
| `lib/features/studio/studio_panel.dart` | Panneau ancré + barre d'export |
| `lib/features/music_id/music_id_controller.dart` | `MusicIdController`, `MusicCard`, `MusicEvent` |
| `lib/features/music_id/music_result_card.dart` | Carte de résultat |
| `lib/features/player/controls_overlay.dart`, `player_menus.dart` | Bouton Studio, entrées musique (paramètres optionnels) |
| `lib/features/shell/app_shell.dart`, `lib/main.dart` | Assemblage, raccourcis, messages |
| `test/support/fake_process.dart`, `fake_exporter.dart`, `fake_music_identifier.dart` | Doublures |
| `tool/make_sample_media.ps1` | + vidéo verticale, HEVC 10 bits, m2ts LPCM |

---

### Task 1: Lanceur de processus en mode normal

Au plan 2, `defaultProcessRunner` est passé en `ProcessStartMode.detachedWithStdio` pour éviter une console supposée. Un essai (2026-10-01) avec un parent au sous-système GUI montre que `Process.run` en mode normal ne donne **aucune** console à l'enfant. Le mode détaché perd le code de sortie (toujours 0) et PowerShell n'y démarre pas. On revient au mode normal.

**Files:**
- Modify: `lib/core/system/process_runner.dart`
- Test: `test/core/system/process_runner_test.dart`

**Interfaces:**
- Produces: `defaultProcessRunner` renvoie le vrai code de sortie.

- [ ] **Step 1: Écrire le test**

`test/core/system/process_runner_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/system/process_runner.dart';

void main() {
  test('defaultProcessRunner reports the exit code', () async {
    final r = await defaultProcessRunner('cmd', ['/c', 'exit 3']);
    expect(r.exitCode, 3);
  });

  test('defaultProcessRunner captures stdout', () async {
    final r = await defaultProcessRunner('cmd', ['/c', 'echo hi']);
    expect((r.stdout as String).trim(), 'hi');
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/system/process_runner_test.dart`
Expected: FAIL sur le premier test, `Expected: <3> Actual: <0>`.

- [ ] **Step 3: Remplacer `lib/core/system/process_runner.dart`**

```dart
import 'dart:convert';
import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Process.run from a GUI app gives console children no window at all
/// (checked 2026-10-01 with a GUI-subsystem parent), so the normal mode is
/// safe, keeps the exit code, and lets PowerShell start.
Future<ProcessResult> defaultProcessRunner(String executable, List<String> arguments) =>
    Process.run(executable, arguments, stdoutEncoding: utf8, stderrEncoding: utf8);
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/system/process_runner.dart test/core/system/process_runner_test.dart
git commit -m "fix(system): run tools in normal mode to keep their exit code"
```

---

### Task 2: Taille d'image, pistes audio et audio de secours en mkv

**Files:**
- Modify: `lib/core/ffmpeg/probe_result.dart`, `lib/core/ffmpeg/export_command_builder.dart`, `lib/core/geometry/crop_math.dart`
- Test: `test/core/ffmpeg/probe_media_info_test.dart`, `test/core/ffmpeg/export_audio_test.dart`, `test/core/geometry/displayed_picture_size_test.dart`

**Interfaces:**
- Consumes: `IntSize`, `Rotation`, `CropMath.displaySize`, `isMp4Family` (plan 1).
- Produces:
  - `class AudioStreamInfo { const AudioStreamInfo({required int index, required String codec}); }`
  - `ProbeResult` : nouveaux champs optionnels `IntSize? videoSize` (1ᵉʳ flux vidéo, pixels codés) et `List<AudioStreamInfo> audioStreams` (défaut `const []`).
  - `CropMath.displayedPictureSize(IntSize? reported, IntSize source, Rotation r) → IntSize` : taille de l'image affichée. media_kit rapporte la taille d'affichage (rapport d'aspect corrigé), rotation appliquée ou non selon la version de mpv ; on la retourne si son orientation ne correspond pas à la rotation.
  - `ExportCommandBuilder.build` : `-c:a flac` quand la sortie n'est pas de la famille MP4 et que la piste audio choisie est `pcm_bluray` ou `pcm_dvd` (refusées par Matroska) ; `-c:a copy` sinon.

- [ ] **Step 1: Écrire les tests**

`test/core/ffmpeg/probe_media_info_test.dart` :

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/geometry.dart';

void main() {
  test('reads the picture size and the audio codecs', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
        {'index': 1, 'codec_type': 'audio', 'codec_name': 'pcm_bluray'},
        {'index': 2, 'codec_type': 'audio', 'codec_name': 'ac3'},
      ],
      'format': <String, dynamic>{},
    }));
    expect(r.videoSize, const IntSize(1920, 1080));
    expect(r.audioStreams.map((a) => '${a.index}:${a.codec}'), ['1:pcm_bluray', '2:ac3']);
  });

  test('an audio-only file has no picture size', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'audio', 'codec_name': 'mp3'},
      ],
      'format': {'duration': '200.0'},
    }));
    expect(r.videoSize, isNull);
  });

  test('zero or missing dimensions give no picture size', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'video', 'width': 0},
      ],
      'format': <String, dynamic>{},
    }));
    expect(r.videoSize, isNull);
  });
}
```

`test/core/ffmpeg/export_audio_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_command_builder.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

ProbeResult _probe(List<AudioStreamInfo> audio) => ProbeResult(
      videoBitRate: null,
      fieldOrder: FieldOrder.progressive,
      frameRate: '25/1',
      bitDepth: 8,
      duration: const Duration(minutes: 10),
      subtitles: const [],
      audioStreams: audio,
    );

String _audioCodec(String output, List<AudioStreamInfo> audio, {int? audioFfIndex}) {
  final args = ExportCommandBuilder.build(
    ExportPlan(inputPath: r'C:\v\in.m2ts', outputPath: output, rotation: Rotation.cw90, audioFfIndex: audioFfIndex),
    _probe(audio),
  ).args;
  return args[args.indexOf('-c:a') + 1];
}

void main() {
  const lpcm = AudioStreamInfo(index: 1, codec: 'pcm_bluray');
  const ac3 = AudioStreamInfo(index: 2, codec: 'ac3');

  test('mkv output re-encodes the selected Blu-ray LPCM track to FLAC', () {
    expect(_audioCodec(r'C:\v\in_rot90.mkv', [lpcm, ac3], audioFfIndex: 1), 'flac');
  });

  test('mkv output copies other codecs', () {
    expect(_audioCodec(r'C:\v\in_rot90.mkv', [lpcm, ac3], audioFfIndex: 2), 'copy');
  });

  test('without an ff-index the first audio stream decides', () {
    expect(_audioCodec(r'C:\v\in_rot90.mkv', [lpcm]), 'flac');
  });

  test('mov output keeps camera PCM as is', () {
    expect(_audioCodec(r'C:\v\in_rot90.mov', [const AudioStreamInfo(index: 1, codec: 'pcm_s16le')]), 'copy');
  });
}
```

`test/core/geometry/displayed_picture_size_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

void main() {
  const source = IntSize(1920, 1080);

  test('without a reported size, the source turned by the rotation', () {
    expect(CropMath.displayedPictureSize(null, source, Rotation.cw90), const IntSize(1080, 1920));
  });

  test('a reported size with the right orientation is kept (anamorphic included)', () {
    expect(CropMath.displayedPictureSize(const IntSize(1024, 576), const IntSize(720, 576), Rotation.none),
        const IntSize(1024, 576));
  });

  test('a reported size that ignores the rotation is turned', () {
    expect(CropMath.displayedPictureSize(const IntSize(1920, 1080), source, Rotation.ccw90), const IntSize(1080, 1920));
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/ffmpeg/probe_media_info_test.dart test/core/ffmpeg/export_audio_test.dart test/core/geometry/displayed_picture_size_test.dart`
Expected: FAIL à la compilation : `videoSize`, `AudioStreamInfo`, `displayedPictureSize` inexistants.

- [ ] **Step 3: Compléter `lib/core/ffmpeg/probe_result.dart`**

Ajouter l'import en tête :

```dart
import '../geometry/geometry.dart';
```

Ajouter après la classe `SubtitleStreamInfo` :

```dart
class AudioStreamInfo {
  const AudioStreamInfo({required this.index, required this.codec});

  /// Absolute stream index, the same as mpv's `ff-index`.
  final int index;
  final String codec;
}
```

Dans le constructeur de `ProbeResult`, après `required this.subtitles,`, ajouter :

```dart
    this.videoSize,
    this.audioStreams = const [],
```

Après le champ `final List<SubtitleStreamInfo> subtitles;`, ajouter :

```dart
  /// Coded size of the first video stream; null for audio-only files.
  final IntSize? videoSize;
  final List<AudioStreamInfo> audioStreams;
```

Dans `parse`, dans l'appel `return ProbeResult(`, après la liste `subtitles: [ ... ],`, ajouter :

```dart
      videoSize: _size(video),
      audioStreams: [
        for (final s in streams)
          if (s['codec_type'] == 'audio' && s['index'] is int)
            AudioStreamInfo(index: s['index'] as int, codec: '${s['codec_name'] ?? ''}'),
      ],
```

Ajouter la méthode après `_positiveInt` :

```dart
  static IntSize? _size(Map<String, dynamic>? video) {
    final w = _positiveInt(video?['width']);
    final h = _positiveInt(video?['height']);
    return (w == null || h == null) ? null : IntSize(w, h);
  }
```

- [ ] **Step 4: Modifier `lib/core/ffmpeg/export_command_builder.dart`**

Ajouter l'import :

```dart
import '../files/output_naming.dart';
```

Supprimer la fonction privée en double :

```dart
bool _isMp4Family(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.m4v');
}
```

Remplacer `if (_isMp4Family(plan.outputPath)) {` par `if (isMp4Family(plan.outputPath)) {`.

Dans `ExportCommandBuilder`, après `static const _minTrim = Duration(milliseconds: 100);`, ajouter :

```dart
  // LPCM flavours the Matroska muxer refuses; re-encoded losslessly.
  static const _matroskaRejectedAudio = {'pcm_bluray', 'pcm_dvd'};
```

Remplacer la ligne :

```dart
    args.addAll(['-pix_fmt', 'yuv420p', '-c:a', 'copy', '-map_metadata', '0', plan.outputPath]);
```

par :

```dart
    final audioCodec = (plan.audioFfIndex != null
            ? probe.audioStreams.where((a) => a.index == plan.audioFfIndex).firstOrNull
            : probe.audioStreams.firstOrNull)
        ?.codec;
    final audio = !isMp4Family(plan.outputPath) && _matroskaRejectedAudio.contains(audioCodec) ? 'flac' : 'copy';
    args.addAll(['-pix_fmt', 'yuv420p', '-c:a', audio, '-map_metadata', '0', plan.outputPath]);
```

- [ ] **Step 5: Compléter `lib/core/geometry/crop_math.dart`**

Ajouter dans `CropMath`, après `displaySize` :

```dart
  /// Size of the picture as drawn by the video widget. [reported] is what
  /// the engine says (aspect-corrected display size); depending on the mpv
  /// build it may or may not include the user rotation, so it is turned when
  /// its orientation contradicts [r]. Falls back to the coded size.
  static IntSize displayedPictureSize(IntSize? reported, IntSize source, Rotation r) {
    final expected = displaySize(source, r);
    if (reported == null || reported.width <= 0 || reported.height <= 0) return expected;
    final reportedLandscape = reported.width > reported.height;
    final expectedLandscape = expected.width > expected.height;
    if (reported.width == reported.height || reportedLandscape == expectedLandscape) return reported;
    return IntSize(reported.height, reported.width);
  }
```

- [ ] **Step 6: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` (les tests existants du constructeur de commandes passent toujours) et `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core test/core
git commit -m "feat(ffmpeg): probe picture size and audio codecs, re-encode LPCM to FLAC in mkv"
```

---

### Task 3: Textes Studio et musique (tr, fr, en)

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_tr.arb`
- Test: `test/l10n/studio_strings_test.dart`

**Interfaces:**
- Produces (getters de `AppLocalizations`) : `tooltipStudio`, `studioTrim`, `studioIn`, `studioOut`, `cropOff`, `cropFree`, `tooltipCrop`, `actionExport`, `exportRemaining(String time)`, `toastExportDone`, `toastExportCancelled`, `toastExportFailed`, `actionCopyDetails`, `toastExportRetryCpu`, `toastNoChanges`, `toastTrimTooShort`, `toastCropTooSmall`, `toastFfmpegMissing(String folder)`, `menuIdentifyMusic`, `menuAutoRename`, `toastListening`, `toastMusicNotFound`, `toastMusicFailed`, `actionRenameFile`, `actionCopy`, `actionUndo`, `toastRenamed(String name)`, `toastRenameFailed`.

- [ ] **Step 1: Écrire le test**

`test/l10n/studio_strings_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';
import 'package:uhf_media/l10n/app_localizations.dart';

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(children: [
      Text(l.tooltipStudio),
      Text(l.toastExportCancelled),
      Text(l.exportRemaining('00:01:12')),
      Text(l.toastRenamed('A - B.mp3')),
      Text(l.toastFfmpegMissing(r'C:\App')),
    ]);
  }
}

void main() {
  const expected = {
    'en': [
      'Studio (E)',
      'Export cancelled',
      '00:01:12 left',
      'Renamed to A - B.mp3',
      r'ffmpeg is missing: put ffmpeg.exe and ffprobe.exe in C:\App',
    ],
    'fr': [
      'Studio (E)',
      'Export annulé',
      'reste 00:01:12',
      'Renommé en A - B.mp3',
      r'ffmpeg est introuvable : place ffmpeg.exe et ffprobe.exe dans C:\App',
    ],
    'tr': [
      'Stüdyo (E)',
      'Dışa aktarma iptal edildi',
      '00:01:12 kaldı',
      'A - B.mp3 olarak yeniden adlandırıldı',
      r'ffmpeg bulunamadı: ffmpeg.exe ve ffprobe.exe dosyalarını C:\App klasörüne koy',
    ],
  };

  for (final entry in expected.entries) {
    testWidgets('studio and music strings in ${entry.key}', (tester) async {
      await tester.pumpWidget(UhfApp(locale: Locale(entry.key), home: const _Probe()));
      await tester.pumpAndSettle();
      for (final text in entry.value) {
        expect(find.text(text), findsOneWidget);
      }
    });
  }
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/l10n/studio_strings_test.dart`
Expected: FAIL, getters `tooltipStudio`… inexistants.

- [ ] **Step 3: Ajouter les clés anglaises**

Dans `lib/l10n/app_en.arb`, ajouter une virgule après la dernière entrée (`"@startupFailed": { ... }`) puis, avant l'accolade finale :

```json
  "tooltipStudio": "Studio (E)",
  "studioTrim": "Trim",
  "studioIn": "In",
  "studioOut": "Out",
  "tooltipCrop": "Crop (C)",
  "cropOff": "Off",
  "cropFree": "Free",
  "actionExport": "Export",
  "exportRemaining": "{time} left",
  "@exportRemaining": { "placeholders": { "time": { "type": "String" } } },
  "toastExportDone": "Export finished",
  "toastExportCancelled": "Export cancelled",
  "toastExportFailed": "The export failed",
  "actionCopyDetails": "Copy details",
  "toastExportRetryCpu": "Hardware encoding failed, retrying on the CPU",
  "toastNoChanges": "Choose a rotation, a crop or a trim first",
  "toastTrimTooShort": "The trim is too short",
  "toastCropTooSmall": "The crop is too small",
  "toastFfmpegMissing": "ffmpeg is missing: put ffmpeg.exe and ffprobe.exe in {folder}",
  "@toastFfmpegMissing": { "placeholders": { "folder": { "type": "String" } } },
  "menuIdentifyMusic": "Identify music",
  "menuAutoRename": "Rename automatically after identification",
  "toastListening": "Listening…",
  "toastMusicNotFound": "No song recognized",
  "toastMusicFailed": "Identification failed; check your connection",
  "actionRenameFile": "Rename the file",
  "actionCopy": "Copy",
  "actionUndo": "Undo",
  "toastRenamed": "Renamed to {name}",
  "@toastRenamed": { "placeholders": { "name": { "type": "String" } } },
  "toastRenameFailed": "Couldn't rename the file"
```

- [ ] **Step 4: Ajouter les clés françaises**

Dans `lib/l10n/app_fr.arb`, ajouter une virgule après la dernière entrée puis, avant l'accolade finale :

```json
  "tooltipStudio": "Studio (E)",
  "studioTrim": "Découpe",
  "studioIn": "Entrée",
  "studioOut": "Sortie",
  "tooltipCrop": "Cadre (C)",
  "cropOff": "Désactivé",
  "cropFree": "Libre",
  "actionExport": "Exporter",
  "exportRemaining": "reste {time}",
  "toastExportDone": "Export terminé",
  "toastExportCancelled": "Export annulé",
  "toastExportFailed": "L'export a échoué",
  "actionCopyDetails": "Copier le détail",
  "toastExportRetryCpu": "L'encodage matériel a échoué, nouvel essai sur le processeur",
  "toastNoChanges": "Choisis d'abord une rotation, un cadre ou une découpe",
  "toastTrimTooShort": "La découpe est trop courte",
  "toastCropTooSmall": "Le cadre est trop petit",
  "toastFfmpegMissing": "ffmpeg est introuvable : place ffmpeg.exe et ffprobe.exe dans {folder}",
  "menuIdentifyMusic": "Identifier la musique",
  "menuAutoRename": "Renommer automatiquement après identification",
  "toastListening": "Écoute en cours…",
  "toastMusicNotFound": "Aucun morceau reconnu",
  "toastMusicFailed": "L'identification a échoué ; vérifie ta connexion",
  "actionRenameFile": "Renommer le fichier",
  "actionCopy": "Copier",
  "actionUndo": "Annuler",
  "toastRenamed": "Renommé en {name}",
  "toastRenameFailed": "Impossible de renommer le fichier"
```

- [ ] **Step 5: Ajouter les clés turques**

Dans `lib/l10n/app_tr.arb`, ajouter une virgule après la dernière entrée puis, avant l'accolade finale :

```json
  "tooltipStudio": "Stüdyo (E)",
  "studioTrim": "Kesme",
  "studioIn": "Başlangıç",
  "studioOut": "Bitiş",
  "tooltipCrop": "Kırpma (C)",
  "cropOff": "Kapalı",
  "cropFree": "Serbest",
  "actionExport": "Dışa aktar",
  "exportRemaining": "{time} kaldı",
  "toastExportDone": "Dışa aktarma tamamlandı",
  "toastExportCancelled": "Dışa aktarma iptal edildi",
  "toastExportFailed": "Dışa aktarma başarısız oldu",
  "actionCopyDetails": "Ayrıntıyı kopyala",
  "toastExportRetryCpu": "Donanım kodlama başarısız oldu, işlemciyle yeniden deneniyor",
  "toastNoChanges": "Önce bir döndürme, kırpma ya da kesme seç",
  "toastTrimTooShort": "Kesme aralığı çok kısa",
  "toastCropTooSmall": "Kırpma alanı çok küçük",
  "toastFfmpegMissing": "ffmpeg bulunamadı: ffmpeg.exe ve ffprobe.exe dosyalarını {folder} klasörüne koy",
  "menuIdentifyMusic": "Müziği tanı",
  "menuAutoRename": "Tanımadan sonra otomatik yeniden adlandır",
  "toastListening": "Dinleniyor…",
  "toastMusicNotFound": "Şarkı tanınamadı",
  "toastMusicFailed": "Tanıma başarısız oldu; bağlantını kontrol et",
  "actionRenameFile": "Dosyayı yeniden adlandır",
  "actionCopy": "Kopyala",
  "actionUndo": "Geri al",
  "toastRenamed": "{name} olarak yeniden adlandırıldı",
  "toastRenameFailed": "Dosya yeniden adlandırılamadı"
```

- [ ] **Step 6: Générer et lancer les tests**

Run: `flutter gen-l10n` puis `flutter test` puis `flutter analyze`
Expected: aucune clé manquante signalée ; `All tests passed!` ; `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/l10n test/l10n
git commit -m "feat(l10n): add studio and music identification strings"
```

---

### Task 4: Exécution d'ffmpeg avec progression et annulation

**Files:**
- Create: `lib/core/ffmpeg/export_progress.dart`, `lib/core/system/export_runner.dart`, `test/support/fake_process.dart`
- Test: `test/core/ffmpeg/export_progress_test.dart`, `test/core/system/export_runner_test.dart`

**Interfaces:**
- Produces:
  - `class ProgressParser { ProgressParser(Duration total); double? feed(String line); }` — lit `out_time_us=<µs>` (fraction bornée à `[0, 1]`) et `progress=end` (1.0) ; `null` pour les autres lignes, `N/A`, ou une durée totale nulle.
  - `typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);`
  - `sealed class ExportOutcome` ; `ExportSucceeded(String outputPath)`, `ExportCancelled()`, `ExportFailed(String log)` (au plus les 2000 derniers caractères de stderr).
  - `class ExportJob { Stream<double> get progress; Future<ExportOutcome> get done; void cancel(); }`
  - `class ExportRunner { ExportRunner(String ffmpegPath, {ProcessStarter? start, Future<void> Function(String path)? deleteFile}); ExportJob start(List<String> args, {required String outputPath, required Duration total}); }` — fichier de sortie supprimé après annulation ou échec ; une annulation demandée avant le démarrage tue ffmpeg dès qu'il démarre.
  - Test : `class FakeProcess implements Process { FakeProcess({List<String> stdoutLines, String stderrText, int exit, bool waitForKill}); bool killed; }`.

- [ ] **Step 1: Écrire la doublure `test/support/fake_process.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Scripted process: writes its output on the next event-loop turn, then
/// exits with [exit] — or, with [waitForKill], only when killed (-1).
class FakeProcess implements Process {
  FakeProcess({List<String> stdoutLines = const [], String stderrText = '', int exit = 0, bool waitForKill = false}) {
    Future<void>(() {
      if (_exit.isCompleted) return;
      _stdout.add(utf8.encode(stdoutLines.map((l) => '$l\n').join()));
      _stderr.add(utf8.encode(stderrText));
      if (!waitForKill) _end(exit);
    });
  }

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  void _end(int code) {
    if (_exit.isCompleted) return;
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    _exit.complete(code);
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;
  @override
  Stream<List<int>> get stderr => _stderr.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;
  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    _end(-1);
    return true;
  }
}
```

- [ ] **Step 2: Écrire les tests**

`test/core/ffmpeg/export_progress_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_progress.dart';

void main() {
  final parser = ProgressParser(const Duration(seconds: 10));

  test('out_time_us gives the fraction done', () {
    expect(parser.feed('out_time_us=2500000'), 0.25);
  });

  test('progress=end means done', () {
    expect(parser.feed('progress=end'), 1.0);
  });

  test('other lines, N/A and overshoot', () {
    expect(parser.feed('frame=120'), isNull);
    expect(parser.feed('progress=continue'), isNull);
    expect(parser.feed('out_time_us=N/A'), isNull);
    expect(parser.feed('out_time_us=99000000'), 1.0);
  });

  test('unknown total duration gives no fraction', () {
    expect(ProgressParser(Duration.zero).feed('out_time_us=1000'), isNull);
  });
}
```

`test/core/system/export_runner_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/system/export_runner.dart';

import '../../support/fake_process.dart';

void main() {
  late List<String> deleted;
  setUp(() => deleted = []);

  ExportRunner runner(FakeProcess process, {List<String>? seenArgs}) => ExportRunner(
        r'C:\App\ffmpeg.exe',
        start: (exe, args) async {
          expect(exe, r'C:\App\ffmpeg.exe');
          seenArgs?.addAll(args);
          return process;
        },
        deleteFile: (path) async => deleted.add(path),
      );

  test('reports progress and succeeds', () async {
    final seen = <String>[];
    final job = runner(
      FakeProcess(stdoutLines: ['frame=1', 'out_time_us=5000000', 'progress=continue', 'progress=end']),
      seenArgs: seen,
    ).start(['-i', 'in.mkv', 'out.mkv'], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    final fractions = <double>[];
    job.progress.listen(fractions.add);
    final outcome = await job.done;
    expect(outcome, isA<ExportSucceeded>().having((o) => o.outputPath, 'outputPath', r'C:\v\out.mkv'));
    expect(fractions, [0.5, 1.0]);
    expect(seen, ['-i', 'in.mkv', 'out.mkv']);
    expect(deleted, isEmpty);
  });

  test('a failure keeps the end of stderr and deletes the partial file', () async {
    final job = runner(FakeProcess(stderrText: '${'x' * 3000}END', exit: 1))
        .start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    final outcome = await job.done;
    expect(outcome, isA<ExportFailed>());
    final log = (outcome as ExportFailed).log;
    expect(log.length, 2000);
    expect(log, endsWith('END'));
    expect(deleted, [r'C:\v\out.mkv']);
  });

  test('cancel kills ffmpeg and deletes the partial file', () async {
    final process = FakeProcess(waitForKill: true);
    final job = runner(process).start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    await Future<void>.delayed(Duration.zero);
    job.cancel();
    expect(await job.done, isA<ExportCancelled>());
    expect(process.killed, isTrue);
    expect(deleted, [r'C:\v\out.mkv']);
  });

  test('a cancel requested before ffmpeg starts kills it on start (review focus 2)', () async {
    final process = FakeProcess(waitForKill: true);
    final job = runner(process).start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    job.cancel();
    expect(await job.done, isA<ExportCancelled>());
    expect(process.killed, isTrue);
  });

  test('ffmpeg that cannot start is a failure, not a crash', () async {
    final job = ExportRunner(
      'ffmpeg.exe',
      start: (_, _) async => throw const ProcessException('ffmpeg.exe', [], 'not found'),
      deleteFile: (path) async => deleted.add(path),
    ).start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    expect(await job.done, isA<ExportFailed>().having((o) => o.log, 'log', 'not found'));
  });
}
```

- [ ] **Step 3: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/ffmpeg/export_progress_test.dart test/core/system/export_runner_test.dart`
Expected: FAIL, `export_progress.dart` et `export_runner.dart` introuvables.

- [ ] **Step 4: Écrire `lib/core/ffmpeg/export_progress.dart`**

```dart
/// Reads the key=value lines ffmpeg writes with `-progress pipe:1`.
class ProgressParser {
  ProgressParser(this.total);

  final Duration total;

  /// Fraction done in [0, 1], or null when [line] carries no progress.
  double? feed(String line) {
    final eq = line.indexOf('=');
    if (eq < 0) return null;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    if (key == 'progress' && value == 'end') return 1.0;
    if (key != 'out_time_us' || total <= Duration.zero) return null;
    final us = int.tryParse(value);
    if (us == null) return null;
    return (us / total.inMicroseconds).clamp(0.0, 1.0);
  }
}
```

- [ ] **Step 5: Écrire `lib/core/system/export_runner.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ffmpeg/export_progress.dart';

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

sealed class ExportOutcome {
  const ExportOutcome();
}

class ExportSucceeded extends ExportOutcome {
  const ExportSucceeded(this.outputPath);
  final String outputPath;
}

class ExportCancelled extends ExportOutcome {
  const ExportCancelled();
}

class ExportFailed extends ExportOutcome {
  const ExportFailed(this.log);

  /// End of ffmpeg's error output, for "Copy details".
  final String log;
}

class ExportJob {
  ExportJob._();

  final _progress = StreamController<double>.broadcast();
  final _done = Completer<ExportOutcome>();
  Process? _process;
  bool _cancelRequested = false;

  Stream<double> get progress => _progress.stream;
  Future<ExportOutcome> get done => _done.future;

  void cancel() {
    _cancelRequested = true;
    _process?.kill();
  }

  void _finish(ExportOutcome outcome) {
    if (!_done.isCompleted) _done.complete(outcome);
    unawaited(_progress.close());
  }
}

class ExportRunner {
  ExportRunner(this.ffmpegPath, {ProcessStarter? start, Future<void> Function(String path)? deleteFile})
      : _start = start ?? Process.start,
        _delete = deleteFile ?? _deleteIfExists;

  static const _logLimit = 2000;

  final String ffmpegPath;
  final ProcessStarter _start;
  final Future<void> Function(String path) _delete;

  ExportJob start(List<String> args, {required String outputPath, required Duration total}) {
    final job = ExportJob._();
    unawaited(_run(job, args, outputPath, total));
    return job;
  }

  Future<void> _run(ExportJob job, List<String> args, String outputPath, Duration total) async {
    final Process process;
    try {
      process = await _start(ffmpegPath, args);
    } on ProcessException catch (e) {
      job._finish(ExportFailed(e.message));
      return;
    }
    job._process = process;
    if (job._cancelRequested) process.kill();

    var log = '';
    final errors = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((chunk) {
      log += chunk;
      if (log.length > 2 * _logLimit) log = log.substring(log.length - _logLimit);
    }).asFuture<void>();

    final parser = ProgressParser(total);
    await process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .forEach((line) {
      final fraction = parser.feed(line);
      if (fraction != null && !job._progress.isClosed) job._progress.add(fraction);
    });
    await errors;
    final code = await process.exitCode;

    if (job._cancelRequested) {
      await _delete(outputPath);
      job._finish(const ExportCancelled());
    } else if (code == 0) {
      job._finish(ExportSucceeded(outputPath));
    } else {
      await _delete(outputPath);
      job._finish(ExportFailed(log.length > _logLimit ? log.substring(log.length - _logLimit) : log));
    }
  }
}

Future<void> _deleteIfExists(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Locked or already gone: nothing more to do.
  }
}
```

- [ ] **Step 6: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/core/ffmpeg/export_progress.dart lib/core/system/export_runner.dart test/support/fake_process.dart test/core/ffmpeg/export_progress_test.dart test/core/system/export_runner_test.dart
git commit -m "feat(export): run ffmpeg with progress, cancel and partial file cleanup"
```

---

### Task 5: Service d'export (encodeur matériel, nom de sortie, repli CPU)

**Files:**
- Create: `lib/core/system/export_service.dart`
- Test: `test/core/system/export_service_test.dart`

**Interfaces:**
- Consumes: `ExportRunner`, `ExportJob`, `ExportOutcome`, `ProcessStarter` (tâche 4), `ExportCommandBuilder`, `ExportPlan`, `TrimRange`, `HwEncoder`, `pickHwEncoder`, `exportOutputPath` (plan 1), `ProbeResult`, `ProcessRunner`.
- Produces:
  - `class ExportInput { const ExportInput({required String inputPath, required ProbeResult probe, Rotation rotation = Rotation.none, IntRect? crop, TrimRange? trim, int? videoFfIndex, int? audioFfIndex}); }` — `crop` en pixels source non tournés.
  - `abstract interface class Exporter { bool get available; String get expectedFolder; Future<ExportOutcome> export(ExportInput input, {required void Function(double fraction) onProgress, void Function()? onCpuRetry}); void cancel(); }` — `export` lève `ExportPlanException` (aucune modification, découpe trop courte, cadre trop petit).
  - `class ExportService implements Exporter { ExportService({required String? ffmpegPath, required String expectedFolder, ProcessRunner? run, ProcessStarter? start, bool Function(String path)? exists, Future<void> Function(String path)? deleteFile}); Future<HwEncoder?> hwEncoder(); }` — `ffmpeg -hide_banner -encoders` lu une seule fois.

- [ ] **Step 1: Écrire le test**

`test/core/system/export_service_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/system/export_runner.dart';
import 'package:uhf_media/core/system/export_service.dart';

import '../../support/fake_process.dart';

const _probe = ProbeResult(
  videoBitRate: 8000000,
  fieldOrder: FieldOrder.progressive,
  frameRate: '25/1',
  bitDepth: 8,
  duration: Duration(minutes: 10),
  subtitles: [],
);

const _input = ExportInput(inputPath: r'C:\v\a.mkv', probe: _probe, rotation: Rotation.cw90);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late List<List<String>> started;
  late List<FakeProcess> processes;
  late int encoderQueries;

  setUp(() {
    started = [];
    processes = [];
    encoderQueries = 0;
  });

  ExportService service({String encoders = ' V....D h264_nvenc   NVIDIA NVENC', Set<String> existing = const {}}) =>
      ExportService(
        ffmpegPath: r'C:\App\ffmpeg.exe',
        expectedFolder: r'C:\App',
        run: (exe, args) async {
          encoderQueries++;
          expect(args, ['-hide_banner', '-encoders']);
          return ProcessResult(1, 0, encoders, '');
        },
        start: (exe, args) async {
          started.add(args);
          return processes.removeAt(0);
        },
        exists: existing.contains,
        deleteFile: (_) async {},
      );

  test('a GPU failure retries once on the CPU', () async {
    processes = [FakeProcess(stderrText: 'nvenc failed', exit: 1), FakeProcess(stdoutLines: ['progress=end'])];
    var retries = 0;
    final s = service();
    final outcome = await s.export(_input, onProgress: (_) {}, onCpuRetry: () => retries++);
    expect(outcome, isA<ExportSucceeded>().having((o) => o.outputPath, 'outputPath', r'C:\v\a_rot90.mkv'));
    expect(retries, 1);
    expect(started[0], contains('h264_nvenc'));
    expect(started[1], contains('libx264'));
    expect(started[1], isNot(contains('h264_nvenc')));
  });

  test('the encoder list is read once', () async {
    processes = [FakeProcess(stdoutLines: ['progress=end']), FakeProcess(stdoutLines: ['progress=end'])];
    final s = service();
    await s.export(_input, onProgress: (_) {});
    await s.export(_input, onProgress: (_) {});
    expect(encoderQueries, 1);
  });

  test('cancelling during the GPU attempt never retries on the CPU (review focus 2)', () async {
    processes = [FakeProcess(waitForKill: true)];
    var retries = 0;
    final s = service();
    final future = s.export(_input, onProgress: (_) {}, onCpuRetry: () => retries++);
    await _settle();
    s.cancel();
    expect(await future, isA<ExportCancelled>());
    expect(retries, 0);
    expect(started, hasLength(1));
  });

  test('progress is forwarded', () async {
    processes = [FakeProcess(stdoutLines: ['out_time_us=300000000', 'progress=end'])];
    final fractions = <double>[];
    await service(encoders: '').export(_input, onProgress: fractions.add);
    expect(fractions, [0.5, 1.0]);
  });

  test('the output name avoids existing files', () async {
    processes = [FakeProcess(stdoutLines: ['progress=end'])];
    final outcome = await service(encoders: '', existing: {r'C:\v\a_rot90.mkv'}).export(_input, onProgress: (_) {});
    expect((outcome as ExportSucceeded).outputPath, r'C:\v\a_rot90 (1).mkv');
  });

  test('nothing to do is rejected before ffmpeg runs', () async {
    await expectLater(
      service().export(const ExportInput(inputPath: r'C:\v\a.mkv', probe: _probe), onProgress: (_) {}),
      throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.noChanges)),
    );
    expect(started, isEmpty);
  });

  test('without ffmpeg the service is unavailable', () async {
    final s = ExportService(ffmpegPath: null, expectedFolder: r'C:\App');
    expect(s.available, isFalse);
    expect(await s.export(_input, onProgress: (_) {}), isA<ExportFailed>());
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/system/export_service_test.dart`
Expected: FAIL, `export_service.dart` introuvable.

- [ ] **Step 3: Écrire `lib/core/system/export_service.dart`**

```dart
import 'dart:io';

import '../ffmpeg/export_command_builder.dart';
import '../ffmpeg/export_plan.dart';
import '../ffmpeg/probe_result.dart';
import '../files/output_naming.dart';
import '../geometry/geometry.dart';
import '../geometry/rotation.dart';
import 'export_runner.dart';
import 'process_runner.dart';

class ExportInput {
  const ExportInput({
    required this.inputPath,
    required this.probe,
    this.rotation = Rotation.none,
    this.crop,
    this.trim,
    this.videoFfIndex,
    this.audioFfIndex,
  });

  final String inputPath;
  final ProbeResult probe;
  final Rotation rotation;

  /// Crop in unrotated source pixels.
  final IntRect? crop;
  final TrimRange? trim;
  final int? videoFfIndex;
  final int? audioFfIndex;
}

abstract interface class Exporter {
  bool get available;

  /// Folder where ffmpeg.exe is expected, for the "missing" message.
  String get expectedFolder;

  /// Throws [ExportPlanException] when the edits cannot be exported.
  Future<ExportOutcome> export(
    ExportInput input, {
    required void Function(double fraction) onProgress,
    void Function()? onCpuRetry,
  });

  void cancel();
}

class ExportService implements Exporter {
  ExportService({
    required String? ffmpegPath,
    required this.expectedFolder,
    ProcessRunner? run,
    ProcessStarter? start,
    bool Function(String path)? exists,
    Future<void> Function(String path)? deleteFile,
  })  : _ffmpeg = ffmpegPath,
        _run = run ?? defaultProcessRunner,
        _start = start,
        _exists = exists ?? ((path) => File(path).existsSync()),
        _deleteFile = deleteFile;

  final String? _ffmpeg;
  final ProcessRunner _run;
  final ProcessStarter? _start;
  final bool Function(String path) _exists;
  final Future<void> Function(String path)? _deleteFile;
  Future<HwEncoder?>? _hw;
  ExportJob? _job;
  bool _cancelled = false;

  @override
  final String expectedFolder;

  @override
  bool get available => _ffmpeg != null;

  /// Hardware H.264 encoder listed by this ffmpeg build, detected once.
  Future<HwEncoder?> hwEncoder() => _hw ??= _detectHwEncoder();

  Future<HwEncoder?> _detectHwEncoder() async {
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return null;
    try {
      final r = await _run(ffmpeg, ['-hide_banner', '-encoders']);
      return r.exitCode == 0 ? pickHwEncoder('${r.stdout}') : null;
    } on Exception {
      return null;
    }
  }

  @override
  Future<ExportOutcome> export(
    ExportInput input, {
    required void Function(double fraction) onProgress,
    void Function()? onCpuRetry,
  }) async {
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return const ExportFailed('ffmpeg.exe not found');
    _cancelled = false;
    final plan = ExportPlan(
      inputPath: input.inputPath,
      outputPath: exportOutputPath(
        input.inputPath,
        crop: input.crop != null,
        rotation: input.rotation,
        trim: input.trim != null,
        exists: _exists,
      ),
      rotation: input.rotation,
      crop: input.crop,
      trim: input.trim,
      videoFfIndex: input.videoFfIndex,
      audioFfIndex: input.audioFfIndex,
    );
    // Validates the edits first: nothing runs when the plan is rejected.
    ExportCommandBuilder.build(plan, input.probe);
    final total = input.trim?.length ?? input.probe.duration ?? Duration.zero;
    final runner = ExportRunner(ffmpeg, start: _start, deleteFile: _deleteFile);

    var command = ExportCommandBuilder.build(plan, input.probe, hwEncoder: await hwEncoder());
    var outcome = await _runOnce(runner, command, plan.outputPath, total, onProgress);
    if (outcome is ExportFailed && command.usesHardware && !_cancelled) {
      // A listed encoder can still fail (no GPU, old driver): retry on the CPU.
      onCpuRetry?.call();
      command = ExportCommandBuilder.build(plan, input.probe);
      outcome = await _runOnce(runner, command, plan.outputPath, total, onProgress);
    }
    return outcome;
  }

  Future<ExportOutcome> _runOnce(
    ExportRunner runner,
    ExportCommand command,
    String outputPath,
    Duration total,
    void Function(double fraction) onProgress,
  ) async {
    final job = runner.start(command.args, outputPath: outputPath, total: total);
    _job = job;
    if (_cancelled) job.cancel();
    final subscription = job.progress.listen(onProgress);
    try {
      return await job.done;
    } finally {
      await subscription.cancel();
      _job = null;
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    _job?.cancel();
  }
}
```

Note : `ExportRunner(ffmpeg, start: _start, ...)` reçoit `null` quand aucun lanceur n'est injecté ; le constructeur de `ExportRunner` retombe alors sur `Process.start`.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/system/export_service.dart test/core/system/export_service_test.dart
git commit -m "feat(export): detect the hardware encoder, name the output and retry on the CPU"
```

---

### Task 6: Plage de découpe (logique pure)

**Files:**
- Create: `lib/features/studio/trim_selection.dart`
- Test: `test/features/studio/trim_selection_test.dart`

**Interfaces:**
- Consumes: `TrimRange` (plan 1).
- Produces:
  - `enum TrimHandle { start, end }`
  - `class TrimSelection { const TrimSelection({required Duration start, required Duration end, required Duration duration}); factory TrimSelection.window(Duration from, Duration duration, {Duration length = const Duration(seconds: 60)}); Duration get minGap; Duration get length; TrimRange get range; TrimSelection withStart(Duration); TrimSelection withEnd(Duration); TrimSelection moveBy(Duration delta); TrimHandle nearestHandle(Duration at); }` — valeur immuable avec `==` ; `minGap` = 0,5 % de la durée ; aucune opération ne lève d'exception, durée nulle comprise.
- Ce fichier n'importe ni Flutter ni `dart:io`.

- [ ] **Step 1: Écrire le test**

`test/features/studio/trim_selection_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/features/studio/trim_selection.dart';

const _ten = Duration(minutes: 10);
Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  test('the window starts at the position and lasts 60 s', () {
    final t = TrimSelection.window(s(60), _ten);
    expect(t, TrimSelection(start: s(60), end: s(120), duration: _ten));
    expect(t.length, s(60));
    expect(t.range.start, s(60));
    expect(t.range.end, s(120));
  });

  test('near the end the window is shortened, and never empty', () {
    expect(TrimSelection.window(s(570), _ten), TrimSelection(start: s(570), end: _ten, duration: _ten));
    // minGap is 0.5 % of 10 min = 3 s.
    expect(TrimSelection.window(_ten, _ten), TrimSelection(start: s(597), end: _ten, duration: _ten));
  });

  test('handles keep the minimal gap and stay in the file', () {
    final t = TrimSelection(start: s(100), end: s(200), duration: _ten);
    expect(t.withStart(s(250)).start, s(197));
    expect(t.withStart(s(-5)).start, Duration.zero);
    expect(t.withEnd(s(50)).end, s(103));
    expect(t.withEnd(s(9999)).end, _ten);
  });

  test('moving the range keeps its length and stops at the edges', () {
    final t = TrimSelection(start: s(100), end: s(200), duration: _ten);
    expect(t.moveBy(s(30)), TrimSelection(start: s(130), end: s(230), duration: _ten));
    expect(t.moveBy(s(9999)), TrimSelection(start: s(500), end: _ten, duration: _ten));
    expect(t.moveBy(s(-9999)), TrimSelection(start: Duration.zero, end: s(100), duration: _ten));
  });

  test('the nearest handle wins, the start on a tie', () {
    final t = TrimSelection(start: s(100), end: s(200), duration: _ten);
    expect(t.nearestHandle(s(20)), TrimHandle.start);
    expect(t.nearestHandle(s(150)), TrimHandle.start);
    expect(t.nearestHandle(s(151)), TrimHandle.end);
  });

  test('a zero duration never throws (review focus: unknown duration)', () {
    final t = TrimSelection.window(s(5), Duration.zero);
    expect(t.start, Duration.zero);
    expect(t.end, Duration.zero);
    expect(t.withStart(s(3)).start, Duration.zero);
    expect(t.moveBy(s(3)).start, Duration.zero);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/studio/trim_selection_test.dart`
Expected: FAIL, `trim_selection.dart` introuvable.

- [ ] **Step 3: Écrire `lib/features/studio/trim_selection.dart`**

```dart
import '../../core/ffmpeg/export_plan.dart';

enum TrimHandle { start, end }

/// Trim range on a file of known [duration]. Every edit keeps
/// 0 <= start < end <= duration with a gap of at least [minGap].
class TrimSelection {
  const TrimSelection({required this.start, required this.end, required this.duration});

  /// [length] from [from], shortened at the end of the file.
  factory TrimSelection.window(Duration from, Duration duration, {Duration length = const Duration(seconds: 60)}) {
    final gap = _gapOf(duration);
    final start = _clamp(from, Duration.zero, duration - gap);
    final end = start + length > duration ? duration : start + length;
    return TrimSelection(start: start, end: end, duration: duration);
  }

  final Duration start;
  final Duration end;
  final Duration duration;

  static Duration _gapOf(Duration d) => Duration(microseconds: (d.inMicroseconds * 0.005).round());

  /// 0.5 % of the duration, so the handles never overlap.
  Duration get minGap => _gapOf(duration);
  Duration get length => end - start;
  TrimRange get range => TrimRange(start, end);

  TrimSelection withStart(Duration value) =>
      TrimSelection(start: _clamp(value, Duration.zero, end - minGap), end: end, duration: duration);

  TrimSelection withEnd(Duration value) =>
      TrimSelection(start: start, end: _clamp(value, start + minGap, duration), duration: duration);

  TrimSelection moveBy(Duration delta) {
    final shifted = _clamp(start + delta, Duration.zero, duration - length);
    return TrimSelection(start: shifted, end: shifted + length, duration: duration);
  }

  TrimHandle nearestHandle(Duration at) =>
      (at - start).abs() <= (at - end).abs() ? TrimHandle.start : TrimHandle.end;

  @override
  bool operator ==(Object other) =>
      other is TrimSelection && other.start == start && other.end == end && other.duration == duration;

  @override
  int get hashCode => Object.hash(start, end, duration);

  @override
  String toString() => 'TrimSelection($start, $end / $duration)';
}

Duration _clamp(Duration value, Duration low, Duration high) {
  if (high < low) return low;
  if (value < low) return low;
  if (value > high) return high;
  return value;
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/studio/trim_selection.dart test/features/studio/trim_selection_test.dart
git commit -m "feat(studio): add trim selection rules"
```

---

### Task 7: Déplacement du cadre de recadrage (logique pure)

**Files:**
- Create: `lib/core/geometry/crop_drag.dart`
- Test: `test/core/geometry/crop_drag_test.dart`

**Interfaces:**
- Consumes: `RatioRect` (plan 1).
- Produces:
  - `enum CropHandle { move, n, s, e, w, ne, nw, se, sw }`
  - `RatioRect dragCrop(RatioRect start, CropHandle handle, double dx, double dy, {required double pictureWidth, required double pictureHeight, double? lockRatio, double minSize = 20})` — `start` en fractions de l'image affichée, `dx` / `dy` en pixels depuis le début du glissement. Sans ratio : chaque bord bouge seul, borné à l'image, 20 px minimum. Avec ratio (largeur / hauteur en pixels affichés) : coin opposé fixe pour les coins, centre fixe pour les côtés, taille réduite pour rester dans l'image. Déplacement : taille conservée, position bornée.

- [ ] **Step 1: Écrire le test**

`test/core/geometry/crop_drag_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/crop_drag.dart';
import 'package:uhf_media/core/geometry/geometry.dart';

// Picture of 1000 x 500 px.
RatioRect drag(RatioRect r, CropHandle h, double dx, double dy, {double? ratio}) =>
    dragCrop(r, h, dx, dy, pictureWidth: 1000, pictureHeight: 500, lockRatio: ratio);

Matcher rect(double l, double t, double w, double h) => isA<RatioRect>()
    .having((r) => r.left, 'left', closeTo(l, 1e-9))
    .having((r) => r.top, 'top', closeTo(t, 1e-9))
    .having((r) => r.width, 'width', closeTo(w, 1e-9))
    .having((r) => r.height, 'height', closeTo(h, 1e-9));

void main() {
  const base = RatioRect(0.1, 0.1, 0.5, 0.5);

  test('moving keeps the size and stops at the edges', () {
    expect(drag(base, CropHandle.move, 100, 50), rect(0.2, 0.2, 0.5, 0.5));
    expect(drag(base, CropHandle.move, 5000, -5000), rect(0.5, 0.0, 0.5, 0.5));
  });

  test('a free corner moves its two edges', () {
    expect(drag(base, CropHandle.se, 100, 50), rect(0.1, 0.1, 0.6, 0.6));
    expect(drag(base, CropHandle.se, 5000, 5000), rect(0.1, 0.1, 0.9, 0.9));
  });

  test('a free edge stops at 20 px', () {
    // Right edge at 600 px: the left edge stops at 580 px.
    expect(drag(base, CropHandle.w, 1000, 0), rect(0.58, 0.1, 0.02, 0.5));
    // Bottom edge at 300 px: the top edge stops at 280 px.
    expect(drag(base, CropHandle.n, 0, 1000), rect(0.1, 0.56, 0.5, 0.04));
  });

  // 200 x 200 px square at (100, 100).
  const square = RatioRect(0.1, 0.2, 0.2, 0.4);

  test('a locked corner keeps the ratio and the opposite corner', () {
    expect(drag(square, CropHandle.se, 100, 0, ratio: 1), rect(0.1, 0.2, 0.3, 0.6));
    expect(drag(square, CropHandle.nw, -50, 0, ratio: 1), rect(0.05, 0.1, 0.25, 0.5));
  });

  test('a locked corner shrinks to stay in the picture', () {
    // Room below the top edge: 400 px, so the square stops at 400 px.
    expect(drag(square, CropHandle.se, 5000, 0, ratio: 1), rect(0.1, 0.2, 0.4, 0.8));
  });

  test('a locked side keeps the ratio around its centre', () {
    expect(drag(square, CropHandle.e, 100, 0, ratio: 1), rect(0.1, 0.1, 0.3, 0.6));
    expect(drag(square, CropHandle.s, 0, 100, ratio: 1), rect(0.05, 0.2, 0.3, 0.6));
  });

  test('a locked corner never goes under 20 px on either side', () {
    final r = drag(square, CropHandle.se, -1000, -1000, ratio: 0.5);
    expect(r.width * 1000, closeTo(20, 1e-6));
    expect(r.height * 500, closeTo(40, 1e-6));
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/geometry/crop_drag_test.dart`
Expected: FAIL, `crop_drag.dart` introuvable.

- [ ] **Step 3: Écrire `lib/core/geometry/crop_drag.dart`**

```dart
import 'dart:math' as math;

import 'geometry.dart';

enum CropHandle { move, n, s, e, w, ne, nw, se, sw }

extension on CropHandle {
  bool get west => this == CropHandle.w || this == CropHandle.nw || this == CropHandle.sw;
  bool get east => this == CropHandle.e || this == CropHandle.ne || this == CropHandle.se;
  bool get north => this == CropHandle.n || this == CropHandle.nw || this == CropHandle.ne;
  bool get south => this == CropHandle.s || this == CropHandle.sw || this == CropHandle.se;
  bool get corner => (west || east) && (north || south);
}

/// New crop after dragging [handle] by ([dx], [dy]) pixels from [start].
/// [lockRatio] is width / height in displayed pixels (null: free).
RatioRect dragCrop(
  RatioRect start,
  CropHandle handle,
  double dx,
  double dy, {
  required double pictureWidth,
  required double pictureHeight,
  double? lockRatio,
  double minSize = 20,
}) {
  final pw = pictureWidth;
  final ph = pictureHeight;
  if (pw <= 0 || ph <= 0) return start;
  final minW = math.min(minSize, pw);
  final minH = math.min(minSize, ph);
  var l = start.left * pw;
  var t = start.top * ph;
  var r = (start.left + start.width) * pw;
  var b = (start.top + start.height) * ph;

  RatioRect result(double left, double top, double width, double height) =>
      RatioRect(left / pw, top / ph, width / pw, height / ph);

  if (handle == CropHandle.move) {
    final w = r - l;
    final h = b - t;
    return result((l + dx).clamp(0.0, pw - w), (t + dy).clamp(0.0, ph - h), w, h);
  }

  final ratio = lockRatio;
  if (ratio == null) {
    if (handle.west) l = (l + dx).clamp(0.0, r - minW);
    if (handle.east) r = (r + dx).clamp(l + minW, pw);
    if (handle.north) t = (t + dy).clamp(0.0, b - minH);
    if (handle.south) b = (b + dy).clamp(t + minH, ph);
    return result(l, t, r - l, b - t);
  }

  // Smallest width that keeps both sides at least minSize.
  final minWidth = math.max(minW, minH * ratio);

  if (handle.corner) {
    final ax = handle.west ? r : l;
    final ay = handle.north ? b : t;
    final proposedW = handle.west ? r - (l + dx) : r + dx - l;
    final proposedH = handle.north ? b - (t + dy) : b + dy - t;
    final maxW = math.min(handle.west ? ax : pw - ax, (handle.north ? ay : ph - ay) * ratio);
    final w = math.max(proposedW, proposedH * ratio).clamp(math.min(minWidth, maxW), maxW);
    final h = w / ratio;
    return result(handle.west ? ax - w : ax, handle.north ? ay - h : ay, w, h);
  }

  if (handle.west || handle.east) {
    final ax = handle.west ? r : l;
    final cy = (t + b) / 2;
    final proposedW = handle.west ? r - (l + dx) : r + dx - l;
    final maxW = math.min(handle.west ? ax : pw - ax, 2 * math.min(cy, ph - cy) * ratio);
    final w = proposedW.clamp(math.min(minWidth, maxW), maxW);
    final h = w / ratio;
    return result(handle.west ? ax - w : ax, cy - h / 2, w, h);
  }

  final ay = handle.north ? b : t;
  final cx = (l + r) / 2;
  final proposedH = handle.north ? b - (t + dy) : b + dy - t;
  final maxH = math.min(handle.north ? ay : ph - ay, 2 * math.min(cx, pw - cx) / ratio);
  final h = proposedH.clamp(math.min(minWidth / ratio, maxH), maxH);
  final w = h * ratio;
  return result(cx - w / 2, handle.north ? ay - h : ay, w, h);
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/geometry/crop_drag.dart test/core/geometry/crop_drag_test.dart
git commit -m "feat(geometry): drag crop handles with bounds, minimum size and ratio lock"
```

---

### Task 8: Lecteur : rotation, résultat ffprobe, pistes sélectionnées, renommage

**Files:**
- Modify: `lib/features/player/player_controller.dart`
- Test: `test/features/player/player_studio_test.dart`

**Interfaces:**
- Consumes: `ProbeResult` (tâche 2), `Rotation`, `MediaEngine.setRotation`, `ResumeStore.migrate`, `FakeMediaEngine`.
- Produces (ajouts à `PlayerController`) :
  - paramètre de constructeur `Future<void> Function(String from, String to)? renameFile` (défaut : `File(from).rename(to)`) ;
  - `ProbeResult? get probe` (résultat ffprobe du fichier ouvert, `null` avant la fin de l'analyse ou sans ffprobe) ;
  - `Rotation get rotation`, `Future<void> setRotation(Rotation r)` (aperçu `video-rotate`), remise à `Rotation.none` à chaque ouverture ;
  - `int? get videoFfIndex`, `int? get audioFfIndex` (pistes sélectionnées) ;
  - `Future<void> pause()` ;
  - `Future<bool> renameOpenFile(String newPath)` : essai direct ; si Windows refuse (`FileSystemException`), fermer, renommer, rouvrir à la même position et dans le même état de lecture ; si le renommage échoue encore, rouvrir l'original à la même position et renvoyer `false`. La clé de reprise suit le fichier. La position forcée ne déclenche pas de `ResumedEvent`.

- [ ] **Step 1: Écrire le test**

`test/features/player/player_studio_test.dart` :

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';

import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProbeService _probe() => ProbeService(
      'ffprobe',
      run: (_, _) async => ProcessResult(
        1,
        0,
        jsonEncode({
          'streams': [
            {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
          ],
          'format': {'duration': '600.0'},
        }),
        '',
      ),
    );

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late ResumeStore resume;
  late List<PlayerEvent> events;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_player_studio_');
    engine = FakeMediaEngine();
    resume = ResumeStore(dir);
    events = [];
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  PlayerController make({Future<void> Function(String from, String to)? renameFile}) {
    final c = PlayerController(
      engine: engine,
      resume: resume,
      probe: _probe(),
      fileExists: (_) => true,
      renameFile: renameFile,
    );
    c.events.listen(events.add);
    return c;
  }

  test('open resets the rotation, keeps the probe and exposes the selected ff-indexes', () async {
    final c = make();
    await c.setRotation(Rotation.cw90);
    expect(c.rotation, Rotation.cw90);
    engine.tracks = const [
      TrackInfo(type: TrackType.video, id: 1, ffIndex: 0, selected: true),
      TrackInfo(type: TrackType.audio, id: 1, ffIndex: 1),
      TrackInfo(type: TrackType.audio, id: 2, ffIndex: 2, selected: true),
    ];
    await c.open(r'C:\v\a.mkv');
    expect(c.rotation, Rotation.none);
    expect(engine.calls, containsAllInOrder(['video-rotate 90', 'video-rotate 0', r'open C:\v\a.mkv']));
    expect(c.probe!.videoSize, const IntSize(1920, 1080));
    engine.emitTracksChanged();
    await settle();
    expect(c.videoFfIndex, 0);
    expect(c.audioFfIndex, 2);
    await c.pause();
    expect(engine.calls.last, 'pause');
  });

  test('a direct rename moves the resume key without reopening', () async {
    final renamed = <String>[];
    final c = make(renameFile: (from, to) async => renamed.add('$from>$to'));
    await c.open(r'C:\m\track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(const Duration(minutes: 1));
    await settle();
    engine.calls.clear();
    expect(await c.renameOpenFile(r'C:\m\A - B.mp3'), isTrue);
    expect(renamed, [r'C:\m\track.mp3>C:\m\A - B.mp3']);
    expect(c.fileName, 'A - B.mp3');
    expect(engine.calls, isNot(contains('stop')));
    expect(resume.resumePositionFor(r'C:\m\A - B.mp3', const Duration(minutes: 4)), const Duration(minutes: 1));
  });

  test('a refused rename closes, renames and reopens at the same position, still paused', () async {
    var attempts = 0;
    final c = make(renameFile: (from, to) async {
      if (++attempts == 1) throw const FileSystemException('in use');
    });
    await c.open(r'C:\m\track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitPlaying(false);
    await settle();
    engine.calls.clear();
    expect(await c.renameOpenFile(r'C:\m\A - B.mp3'), isTrue);
    expect(engine.calls, containsAllInOrder(['stop', r'open C:\m\A - B.mp3', 'pause']));
    expect(c.fileName, 'A - B.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    await settle();
    expect(engine.calls, contains('seek ${const Duration(minutes: 1).inMilliseconds}'));
    expect(events.whereType<ResumedEvent>(), isEmpty);
  });

  test('a rename refused twice reopens the original file where it was', () async {
    final c = make(renameFile: (from, to) async => throw const FileSystemException('in use'));
    await c.open(r'C:\m\track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitPlaying(true);
    await settle();
    engine.calls.clear();
    expect(await c.renameOpenFile(r'C:\m\A - B.mp3'), isFalse);
    expect(engine.calls, containsAllInOrder(['stop', r'open C:\m\track.mp3']));
    expect(engine.calls, isNot(contains('pause')));
    expect(c.fileName, 'track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    await settle();
    expect(engine.calls, contains('seek ${const Duration(minutes: 1).inMilliseconds}'));
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/player/player_studio_test.dart`
Expected: FAIL à la compilation : `renameFile`, `setRotation`, `rotation`, `probe`… inexistants.

- [ ] **Step 3: Modifier `lib/features/player/player_controller.dart`**

Ajouter les imports :

```dart
import '../../core/ffmpeg/probe_result.dart';
import '../../core/geometry/rotation.dart';
```

Dans le constructeur, après `bool Function(String path)? fileExists,`, ajouter :

```dart
    Future<void> Function(String from, String to)? renameFile,
```

et, dans la liste d'initialisation, après `_fileExists = fileExists ?? ((path) => File(path).existsSync()),`, ajouter :

```dart
        _renameFile = renameFile ?? _renameOnDisk,
```

Après le champ `final bool Function(String path) _fileExists;`, ajouter :

```dart
  final Future<void> Function(String from, String to) _renameFile;

  static Future<void> _renameOnDisk(String from, String to) async {
    await File(from).rename(to);
  }
```

Après le champ `PanMode _pan = PanMode.stereo;`, ajouter :

```dart
  Rotation _rotation = Rotation.none;
  ProbeResult? _probeResult;

  /// Exact position to restore after a reopen (rename), instead of the
  /// saved resume position.
  Duration? _forcedStart;
```

Après le getter `Stream<PlayerEvent> get events => _events.stream;`, ajouter :

```dart
  ProbeResult? get probe => _probeResult;
  Rotation get rotation => _rotation;
  int? get videoFfIndex =>
      _tracks.where((t) => t.type == TrackType.video && t.selected).firstOrNull?.ffIndex;
  int? get audioFfIndex =>
      _tracks.where((t) => t.type == TrackType.audio && t.selected).firstOrNull?.ffIndex;
```

Remplacer toute la méthode `open` :

```dart
  Future<void> open(String path) => _openFile(path);

  Future<void> _openFile(String path, {Duration? startAt}) async {
    if (!_fileExists(path)) {
      _events.add(OpenFailedEvent(path));
      return;
    }
    await saveResume();
    _fallbackPath = _path;
    _path = path;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lastRecorded = Duration.zero;
    _pendingResume = true;
    _forcedStart = startAt;
    _tracks = const [];
    _pan = PanMode.stereo;
    _rotation = Rotation.none;
    _probeResult = null;
    _videoSize = null;
    notifyListeners();
    try {
      await _engine.setPan(PanMode.stereo);
      await _engine.setRotation(Rotation.none);
      await _engine.open(path);
      await _engine.setSubtitleScale(_subtitleScale);
      await _engine.setSubtitlePosition(_subtitlePos);
      final probe = await _probe?.probe(path);
      if (_path == path) {
        _probeResult = probe;
        notifyListeners();
      }
      await _engine.setDeinterlace(probe?.isInterlaced ?? false);
    } on Exception {
      _failOpen(path);
    }
  }
```

Dans `_onDuration`, remplacer le bloc :

```dart
      _pendingResume = false;
      final resumeAt = _resume.resumePositionFor(path, d);
      if (resumeAt != null) {
        unawaited(_engine.seek(resumeAt));
        _events.add(ResumedEvent(resumeAt));
      }
```

par :

```dart
      _pendingResume = false;
      final forced = _forcedStart;
      _forcedStart = null;
      if (forced != null) {
        if (forced > Duration.zero) unawaited(_engine.seek(forced));
      } else {
        final resumeAt = _resume.resumePositionFor(path, d);
        if (resumeAt != null) {
          unawaited(_engine.seek(resumeAt));
          _events.add(ResumedEvent(resumeAt));
        }
      }
```

Après la méthode `togglePlay`, ajouter :

```dart
  Future<void> pause() => _engine.pause();

  Future<void> setRotation(Rotation r) async {
    _rotation = r;
    notifyListeners();
    await _engine.setRotation(r);
  }

  /// Renames the open file. When Windows refuses (the file is in use), closes
  /// it, renames, and reopens it at the same position and play state. Returns
  /// false when the rename is refused even then; the original file is then
  /// reopened where it was.
  Future<bool> renameOpenFile(String newPath) async {
    final from = _path;
    if (from == null) return false;
    if (_position > Duration.zero) _resume.record(from, _position);
    try {
      await _renameFile(from, newPath);
      _resume.migrate(from, newPath);
      _path = newPath;
      notifyListeners();
      await _flushResume();
      return true;
    } on FileSystemException {
      // Probably held open by the player: close it and try again.
    }

    final at = _position;
    final wasPlaying = _playing;
    await close();
    var target = newPath;
    var renamed = true;
    try {
      await _renameFile(from, newPath);
      _resume.migrate(from, newPath);
      await _flushResume();
    } on FileSystemException {
      renamed = false;
      target = from;
    }
    await _openFile(target, startAt: at);
    if (!wasPlaying) await _engine.pause();
    return renamed;
  }
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` (les tests existants du lecteur restent verts : `video-rotate 0` s'ajoute aux appels mais ils utilisent `containsAllInOrder` ou vident la liste) et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/player/player_controller.dart test/features/player/player_studio_test.dart
git commit -m "feat(player): expose rotation, probe and selected tracks, rename the open file safely"
```

---

### Task 9: Contrôleur Studio (rotation, découpe, cadre)

**Files:**
- Create: `lib/features/studio/studio_controller.dart`, `test/support/fake_exporter.dart`
- Test: `test/features/studio/studio_controller_test.dart`

**Interfaces:**
- Consumes: `PlayerController` (`rotation`, `setRotation`, `probe`, `videoSize`, `position`, `duration`, `pause`, `seekTo`, `path`, `hasMedia`), `TrimSelection` (tâche 6), `CropMath.fitPreset`, `CropMath.displayedPictureSize`, `CropMath.displayToSource`, `CropMath.outputSize`, `AspectPreset`, `Exporter` (tâche 5).
- Produces:
  - `class StudioController extends ChangeNotifier { StudioController({required PlayerController player, required Exporter exporter}); }` (la tâche 10 ajoute `DateTime Function()? now`).
  - Événements (émis à partir de la tâche 10) : `sealed class StudioEvent` ; `ExportFinishedEvent(String path)`, `ExportCancelledEvent()`, `ExportFailedEvent(String log)`, `ExportRetriedOnCpuEvent()`, `ExportRejectedEvent(ExportPlanError error)`, `FfmpegMissingEvent(String folder)` ; `class ExportProgress { double fraction; Duration? remaining; }`.
  - État : `bool ffmpegAvailable`, `bool isOpen`, `bool available` (fichier ouvert avec une image), `Rotation rotation`, `bool trimEnabled`, `TrimSelection? trim`, `bool cropEnabled`, `AspectPreset? cropPreset`, `RatioRect crop`, `double? cropLockRatio`, `IntSize? pictureSize` (image affichée), `IntSize? outputSize` (image exportée).
  - Actions : `toggle()` (`E`), `setRotation(Rotation)`, `cycleRotation()` (`R`), `toggleTrim()`, `markIn()` (`I`), `markOut()` (`O`), `setTrim(TrimSelection)`, `nudgeStart(int seconds)`, `nudgeEnd(int seconds)`, `preview(Duration at)` (pause + saut), `toggleCrop()` (`C`), `setCropPreset(AspectPreset?)` (`null` = désactivé), `setCrop(RatioRect)`.
  - À l'ouverture d'un autre fichier : découpe et cadre désactivés, panneau conservé ; fermé si plus aucun fichier n'est ouvert.
  - Test : `class FakeExporter implements Exporter` (tâche suivante pour l'export).

- [ ] **Step 1: Écrire la doublure `test/support/fake_exporter.dart`**

```dart
import 'dart:async';

import 'package:uhf_media/core/system/export_runner.dart';
import 'package:uhf_media/core/system/export_service.dart';

class FakeExporter implements Exporter {
  bool isAvailable = true;
  ExportInput? lastInput;
  Completer<ExportOutcome>? pending;
  void Function(double fraction)? progress;
  void Function()? cpuRetry;
  bool cancelled = false;
  Object? error;

  @override
  bool get available => isAvailable;

  @override
  String get expectedFolder => r'C:\App';

  @override
  Future<ExportOutcome> export(
    ExportInput input, {
    required void Function(double fraction) onProgress,
    void Function()? onCpuRetry,
  }) {
    lastInput = input;
    progress = onProgress;
    cpuRetry = onCpuRetry;
    final e = error;
    if (e != null) return Future.error(e);
    final completer = Completer<ExportOutcome>();
    pending = completer;
    return completer.future;
  }

  @override
  void cancel() {
    cancelled = true;
    final p = pending;
    if (p != null && !p.isCompleted) p.complete(const ExportCancelled());
  }
}
```

- [ ] **Step 2: Écrire le test**

`test/features/studio/studio_controller_test.dart` :

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/aspect_preset.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';
import 'package:uhf_media/features/studio/trim_selection.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProbeService probeOf(List<Map<String, Object>> streams) => ProbeService(
      'ffprobe',
      run: (_, _) async => ProcessResult(1, 0, jsonEncode({'streams': streams, 'format': {'duration': '600.0'}}), ''),
    );

final videoProbe = probeOf([
  {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
]);

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeExporter exporter;
  late StudioController studio;

  Future<void> openVideo(String path, {ProbeService? probe}) async {
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      probe: probe ?? videoProbe,
      fileExists: (_) => true,
    );
    studio = StudioController(player: player, exporter: exporter);
    await player.open(path);
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitVideoSize(const IntSize(1920, 1080));
    await settle();
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_studio_');
    engine = FakeMediaEngine();
    exporter = FakeExporter();
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  test('the studio opens only on a file with a picture (review focus 4)', () async {
    // An audio file: no picture size from ffprobe, none from the engine.
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      probe: probeOf([
        {'index': 0, 'codec_type': 'audio', 'codec_name': 'mp3'},
      ]),
      fileExists: (_) => true,
    );
    final audioOnly = StudioController(player: player, exporter: exporter);
    await player.open(r'C:\m\song.mp3');
    engine.emitDuration(const Duration(minutes: 3));
    await settle();
    expect(audioOnly.available, isFalse);
    audioOnly.toggle();
    expect(audioOnly.isOpen, isFalse);

    await openVideo(r'C:\v\a.mkv');
    expect(studio.available, isTrue);
    studio.toggle();
    expect(studio.isOpen, isTrue);
  });

  test('rotation goes through the player and cycles', () async {
    await openVideo(r'C:\v\a.mkv');
    await studio.cycleRotation();
    expect(studio.rotation, Rotation.cw90);
    expect(engine.calls, contains('video-rotate 90'));
    expect(studio.pictureSize, const IntSize(1080, 1920));
    expect(studio.outputSize, const IntSize(1080, 1920));
  });

  test('C turns the crop on with the last preset, centred at 70 %', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggleCrop();
    expect(studio.cropEnabled, isTrue);
    expect(studio.cropPreset, AspectPreset.free);
    expect(studio.crop, CropMath.defaultCrop);
    expect(studio.cropLockRatio, isNull);
    studio.setCropPreset(AspectPreset.r1x1);
    studio.toggleCrop();
    expect(studio.cropEnabled, isFalse);
    studio.toggleCrop();
    expect(studio.cropPreset, AspectPreset.r1x1);
    expect(studio.cropLockRatio, 1);
  });

  test('rotating with a crop refits it to the turned picture (review focus 3)', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.setCropPreset(AspectPreset.r9x16);
    studio.setCrop(const RatioRect(0.6, 0.6, 0.4, 0.4));
    await studio.setRotation(Rotation.cw90);
    expect(studio.crop, CropMath.fitPreset(AspectPreset.r9x16, const IntSize(1080, 1920)));
    final out = studio.outputSize!;
    expect(out.width / out.height, closeTo(9 / 16, 0.01));
  });

  test('the trim starts as 60 s from the position and follows I / O', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggleTrim();
    expect(studio.trim, const TrimSelection(start: Duration(minutes: 1), end: Duration(minutes: 2), duration: Duration(minutes: 10)));
    engine.emitPosition(const Duration(seconds: 90));
    await settle();
    studio.markOut();
    expect(studio.trim!.end, const Duration(seconds: 90));
    studio.toggleTrim();
    expect(studio.trimEnabled, isFalse);
    studio.markIn();
    expect(studio.trim!.start, const Duration(seconds: 90));
  });

  test('O first opens a range ending at the position', () async {
    await openVideo(r'C:\v\a.mkv');
    engine.emitPosition(const Duration(minutes: 5));
    await settle();
    studio.markOut();
    expect(studio.trim, const TrimSelection(start: Duration(minutes: 4), end: Duration(minutes: 5), duration: Duration(minutes: 10)));
  });

  test('nudges move a handle by one second and preview it', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggleTrim();
    engine.calls.clear();
    await studio.nudgeStart(-1);
    expect(studio.trim!.start, const Duration(seconds: 59));
    expect(engine.calls, ['pause', 'seek ${const Duration(seconds: 59).inMilliseconds}']);
    await studio.nudgeEnd(1);
    expect(studio.trim!.end, const Duration(seconds: 121));
  });

  test('opening another file resets the edits but keeps the panel', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggle();
    studio.toggleTrim();
    studio.toggleCrop();
    await player.open(r'C:\v\b.mkv');
    await settle();
    expect(studio.isOpen, isTrue);
    expect(studio.trimEnabled, isFalse);
    expect(studio.cropEnabled, isFalse);
    expect(studio.rotation, Rotation.none);
  });
}
```

- [ ] **Step 3: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/studio/studio_controller_test.dart`
Expected: FAIL, `studio_controller.dart` introuvable.

- [ ] **Step 4: Écrire `lib/features/studio/studio_controller.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/ffmpeg/export_plan.dart';
import '../../core/geometry/aspect_preset.dart';
import '../../core/geometry/crop_math.dart';
import '../../core/geometry/geometry.dart';
import '../../core/geometry/rotation.dart';
import '../../core/system/export_service.dart';
import '../player/player_controller.dart';
import 'trim_selection.dart';

sealed class StudioEvent {
  const StudioEvent();
}

class ExportFinishedEvent extends StudioEvent {
  const ExportFinishedEvent(this.path);
  final String path;
}

class ExportCancelledEvent extends StudioEvent {
  const ExportCancelledEvent();
}

class ExportFailedEvent extends StudioEvent {
  const ExportFailedEvent(this.log);
  final String log;
}

class ExportRetriedOnCpuEvent extends StudioEvent {
  const ExportRetriedOnCpuEvent();
}

class ExportRejectedEvent extends StudioEvent {
  const ExportRejectedEvent(this.error);
  final ExportPlanError error;
}

class FfmpegMissingEvent extends StudioEvent {
  const FfmpegMissingEvent(this.folder);
  final String folder;
}

class ExportProgress {
  const ExportProgress(this.fraction, this.remaining);
  final double fraction;
  final Duration? remaining;
}

class StudioController extends ChangeNotifier {
  StudioController({required PlayerController player, required Exporter exporter})
      : _player = player,
        _exporter = exporter {
    _path = player.path;
    player.addListener(_onPlayerChanged);
  }

  static const _window = Duration(seconds: 60);

  final PlayerController _player;
  final Exporter _exporter;
  final _events = StreamController<StudioEvent>.broadcast();

  String? _path;
  bool _open = false;
  TrimSelection? _trim;
  AspectPreset? _cropPreset;
  AspectPreset _lastPreset = AspectPreset.free;
  RatioRect _crop = CropMath.defaultCrop;

  Stream<StudioEvent> get events => _events.stream;

  /// ffmpeg was found; otherwise exporting shows where to put it.
  bool get ffmpegAvailable => _exporter.available;
  bool get isOpen => _open;
  Rotation get rotation => _player.rotation;
  bool get trimEnabled => _trim != null;
  TrimSelection? get trim => _trim;
  bool get cropEnabled => _cropPreset != null;
  AspectPreset? get cropPreset => _cropPreset;
  RatioRect get crop => _crop;
  double? get cropLockRatio => _cropPreset?.ratio;

  /// Unrotated picture size: ffprobe's coded size, else the engine's.
  IntSize? get _sourceSize => _player.probe?.videoSize ?? _player.videoSize;

  /// A file with a picture is open (audio files have no studio).
  bool get available => _player.hasMedia && _sourceSize != null;

  /// The picture as drawn on screen, rotation included.
  IntSize? get pictureSize {
    final source = _sourceSize;
    return source == null ? null : CropMath.displayedPictureSize(_player.videoSize, source, rotation);
  }

  /// Size of the exported picture.
  IntSize? get outputSize {
    final source = _sourceSize;
    if (source == null) return null;
    if (!cropEnabled) return CropMath.displaySize(source, rotation);
    return CropMath.outputSize(CropMath.displayToSource(_crop, rotation, source), rotation);
  }

  void _onPlayerChanged() {
    final path = _player.path;
    if (path == _path) return;
    _path = path;
    _trim = null;
    _cropPreset = null;
    _crop = CropMath.defaultCrop;
    if (path == null) _open = false;
    notifyListeners();
  }

  void toggle() {
    if (!_open && !available) return;
    _open = !_open;
    notifyListeners();
  }

  Future<void> setRotation(Rotation r) async {
    if (r == rotation) return;
    await _player.setRotation(r);
    final preset = _cropPreset;
    if (preset != null) _crop = _fit(preset);
    notifyListeners();
  }

  Future<void> cycleRotation() => setRotation(rotation.next);

  // Trim ----------------------------------------------------------------

  void toggleTrim() {
    if (_trim != null) {
      _trim = null;
    } else {
      final duration = _player.duration;
      if (duration <= Duration.zero) return;
      _trim = TrimSelection.window(_player.position, duration);
    }
    notifyListeners();
  }

  void markIn() {
    final duration = _player.duration;
    if (duration <= Duration.zero) return;
    final position = _player.position;
    _trim = (_trim ?? TrimSelection.window(position, duration)).withStart(position);
    notifyListeners();
  }

  void markOut() {
    final duration = _player.duration;
    if (duration <= Duration.zero) return;
    final position = _player.position;
    final current = _trim ??
        TrimSelection(
          start: position > _window ? position - _window : Duration.zero,
          end: duration,
          duration: duration,
        );
    _trim = current.withEnd(position);
    notifyListeners();
  }

  void setTrim(TrimSelection selection) {
    if (_trim == null) return;
    _trim = selection;
    notifyListeners();
  }

  Future<void> nudgeStart(int seconds) async {
    final t = _trim;
    if (t == null) return;
    _trim = t.withStart(t.start + Duration(seconds: seconds));
    notifyListeners();
    await preview(_trim!.start);
  }

  Future<void> nudgeEnd(int seconds) async {
    final t = _trim;
    if (t == null) return;
    _trim = t.withEnd(t.end + Duration(seconds: seconds));
    notifyListeners();
    await preview(_trim!.end);
  }

  /// Shows the frame at [at] while a trim handle moves.
  Future<void> preview(Duration at) async {
    await _player.pause();
    await _player.seekTo(at);
  }

  // Crop ----------------------------------------------------------------

  void toggleCrop() => setCropPreset(cropEnabled ? null : _lastPreset);

  /// Choosing a preset recentres the largest frame of that ratio in 70 % of
  /// the picture; null turns the crop off.
  void setCropPreset(AspectPreset? preset) {
    if (preset != null) {
      if (pictureSize == null) return;
      _lastPreset = preset;
      _crop = _fit(preset);
    }
    _cropPreset = preset;
    notifyListeners();
  }

  void setCrop(RatioRect crop) {
    if (!cropEnabled) return;
    _crop = crop;
    notifyListeners();
  }

  RatioRect _fit(AspectPreset preset) {
    final picture = pictureSize;
    return picture == null ? CropMath.defaultCrop : CropMath.fitPreset(preset, picture);
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    unawaited(_events.close());
    super.dispose();
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/studio/studio_controller.dart test/support/fake_exporter.dart test/features/studio/studio_controller_test.dart
git commit -m "feat(studio): add studio controller for rotation, trim and crop"
```

---

### Task 10: Contrôleur Studio : export

**Files:**
- Modify: `lib/features/studio/studio_controller.dart`
- Test: `test/features/studio/studio_export_test.dart`

**Interfaces:**
- Consumes: `Exporter`, `ExportInput`, `ExportOutcome` et ses cas, `ExportPlanException`, `FakeExporter`.
- Produces (ajouts à `StudioController`) : paramètre `DateTime Function()? now` ; `bool exporting`, `ExportProgress? exportProgress` (fraction, temps restant estimé à partir du temps écoulé) ; `Future<void> export()` (`Ctrl+E`, met la lecture en pause, recadrage converti en pixels source) ; `void cancelExport()` ; `Future<void> shutdown()` (annule un export en cours et l'attend au plus 3 s, à la fermeture). Un export continue quand un autre fichier est ouvert.

- [ ] **Step 1: Écrire le test**

`test/features/studio/studio_export_test.dart` :

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/export_runner.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final _probe = ProbeService(
  'ffprobe',
  run: (_, _) async => ProcessResult(
    1,
    0,
    jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
      ],
      'format': {'duration': '600.0'},
    }),
    '',
  ),
);

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeExporter exporter;
  late StudioController studio;
  late List<StudioEvent> events;
  var clock = DateTime(2026, 10, 1, 12);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('uhf_studio_export_');
    engine = FakeMediaEngine();
    exporter = FakeExporter();
    events = [];
    clock = DateTime(2026, 10, 1, 12);
    player = PlayerController(engine: engine, resume: ResumeStore(dir), probe: _probe, fileExists: (_) => true);
    studio = StudioController(player: player, exporter: exporter, now: () => clock);
    studio.events.listen(events.add);
    engine.tracks = const [
      TrackInfo(type: TrackType.video, id: 1, ffIndex: 0, selected: true),
      TrackInfo(type: TrackType.audio, id: 2, ffIndex: 2, selected: true),
    ];
    await player.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitVideoSize(const IntSize(1920, 1080));
    engine.emitTracksChanged();
    await settle();
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  test('nothing to export is rejected without pausing', () async {
    engine.calls.clear();
    await studio.export();
    expect(events.single, isA<ExportRejectedEvent>().having((e) => e.error, 'error', ExportPlanError.noChanges));
    expect(exporter.lastInput, isNull);
    expect(engine.calls, isNot(contains('pause')));
  });

  test('without ffmpeg the event names the expected folder', () async {
    exporter.isAvailable = false;
    await studio.setRotation(Rotation.cw90);
    await studio.export();
    expect(events.single, isA<FfmpegMissingEvent>().having((e) => e.folder, 'folder', r'C:\App'));
  });

  test('export sends the edits in source pixels, pauses and reports progress', () async {
    await studio.setRotation(Rotation.cw90);
    studio.toggleCrop();
    studio.toggleTrim();
    engine.calls.clear();
    final done = studio.export();
    await settle();
    expect(studio.exporting, isTrue);
    expect(engine.calls, contains('pause'));
    final input = exporter.lastInput!;
    expect(input.inputPath, r'C:\v\a.mkv');
    expect(input.rotation, Rotation.cw90);
    expect(input.crop, CropMath.displayToSource(CropMath.defaultCrop, Rotation.cw90, const IntSize(1920, 1080)));
    expect(input.trim!.start, const Duration(minutes: 1));
    expect(input.trim!.end, const Duration(minutes: 2));
    expect(input.videoFfIndex, 0);
    expect(input.audioFfIndex, 2);

    clock = clock.add(const Duration(seconds: 10));
    exporter.progress!(0.25);
    expect(studio.exportProgress!.fraction, 0.25);
    expect(studio.exportProgress!.remaining, const Duration(seconds: 30));

    exporter.cpuRetry!();
    exporter.pending!.complete(const ExportSucceeded(r'C:\v\a_crop_rot90_trim.mkv'));
    await done;
    expect(studio.exporting, isFalse);
    expect(events[0], isA<ExportRetriedOnCpuEvent>());
    expect(events[1], isA<ExportFinishedEvent>().having((e) => e.path, 'path', r'C:\v\a_crop_rot90_trim.mkv'));
  });

  test('cancel stops the export and reports it', () async {
    await studio.setRotation(Rotation.half);
    final done = studio.export();
    await settle();
    studio.cancelExport();
    await done;
    expect(exporter.cancelled, isTrue);
    expect(events.last, isA<ExportCancelledEvent>());
    expect(studio.exporting, isFalse);
  });

  test('a failure carries the ffmpeg log', () async {
    await studio.setRotation(Rotation.half);
    final done = studio.export();
    await settle();
    exporter.pending!.complete(const ExportFailed('Unknown encoder'));
    await done;
    expect(events.last, isA<ExportFailedEvent>().having((e) => e.log, 'log', 'Unknown encoder'));
  });

  test('a plan rejected by the builder becomes an event', () async {
    exporter.error = const ExportPlanException(ExportPlanError.cropTooSmall);
    studio.toggleCrop();
    await studio.export();
    expect(events.last, isA<ExportRejectedEvent>().having((e) => e.error, 'error', ExportPlanError.cropTooSmall));
    expect(studio.exporting, isFalse);
  });

  test('opening another file during an export keeps it running (review focus 1)', () async {
    await studio.setRotation(Rotation.cw90);
    final done = studio.export();
    await settle();
    await player.open(r'C:\v\b.mkv');
    await settle();
    expect(studio.exporting, isTrue);
    expect(studio.rotation, Rotation.none);
    exporter.pending!.complete(const ExportSucceeded(r'C:\v\a_rot90.mkv'));
    await done;
    expect(events.last, isA<ExportFinishedEvent>().having((e) => e.path, 'path', r'C:\v\a_rot90.mkv'));
  });

  test('shutdown cancels a running export and waits for it', () async {
    await studio.setRotation(Rotation.cw90);
    unawaited(studio.export());
    await settle();
    await studio.shutdown();
    expect(exporter.cancelled, isTrue);
    expect(studio.exporting, isFalse);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/studio/studio_export_test.dart`
Expected: FAIL à la compilation : paramètre `now`, `export`, `exporting`… inexistants.

- [ ] **Step 3: Compléter `lib/features/studio/studio_controller.dart`**

Ajouter l'import :

```dart
import '../../core/system/export_runner.dart';
```

Remplacer le constructeur et les champs du haut de la classe :

```dart
  StudioController({required PlayerController player, required Exporter exporter})
      : _player = player,
        _exporter = exporter {
    _path = player.path;
    player.addListener(_onPlayerChanged);
  }

  static const _window = Duration(seconds: 60);

  final PlayerController _player;
  final Exporter _exporter;
  final _events = StreamController<StudioEvent>.broadcast();
```

par :

```dart
  StudioController({required PlayerController player, required Exporter exporter, DateTime Function()? now})
      : _player = player,
        _exporter = exporter,
        _now = now ?? DateTime.now {
    _path = player.path;
    player.addListener(_onPlayerChanged);
  }

  static const _window = Duration(seconds: 60);

  final PlayerController _player;
  final Exporter _exporter;
  final DateTime Function() _now;
  final _events = StreamController<StudioEvent>.broadcast();
  ExportProgress? _export;
  DateTime? _exportStarted;
  Future<void>? _exportFuture;
```

Après le getter `double? get cropLockRatio => _cropPreset?.ratio;`, ajouter :

```dart
  bool get exporting => _export != null;
  ExportProgress? get exportProgress => _export;
```

Avant `@override void dispose()`, ajouter :

```dart
  // Export --------------------------------------------------------------

  Future<void> export() {
    final running = _exportFuture;
    if (running != null) return running;
    final future = _runExport();
    _exportFuture = future;
    return future.whenComplete(() => _exportFuture = null);
  }

  Future<void> _runExport() async {
    final path = _player.path;
    if (path == null) return;
    if (rotation == Rotation.none && !cropEnabled && _trim == null) {
      _events.add(const ExportRejectedEvent(ExportPlanError.noChanges));
      return;
    }
    final probe = _player.probe;
    if (!_exporter.available || probe == null) {
      _events.add(FfmpegMissingEvent(_exporter.expectedFolder));
      return;
    }
    final source = probe.videoSize ?? _sourceSize;
    final input = ExportInput(
      inputPath: path,
      probe: probe,
      rotation: rotation,
      crop: cropEnabled && source != null ? CropMath.displayToSource(_crop, rotation, source) : null,
      trim: _trim?.range,
      videoFfIndex: _player.videoFfIndex,
      audioFfIndex: _player.audioFfIndex,
    );

    await _player.pause();
    _exportStarted = _now();
    _export = const ExportProgress(0, null);
    notifyListeners();
    try {
      final outcome = await _exporter.export(
        input,
        onProgress: _onProgress,
        onCpuRetry: () => _events.add(const ExportRetriedOnCpuEvent()),
      );
      _events.add(switch (outcome) {
        ExportSucceeded(:final outputPath) => ExportFinishedEvent(outputPath),
        ExportCancelled() => const ExportCancelledEvent(),
        ExportFailed(:final log) => ExportFailedEvent(log),
      });
    } on ExportPlanException catch (e) {
      _events.add(ExportRejectedEvent(e.error));
    } finally {
      _export = null;
      _exportStarted = null;
      notifyListeners();
    }
  }

  void _onProgress(double fraction) {
    final started = _exportStarted;
    if (started == null) return;
    final elapsed = _now().difference(started);
    final remaining = fraction > 0.01
        ? Duration(microseconds: (elapsed.inMicroseconds * (1 - fraction) / fraction).round())
        : null;
    _export = ExportProgress(fraction, remaining);
    notifyListeners();
  }

  void cancelExport() => _exporter.cancel();

  /// On app close: stops a running export and waits (3 s at most) for
  /// ffmpeg to quit and the partial file to be removed.
  Future<void> shutdown() async {
    final running = _exportFuture;
    if (running == null) return;
    _exporter.cancel();
    await running.timeout(const Duration(seconds: 3), onTimeout: () {});
  }
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/studio/studio_controller.dart test/features/studio/studio_export_test.dart
git commit -m "feat(studio): export with progress, remaining time, cancel and CPU retry events"
```

---

### Task 11: Timeline de découpe

**Files:**
- Create: `lib/features/studio/trim_timeline.dart`
- Test: `test/features/studio/trim_timeline_test.dart`

**Interfaces:**
- Consumes: `TrimSelection`, `TrimHandle` (tâche 6), `UhfColors`, `harness`.
- Produces: `class TrimTimeline extends StatefulWidget { const TrimTimeline({super.key, required TrimSelection selection, required Duration position, required ValueChanged<TrimSelection> onChanged, required ValueChanged<Duration> onPreview}); static const double height = 28; }` — appui sur une poignée (±8 px) : glissement de la poignée ; appui dans la plage : déplacement de la plage ; appui hors plage : la poignée la plus proche saute au point et suit le glissement. Chaque changement appelle `onChanged` puis `onPreview` (instant de la poignée, ou début de la plage).

- [ ] **Step 1: Écrire le test**

`test/features/studio/trim_timeline_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/features/studio/trim_selection.dart';
import 'package:uhf_media/features/studio/trim_timeline.dart';

import '../../support/harness.dart';

Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  late TrimSelection selection;
  late List<Duration> previews;

  // 600 px for 600 s: one pixel per second.
  Future<Offset Function(double x)> pump(WidgetTester tester) async {
    selection = TrimSelection(start: s(120), end: s(240), duration: s(600));
    previews = [];
    await tester.pumpWidget(harness(Center(
      child: SizedBox(
        width: 600,
        child: StatefulBuilder(
          builder: (context, setState) => TrimTimeline(
            selection: selection,
            position: Duration.zero,
            onChanged: (next) => setState(() => selection = next),
            onPreview: previews.add,
          ),
        ),
      ),
    )));
    final origin = tester.getTopLeft(find.byType(TrimTimeline));
    return (x) => origin + Offset(x, TrimTimeline.height / 2);
  }

  testWidgets('dragging the start handle moves it and previews it', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(120), const Offset(30, 0));
    await tester.pump();
    expect(selection.start, s(150));
    expect(selection.end, s(240));
    expect(previews.last, s(150));
  });

  testWidgets('a click outside the range moves the nearest handle there', (tester) async {
    final at = await pump(tester);
    await tester.tapAt(at(500));
    await tester.pump();
    expect(selection.end, s(500));
    expect(previews.last, s(500));
  });

  testWidgets('dragging inside the range moves the whole range', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(180), const Offset(100, 0));
    await tester.pump();
    expect(selection.start, s(220));
    expect(selection.end, s(340));
    expect(previews.last, s(220));
  });

  testWidgets('the start handle stops at the minimal gap before the end', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(120), const Offset(300, 0));
    await tester.pump();
    expect(selection.start, s(237));
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/studio/trim_timeline_test.dart`
Expected: FAIL, `trim_timeline.dart` introuvable.

- [ ] **Step 3: Écrire `lib/features/studio/trim_timeline.dart`**

```dart
import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import 'trim_selection.dart';

class TrimTimeline extends StatefulWidget {
  const TrimTimeline({
    super.key,
    required this.selection,
    required this.position,
    required this.onChanged,
    required this.onPreview,
  });

  final TrimSelection selection;
  final Duration position;
  final ValueChanged<TrimSelection> onChanged;
  final ValueChanged<Duration> onPreview;

  static const double height = 28;

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

enum _Drag { start, end, range }

class _TrimTimelineState extends State<TrimTimeline> {
  static const _grab = 8.0;

  _Drag? _drag;
  double _anchorX = 0;
  TrimSelection? _anchor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final total = widget.selection.duration.inMicroseconds;
      double xOf(Duration d) => total <= 0 || width <= 0 ? 0 : width * d.inMicroseconds / total;
      Duration at(double x) => total <= 0 || width <= 0
          ? Duration.zero
          : Duration(microseconds: (total * (x / width).clamp(0.0, 1.0)).round());

      void apply(TrimSelection next, Duration preview) {
        widget.onChanged(next);
        widget.onPreview(preview);
      }

      return MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            final s = widget.selection;
            final x = d.localPosition.dx;
            final toStart = (x - xOf(s.start)).abs();
            final toEnd = (x - xOf(s.end)).abs();
            if (toStart <= _grab && toStart <= toEnd) {
              _drag = _Drag.start;
              widget.onPreview(s.start);
            } else if (toEnd <= _grab) {
              _drag = _Drag.end;
              widget.onPreview(s.end);
            } else if (x > xOf(s.start) && x < xOf(s.end)) {
              _drag = _Drag.range;
              _anchorX = x;
              _anchor = s;
              widget.onPreview(s.start);
            } else if (s.nearestHandle(at(x)) == TrimHandle.start) {
              _drag = _Drag.start;
              final next = s.withStart(at(x));
              apply(next, next.start);
            } else {
              _drag = _Drag.end;
              final next = s.withEnd(at(x));
              apply(next, next.end);
            }
          },
          onPanUpdate: (d) {
            final s = widget.selection;
            final x = d.localPosition.dx;
            switch (_drag) {
              case _Drag.start:
                final next = s.withStart(at(x));
                apply(next, next.start);
              case _Drag.end:
                final next = s.withEnd(at(x));
                apply(next, next.end);
              case _Drag.range:
                final shift = width <= 0 ? 0.0 : (x - _anchorX) / width;
                final next = _anchor!.moveBy(Duration(microseconds: (total * shift).round()));
                apply(next, next.start);
              case null:
                break;
            }
          },
          onPanEnd: (_) => _drag = null,
          onPanCancel: () => _drag = null,
          child: CustomPaint(
            size: Size(width, TrimTimeline.height),
            painter: _TrimPainter(
              start: xOf(widget.selection.start),
              end: xOf(widget.selection.end),
              playhead: xOf(widget.position),
            ),
          ),
        ),
      );
    });
  }
}

class _TrimPainter extends CustomPainter {
  _TrimPainter({required this.start, required this.end, required this.playhead});

  final double start;
  final double end;
  final double playhead;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    canvas.drawRect(Rect.fromLTWH(0, midY - 1, size.width, 2), Paint()..color = UhfColors.line);
    final range = Rect.fromLTRB(start, midY - 6, end, midY + 6);
    canvas.drawRect(range, Paint()..color = UhfColors.signal.withValues(alpha: 0.25));
    final edge = Paint()..color = UhfColors.signal;
    canvas.drawRect(Rect.fromLTWH(start - 1, 2, 2, size.height - 4), edge);
    canvas.drawRect(Rect.fromLTWH(end - 1, 2, 2, size.height - 4), edge);
    canvas.drawRect(Rect.fromLTWH(playhead, 4, 1, size.height - 8), Paint()..color = UhfColors.text);
  }

  @override
  bool shouldRepaint(_TrimPainter old) => old.start != start || old.end != end || old.playhead != playhead;
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/studio/trim_timeline.dart test/features/studio/trim_timeline_test.dart
git commit -m "feat(studio): add trim timeline with handles, range drag and live preview"
```

---

### Task 12: Cadre de recadrage

**Files:**
- Create: `lib/features/studio/crop_overlay.dart`
- Test: `test/features/studio/crop_overlay_test.dart`

**Interfaces:**
- Consumes: `dragCrop`, `CropHandle` (tâche 7), `RatioRect`, `UhfColors`, `UhfText`.
- Produces: `class CropOverlay extends StatefulWidget { const CropOverlay({super.key, required RatioRect crop, required double? lockRatio, required String label, required ValueChanged<RatioRect> onChanged}); }` — à placer exactement sur l'image affichée ; poignées saisissables à 12 px ; glissement hors du cadre sans effet.

- [ ] **Step 1: Écrire le test**

`test/features/studio/crop_overlay_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/features/studio/crop_overlay.dart';

import '../../support/harness.dart';

void main() {
  late RatioRect crop;

  // Picture of 1000 x 500 px, crop at (100, 50) - (600, 300).
  Future<Offset Function(double x, double y)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    crop = const RatioRect(0.1, 0.1, 0.5, 0.5);
    await tester.pumpWidget(harness(Center(
      child: SizedBox(
        width: 1000,
        height: 500,
        child: StatefulBuilder(
          builder: (context, setState) => CropOverlay(
            crop: crop,
            lockRatio: null,
            label: '960 × 540 · 16:9',
            onChanged: (next) => setState(() => crop = next),
          ),
        ),
      ),
    )));
    final origin = tester.getTopLeft(find.byType(CropOverlay));
    return (x, y) => origin + Offset(x, y);
  }

  testWidgets('the bottom-right corner resizes the frame', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(600, 300), const Offset(100, 50));
    await tester.pump();
    expect(crop.width, closeTo(0.6, 1e-9));
    expect(crop.height, closeTo(0.6, 1e-9));
    expect(crop.left, closeTo(0.1, 1e-9));
  });

  testWidgets('dragging inside moves the frame', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(300, 150), const Offset(100, 50));
    await tester.pump();
    expect(crop.left, closeTo(0.2, 1e-9));
    expect(crop.top, closeTo(0.2, 1e-9));
    expect(crop.width, closeTo(0.5, 1e-9));
  });

  testWidgets('dragging outside the frame changes nothing', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(900, 450), const Offset(-100, -50));
    await tester.pump();
    expect(crop, const RatioRect(0.1, 0.1, 0.5, 0.5));
  });

  testWidgets('the output label is shown', (tester) async {
    await pump(tester);
    expect(find.text('960 × 540 · 16:9'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/studio/crop_overlay_test.dart`
Expected: FAIL, `crop_overlay.dart` introuvable.

- [ ] **Step 3: Écrire `lib/features/studio/crop_overlay.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/geometry/crop_drag.dart';
import '../../core/geometry/geometry.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';

class CropOverlay extends StatefulWidget {
  const CropOverlay({
    super.key,
    required this.crop,
    required this.lockRatio,
    required this.label,
    required this.onChanged,
  });

  /// Fractions of the displayed picture this widget covers exactly.
  final RatioRect crop;

  /// Width / height of the output picture, null when free.
  final double? lockRatio;
  final String label;
  final ValueChanged<RatioRect> onChanged;

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  static const _grab = 12.0;

  CropHandle? _handle;
  RatioRect? _startCrop;
  Offset _startPoint = Offset.zero;

  CropHandle? _hit(Offset p, Rect f) {
    bool near(Offset corner) => (p - corner).distance <= _grab;
    if (near(f.topLeft)) return CropHandle.nw;
    if (near(f.topRight)) return CropHandle.ne;
    if (near(f.bottomLeft)) return CropHandle.sw;
    if (near(f.bottomRight)) return CropHandle.se;
    final inX = p.dx >= f.left && p.dx <= f.right;
    final inY = p.dy >= f.top && p.dy <= f.bottom;
    if (inX && (p.dy - f.top).abs() <= _grab) return CropHandle.n;
    if (inX && (p.dy - f.bottom).abs() <= _grab) return CropHandle.s;
    if (inY && (p.dx - f.left).abs() <= _grab) return CropHandle.w;
    if (inY && (p.dx - f.right).abs() <= _grab) return CropHandle.e;
    if (f.contains(p)) return CropHandle.move;
    return null;
  }

  void _end() => setState(() {
        _handle = null;
        _startCrop = null;
      });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final c = widget.crop;
      final frame = Rect.fromLTWH(
        c.left * size.width,
        c.top * size.height,
        c.width * size.width,
        c.height * size.height,
      );
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (d) => setState(() {
          _handle = _hit(d.localPosition, frame);
          _startCrop = widget.crop;
          _startPoint = d.localPosition;
        }),
        onPanUpdate: (d) {
          final handle = _handle;
          final start = _startCrop;
          if (handle == null || start == null) return;
          final delta = d.localPosition - _startPoint;
          widget.onChanged(dragCrop(
            start,
            handle,
            delta.dx,
            delta.dy,
            pictureWidth: size.width,
            pictureHeight: size.height,
            lockRatio: widget.lockRatio,
          ));
        },
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CropPainter(frame, thirds: _handle != null))),
            Positioned(
              left: frame.left,
              top: math.max(0, frame.top - 20),
              child: IgnorePointer(child: Text(widget.label, style: UhfText.mono(size: 11))),
            ),
          ],
        ),
      );
    });
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.frame, {required this.thirds});

  final Rect frame;
  final bool thirds;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(outside, Paint()..color = UhfColors.ink.withValues(alpha: 0.7));

    canvas.drawRect(
      frame.deflate(0.5),
      Paint()
        ..color = UhfColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (thirds) {
      final faint = Paint()
        ..color = UhfColors.text.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (var i = 1; i <= 2; i++) {
        final x = frame.left + frame.width * i / 3;
        final y = frame.top + frame.height * i / 3;
        canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), faint);
        canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), faint);
      }
    }

    final handle = Paint()
      ..color = UhfColors.text
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    const arm = 12.0;
    void corner(Offset p, double sx, double sy) {
      canvas.drawLine(p, p + Offset(arm * sx, 0), handle);
      canvas.drawLine(p, p + Offset(0, arm * sy), handle);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);
    const half = 8.0;
    canvas.drawLine(frame.topCenter - const Offset(half, 0), frame.topCenter + const Offset(half, 0), handle);
    canvas.drawLine(frame.bottomCenter - const Offset(half, 0), frame.bottomCenter + const Offset(half, 0), handle);
    canvas.drawLine(frame.centerLeft - const Offset(0, half), frame.centerLeft + const Offset(0, half), handle);
    canvas.drawLine(frame.centerRight - const Offset(0, half), frame.centerRight + const Offset(0, half), handle);
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.frame != frame || old.thirds != thirds;
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/studio/crop_overlay.dart test/features/studio/crop_overlay_test.dart
git commit -m "feat(studio): add crop frame with handles, thirds and output label"
```

---

### Task 13: Panneau Studio

**Files:**
- Create: `lib/ui/uhf_chip.dart`, `lib/features/studio/studio_panel.dart`
- Test: `test/features/studio/studio_panel_test.dart`

**Interfaces:**
- Consumes: `StudioController` (tâches 9-10), `PlayerController`, `TrimTimeline`, `UhfIconButton`, `UhfMenuButton`, `UhfMenuEntry`, `AspectPreset`, `formatTimecode`, `reducedRatio`, `AppLocalizations`, `FakeExporter`, `FakeMediaEngine`.
- Produces:
  - `class UhfChip extends StatefulWidget { const UhfChip({super.key, required String label, required VoidCallback? onPressed, bool selected = false, IconData? icon, bool mono = false}); }` — sans focus ; contour `signal` et texte `signal` quand sélectionnée.
  - `class StudioPanel extends StatelessWidget { const StudioPanel({super.key, required StudioController studio, required PlayerController player, ValueChanged<bool>? onMenuOpenChanged}); static String rotationLabel(Rotation r); }` — découpe (timeline + entrée / sortie ±1 s + durée) quand elle est active ; rangée : rotations `0°` `90°` `−90°` `180°`, *Découpe*, menu du cadre, dimensions de sortie, *Exporter* ; pendant l'export, la rangée laisse place à la barre de progression, au pourcentage, au temps restant et à *Annuler*.

- [ ] **Step 1: Écrire le test**

`test/features/studio/studio_panel_test.dart` :

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/aspect_preset.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';
import 'package:uhf_media/features/studio/studio_panel.dart';
import 'package:uhf_media/features/studio/trim_timeline.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeExporter exporter;
  late StudioController studio;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_studio_panel_');
    engine = FakeMediaEngine();
    exporter = FakeExporter();
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      probe: ProbeService(
        'ffprobe',
        run: (_, _) async => ProcessResult(
          1,
          0,
          jsonEncode({
            'streams': [
              {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
            ],
            'format': {'duration': '600.0'},
          }),
          '',
        ),
      ),
    );
    studio = StudioController(player: player, exporter: exporter);
  });
  // Resume positions are flushed in the background: retry while a write
  // still holds a file open.
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await player.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitVideoSize(const IntSize(1920, 1080));
    await tester.pumpWidget(harness(Align(
      alignment: Alignment.bottomCenter,
      child: StudioPanel(studio: studio, player: player),
    )));
    await tester.pump();
  }

  testWidgets('rotation chips and output size', (tester) async {
    await pump(tester);
    expect(find.text('1920 × 1080 · 16:9'), findsOneWidget);
    await tester.tap(find.text('90°'));
    await tester.pump();
    expect(studio.rotation, Rotation.cw90);
    expect(find.text('1080 × 1920 · 9:16'), findsOneWidget);
  });

  testWidgets('the trim chip shows the trim timeline and its nudges', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Trim'));
    await tester.pump();
    expect(find.byType(TrimTimeline), findsOneWidget);
    expect(find.text('00:02:00'), findsOneWidget);
    await tester.tap(find.byTooltip('+1 s').first);
    await tester.pump();
    expect(studio.trim!.start, const Duration(seconds: 61));
  });

  testWidgets('the crop menu picks a ratio', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Crop (C)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    expect(studio.cropPreset, AspectPreset.r1x1);
    expect(find.text('756 × 756 · 1:1'), findsOneWidget);
  });

  testWidgets('exporting replaces the row with progress and Cancel', (tester) async {
    await pump(tester);
    await tester.tap(find.text('90°'));
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump();
    expect(exporter.lastInput, isNotNull);
    expect(find.text('0 %'), findsOneWidget);
    expect(find.text('90°'), findsNothing);
    exporter.progress!(0.42);
    await tester.pump();
    expect(find.text('42 %'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();
    expect(exporter.cancelled, isTrue);
    expect(find.text('Export'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/studio/studio_panel_test.dart`
Expected: FAIL, `studio_panel.dart` introuvable.

- [ ] **Step 3: Écrire `lib/ui/uhf_chip.dart`**

```dart
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Small toggle with a 1 px outline; never takes keyboard focus.
class UhfChip extends StatefulWidget {
  const UhfChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.icon,
    this.mono = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final IconData? icon;
  final bool mono;

  @override
  State<UhfChip> createState() => _UhfChipState();
}

class _UhfChipState extends State<UhfChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = widget.selected
        ? UhfColors.signal
        : enabled
            ? UhfColors.text
            : UhfColors.textMuted;
    final style = widget.mono ? UhfText.mono(size: 12, color: color) : UhfText.sans(size: 12, color: color);
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: UhfDurations.fast,
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hover && enabled ? UhfColors.text.withValues(alpha: 0.06) : Colors.transparent,
              border: Border.all(color: widget.selected ? UhfColors.signal : UhfColors.line),
              borderRadius: BorderRadius.circular(UhfRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, weight: 300, color: color),
                  const SizedBox(width: 6),
                ],
                Text(widget.label, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Écrire `lib/features/studio/studio_panel.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/geometry/aspect_preset.dart';
import '../../core/geometry/rotation.dart';
import '../../core/util/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_chip.dart';
import '../../ui/uhf_icon_button.dart';
import '../../ui/uhf_menu.dart';
import '../player/player_controller.dart';
import 'studio_controller.dart';
import 'trim_selection.dart';
import 'trim_timeline.dart';

class StudioPanel extends StatelessWidget {
  const StudioPanel({super.key, required this.studio, required this.player, this.onMenuOpenChanged});

  final StudioController studio;
  final PlayerController player;
  final ValueChanged<bool>? onMenuOpenChanged;

  static String rotationLabel(Rotation r) => switch (r) {
        Rotation.none => '0°',
        Rotation.cw90 => '90°',
        Rotation.ccw90 => '−90°',
        Rotation.half => '180°',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([studio, player]),
      builder: (context, _) {
        final trim = studio.trim;
        return Container(
          decoration: const BoxDecoration(
            color: UhfColors.surface,
            border: Border(top: BorderSide(color: UhfColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (trim != null) ...[
                TrimTimeline(
                  selection: trim,
                  position: player.position,
                  onChanged: studio.setTrim,
                  onPreview: studio.preview,
                ),
                const SizedBox(height: 6),
                _TrimRow(studio: studio, trim: trim),
                const SizedBox(height: 10),
              ],
              if (studio.exporting) _ExportBar(studio: studio) else _EditRow(studio: studio, onMenuOpenChanged: onMenuOpenChanged),
            ],
          ),
        );
      },
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.studio, required this.onMenuOpenChanged});

  final StudioController studio;
  final ValueChanged<bool>? onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final out = studio.outputSize;
    return Row(
      children: [
        for (final r in Rotation.values) ...[
          UhfChip(
            label: StudioPanel.rotationLabel(r),
            mono: true,
            selected: studio.rotation == r,
            onPressed: () => studio.setRotation(r),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 8),
        UhfChip(
          icon: Symbols.content_cut_sharp,
          label: l.studioTrim,
          selected: studio.trimEnabled,
          onPressed: studio.toggleTrim,
        ),
        const SizedBox(width: 4),
        UhfMenuButton(
          icon: Symbols.crop_sharp,
          tooltip: l.tooltipCrop,
          active: studio.cropEnabled,
          onOpenChanged: onMenuOpenChanged,
          entries: [
            UhfMenuEntry(
              label: l.cropOff,
              checked: !studio.cropEnabled,
              onSelected: () => studio.setCropPreset(null),
            ),
            for (final p in AspectPreset.values)
              UhfMenuEntry(
                label: p == AspectPreset.free ? l.cropFree : p.label,
                checked: studio.cropPreset == p,
                onSelected: () => studio.setCropPreset(p),
              ),
          ],
        ),
        const SizedBox(width: 12),
        if (out != null)
          Text(
            '${out.width} × ${out.height} · ${reducedRatio(out.width, out.height)}',
            style: UhfText.mono(size: 12, color: UhfColors.textMuted),
          ),
        const Spacer(),
        _ExportButton(label: l.actionExport, onPressed: studio.export),
      ],
    );
  }
}

class _TrimRow extends StatelessWidget {
  const _TrimRow({required this.studio, required this.trim});

  final StudioController studio;
  final TrimSelection trim;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = UhfText.sans(size: 11, color: UhfColors.textMuted);
    Widget nudge(IconData icon, String tooltip, VoidCallback onPressed) =>
        UhfIconButton(icon: icon, tooltip: tooltip, size: 24, iconSize: 16, onPressed: onPressed);
    return Row(
      children: [
        Text(l.studioIn, style: label),
        const SizedBox(width: 6),
        Text(formatTimecode(trim.start), style: UhfText.mono(size: 12)),
        nudge(Symbols.remove_sharp, '−1 s', () => studio.nudgeStart(-1)),
        nudge(Symbols.add_sharp, '+1 s', () => studio.nudgeStart(1)),
        const SizedBox(width: 16),
        Text(l.studioOut, style: label),
        const SizedBox(width: 6),
        Text(formatTimecode(trim.end), style: UhfText.mono(size: 12)),
        nudge(Symbols.remove_sharp, '−1 s', () => studio.nudgeEnd(-1)),
        nudge(Symbols.add_sharp, '+1 s', () => studio.nudgeEnd(1)),
        const Spacer(),
        Text(formatTimecode(trim.length), style: UhfText.mono(size: 12, color: UhfColors.textMuted)),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UhfColors.signal,
              borderRadius: BorderRadius.circular(UhfRadii.sm),
            ),
            child: Text(label, style: UhfText.sans(size: 13, weight: 500, color: UhfColors.ink)),
          ),
        ),
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.studio});

  final StudioController studio;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final progress = studio.exportProgress!;
    final remaining = progress.remaining;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: UhfColors.line),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.fraction.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: const ColoredBox(color: UhfColors.signal),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${(progress.fraction * 100).floor()} %', style: UhfText.mono(size: 12)),
          if (remaining != null) ...[
            const SizedBox(width: 12),
            Text(
              l.exportRemaining(formatTimecode(remaining)),
              style: UhfText.mono(size: 12, color: UhfColors.textMuted),
            ),
          ],
          const SizedBox(width: 12),
          UhfChip(label: l.actionCancel, onPressed: studio.cancelExport),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/ui/uhf_chip.dart lib/features/studio/studio_panel.dart test/features/studio/studio_panel_test.dart
git commit -m "feat(studio): add docked studio panel with trim row, crop menu and export bar"
```

---

### Task 14: Studio dans l'écran principal

**Files:**
- Modify: `lib/features/player/controls_overlay.dart`, `lib/features/shell/app_shell.dart`, `lib/main.dart`
- Test: `test/features/shell/app_shell_studio_test.dart`

**Interfaces:**
- Consumes: `StudioController`, `StudioEvent` et ses cas, `StudioPanel`, `CropOverlay`, `CropMath.videoRectInViewport`, `ExportService`, `FfmpegLocator.executableDir`, `ExportPlanError`.
- Produces:
  - `ControlsOverlay` : paramètre optionnel `StudioController? studio` ; bouton Studio (`Symbols.movie_edit_sharp`, actif quand le panneau est ouvert, désactivé sans image) avant le bouton plein écran.
  - `AppShell` : paramètre optionnel `StudioController? studio`. Studio ouvert : la vidéo se réduit, les contrôles de lecture passent sous la vidéo (toujours visibles), puis le panneau Studio ; rien ne recouvre la vidéo sauf le cadre de recadrage, posé exactement sur l'image. Raccourcis `E`, et dans le Studio `I`, `O`, `R`, `C`, `Ctrl+E`. Événements Studio traduits en messages (*Afficher* après un export, *Copier le détail* après un échec).
  - `main.dart` : `ExportService` + `StudioController` ; à la fermeture, `studio.shutdown()` avant les sauvegardes.

- [ ] **Step 1: Écrire le test**

`test/features/shell/app_shell_studio_test.dart` :

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/app_shell.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/features/studio/crop_overlay.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';
import 'package:uhf_media/features/studio/studio_panel.dart';
import 'package:uhf_media/features/studio/trim_timeline.dart';
import 'package:uhf_media/ui/toast.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late StudioController studio;
  late ToastController toasts;
  late SettingsController settings;
  late ShellController shell;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_shell_studio_');
    engine = FakeMediaEngine();
    player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => true);
    studio = StudioController(player: player, exporter: FakeExporter());
    toasts = ToastController();
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    shell = ShellController(FakeWindowHost(), settings);
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    toasts.dispose();
  }

  Future<void> pumpShell(WidgetTester tester, {bool withPicture = true}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(AppShell(
      player: player,
      shell: shell,
      settings: settings,
      toasts: toasts,
      studio: studio,
      videoBuilder: (_) => const ColoredBox(key: Key('video'), color: Colors.black),
      pickFile: (_) async => null,
      revealFile: (_) {},
    )));
    await player.open(withPicture ? r'C:\v\a.mkv' : r'C:\m\song.mp3');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    if (withPicture) engine.emitVideoSize(const IntSize(1920, 1080));
    await tester.pump();
  }

  testWidgets('E opens the studio; R, I and C act inside it', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byType(StudioPanel), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(engine.calls, contains('video-rotate 90'));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    expect(find.byType(TrimTimeline), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(find.byType(CropOverlay), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byType(StudioPanel), findsNothing);
    await finish(tester);
  });

  testWidgets('studio keys do nothing outside the studio', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(engine.calls, isNot(contains('video-rotate 90')));
    expect(find.byType(CropOverlay), findsNothing);
    await finish(tester);
  });

  testWidgets('Ctrl+E without edits explains what to choose', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(find.text('Choose a rotation, a crop or a trim first'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the studio button opens the panel', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Studio (E)'));
    await tester.pump();
    expect(find.byType(StudioPanel), findsOneWidget);
    await finish(tester);
  });

  testWidgets('an audio file has no studio (review focus 4)', (tester) async {
    await pumpShell(tester, withPicture: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byType(StudioPanel), findsNothing);
    await finish(tester);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/shell/app_shell_studio_test.dart`
Expected: FAIL à la compilation : `AppShell` n'a pas de paramètre `studio`.

- [ ] **Step 3: Ajouter le bouton Studio à `lib/features/player/controls_overlay.dart`**

Ajouter l'import :

```dart
import '../studio/studio_controller.dart';
```

Dans le constructeur, après `required this.onMenuOpenChanged,`, ajouter `this.studio,` et, après le champ `final ValueChanged<bool> onMenuOpenChanged;`, ajouter :

```dart
  final StudioController? studio;
```

Remplacer `listenable: Listenable.merge([player, shell, settings, visibility]),` par :

```dart
      listenable: Listenable.merge([player, shell, settings, visibility, ?studio]),
```

Dans le `builder`, après `final l = AppLocalizations.of(context);`, ajouter :

```dart
        final studio = this.studio;
```

Avant le `UhfIconButton` du plein écran (celui dont l'icône est `Symbols.fullscreen_exit_sharp` / `Symbols.fullscreen_sharp`), ajouter :

```dart
                      if (studio != null)
                        UhfIconButton(
                          icon: Symbols.movie_edit_sharp,
                          tooltip: l.tooltipStudio,
                          active: studio.isOpen,
                          onPressed: studio.available ? studio.toggle : null,
                        ),
```

Si l'analyseur refuse l'élément de liste nul `?studio` (Dart 3.8+ requis), écrire à la place `if (studio != null) studio!` dans la liste — `Listenable.merge` accepte une liste d'éléments nullables.

- [ ] **Step 4: Modifier `lib/features/shell/app_shell.dart`**

Ajouter les imports :

```dart
import '../../core/ffmpeg/export_plan.dart';
import '../../core/geometry/crop_math.dart';
import '../../core/geometry/rotation.dart';
import '../studio/crop_overlay.dart';
import '../studio/studio_controller.dart';
import '../studio/studio_panel.dart';
```

Dans le constructeur d'`AppShell`, après `required this.revealFile,`, ajouter `this.studio,` et, après le champ `final void Function(String path) revealFile;`, ajouter :

```dart
  final StudioController? studio;
```

Dans `_AppShellState`, après `final _focus = FocusNode(debugLabel: 'app-shell');`, ajouter :

```dart
  // Under the video in the studio: always shown.
  final _studioVisibility = ControlsVisibility();
  StreamSubscription<StudioEvent>? _studioEvents;

  StudioController? get _studio => widget.studio;
  bool get _studioOpen => _studio?.isOpen ?? false;
```

Dans `initState`, après `_player.addListener(_onPlayerChanged);`, ajouter :

```dart
    _studioEvents = _studio?.events.listen(_onStudioEvent);
```

Dans `dispose`, après `unawaited(_events.cancel());`, ajouter :

```dart
    unawaited(_studioEvents?.cancel());
    _studioVisibility.dispose();
```

Après la méthode `_onEvent`, ajouter :

```dart
  void _onStudioEvent(StudioEvent event) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final toasts = widget.toasts;
    switch (event) {
      case ExportFinishedEvent(:final path):
        toasts.show(l.toastExportDone, actionLabel: l.actionShow, onAction: () => widget.revealFile(path));
      case ExportCancelledEvent():
        toasts.show(l.toastExportCancelled);
      case ExportFailedEvent(:final log):
        toasts.show(
          l.toastExportFailed,
          actionLabel: l.actionCopyDetails,
          onAction: () => Clipboard.setData(ClipboardData(text: log)),
        );
      case ExportRetriedOnCpuEvent():
        toasts.show(l.toastExportRetryCpu);
      case ExportRejectedEvent(:final error):
        toasts.show(switch (error) {
          ExportPlanError.noChanges => l.toastNoChanges,
          ExportPlanError.trimTooShort => l.toastTrimTooShort,
          ExportPlanError.cropTooSmall => l.toastCropTooSmall,
        });
      case FfmpegMissingEvent(:final folder):
        toasts.show(l.toastFfmpegMissing(folder));
    }
  }

  void _inStudio(void Function(StudioController studio) action) {
    final studio = _studio;
    if (studio != null && studio.isOpen) action(studio);
  }
```

Dans le getter `_bindings`, après la ligne de `Ctrl+T`, ajouter :

```dart
        const SingleActivator(LogicalKeyboardKey.keyE, includeRepeats: false): () => _studio?.toggle(),
        const SingleActivator(LogicalKeyboardKey.keyI): () => _inStudio((s) => s.markIn()),
        const SingleActivator(LogicalKeyboardKey.keyO): () => _inStudio((s) => s.markOut()),
        const SingleActivator(LogicalKeyboardKey.keyR, includeRepeats: false): () => _inStudio((s) => s.cycleRotation()),
        const SingleActivator(LogicalKeyboardKey.keyC, includeRepeats: false): () => _inStudio((s) => s.toggleCrop()),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () => _inStudio((s) => s.export()),
```

Dans `build`, remplacer :

```dart
            child: ListenableBuilder(
              listenable: Listenable.merge([_player, _shell, _visibility]),
              builder: (context, _) => ColoredBox(
                color: UhfColors.ink,
                child: Column(
                  children: [
                    if (!_shell.fullscreen) TitleBar(shell: _shell, fileName: _player.fileName, onOpen: _open),
                    Expanded(child: _stage(context)),
                  ],
                ),
              ),
            ),
```

par :

```dart
            child: ListenableBuilder(
              listenable: Listenable.merge([_player, _shell, _visibility, ?_studio]),
              builder: (context, _) {
                final studio = _studio;
                final docked = studio != null && studio.isOpen && _player.hasMedia && !_shell.fullscreen;
                return ColoredBox(
                  color: UhfColors.ink,
                  child: Column(
                    children: [
                      if (!_shell.fullscreen) TitleBar(shell: _shell, fileName: _player.fileName, onOpen: _open),
                      Expanded(child: _stage(context)),
                      if (docked) ...[
                        ControlsOverlay(
                          player: _player,
                          shell: _shell,
                          settings: widget.settings,
                          visibility: _studioVisibility,
                          onMenuOpenChanged: _onMenuOpenChanged,
                          studio: studio,
                        ),
                        StudioPanel(studio: studio, player: _player, onMenuOpenChanged: _onMenuOpenChanged),
                      ],
                    ],
                  ),
                );
              },
            ),
```

(même remarque que plus haut pour `?_studio`.)

Dans `_stage`, remplacer `final hidden = _player.hasMedia && !_visibility.visible;` par :

```dart
    final studio = _studio;
    final hidden = _player.hasMedia && !_studioOpen && !_visibility.visible;
```

Dans la `Stack` de `_stage`, remplacer le bloc des contrôles superposés :

```dart
          if (_player.hasMedia)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ControlsOverlay(
                player: _player,
                shell: _shell,
                settings: widget.settings,
                visibility: _visibility,
                onMenuOpenChanged: _onMenuOpenChanged,
              ),
            ),
```

par :

```dart
          if (_player.hasMedia && studio != null && studio.isOpen && studio.cropEnabled) _cropLayer(studio),
          if (_player.hasMedia && !(_studioOpen && !_shell.fullscreen))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ControlsOverlay(
                player: _player,
                shell: _shell,
                settings: widget.settings,
                visibility: _visibility,
                onMenuOpenChanged: _onMenuOpenChanged,
                studio: studio,
              ),
            ),
```

Ajouter la méthode à la fin de `_AppShellState` :

```dart
  /// The crop frame sits exactly on the picture, letterboxed like the video.
  Widget _cropLayer(StudioController studio) => LayoutBuilder(builder: (context, constraints) {
        final picture = studio.pictureSize;
        final rect = picture == null
            ? null
            : CropMath.videoRectInViewport(picture, Rotation.none, constraints.maxWidth, constraints.maxHeight);
        if (rect == null) return const SizedBox.shrink();
        final out = studio.outputSize;
        return Stack(
          children: [
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: CropOverlay(
                crop: studio.crop,
                lockRatio: studio.cropLockRatio,
                label: out == null ? '' : '${out.width} × ${out.height} · ${reducedRatio(out.width, out.height)}',
                onChanged: studio.setCrop,
              ),
            ),
          ],
        );
      });
```

- [ ] **Step 5: Câbler `lib/main.dart`**

Ajouter les imports :

```dart
import 'core/system/export_service.dart';
import 'features/studio/studio_controller.dart';
```

Après la création de `player` (`final player = PlayerController(...);`), ajouter :

```dart
  final studio = StudioController(
    player: player,
    exporter: ExportService(ffmpegPath: locator.locate('ffmpeg'), expectedFolder: locator.executableDir),
  );
```

Remplacer :

```dart
  host.onCloseRequested = () async {
    await player.saveResume();
```

par :

```dart
  host.onCloseRequested = () async {
    await studio.shutdown();
    await player.saveResume();
```

Dans l'appel `AppShell(`, après `toasts: toasts,`, ajouter `studio: studio,`.

- [ ] **Step 6: Lancer les tests et le build**

Run: `flutter test` puis `flutter analyze` puis `flutter build windows --debug`
Expected: `All tests passed!` (les tests d'`AppShell` du plan 2, sans `studio`, restent verts), `No issues found!`, `√ Built build\windows\x64\runner\Debug\uhf_media.exe`

- [ ] **Step 7: Commit**

```bash
git add lib/features/player/controls_overlay.dart lib/features/shell/app_shell.dart lib/main.dart test/features/shell/app_shell_studio_test.dart
git commit -m "feat(shell): dock the studio under the video with shortcuts and export messages"
```

---

### Task 15: Reconnaissance musicale (extraction + Shazam)

**Files:**
- Create: `lib/core/system/music_recognizer.dart`
- Test: `test/core/system/music_recognizer_test.dart`

**Interfaces:**
- Consumes: `isSilent`, `SignatureGenerator.fromPcm16kMono`, `ShazamClient`, `RecognitionResult`, `ShazamException` (plan 1), `formatSeconds3`.
- Produces:
  - `typedef BytesRunner = Future<(int, Uint8List)> Function(String executable, List<String> arguments);` (code de sortie, stdout brut).
  - `Int16List pcm16FromBytes(Uint8List bytes)` (petit-boutiste, octet impair final ignoré).
  - `sealed class MusicOutcome` ; `MusicFound(RecognitionResult result)`, `MusicNotFound()`, `MusicFailed(String reason)`.
  - `abstract interface class MusicIdentifier { bool get available; String get expectedFolder; Future<MusicOutcome> identify(String path, Duration at); }`
  - `class MusicRecognizer implements MusicIdentifier { MusicRecognizer({required String? ffmpegPath, required String expectedFolder, required ShazamClient client, BytesRunner? run}); static List<String> extractArgs(String path, Duration at); }` — silence : `MusicNotFound` sans requête ; la signature est calculée dans un isolat (`Isolate.run`) pour ne pas figer l'interface.

- [ ] **Step 1: Écrire le test**

`test/core/system/music_recognizer_test.dart` :

```dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/system/music_recognizer.dart';

Uint8List _tone(double amplitude, {int seconds = 10}) {
  final data = ByteData(16000 * seconds * 2);
  for (var i = 0; i < 16000 * seconds; i++) {
    final v = (amplitude * 32767 * math.sin(2 * math.pi * 440 * i / 16000)).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  late int requests;
  setUp(() => requests = 0);

  ShazamClient client(http.Response response) => ShazamClient(
        client: MockClient((_) async {
          requests++;
          return response;
        }),
        random: math.Random(1),
      );

  final found = http.Response(
    jsonEncode({'track': {'title': 'Gülümse', 'subtitle': 'Sezen Aksu'}}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('extracts 10 s of 16 kHz mono PCM at the position, then asks Shazam', () async {
    late List<String> seen;
    final recognizer = MusicRecognizer(
      ffmpegPath: r'C:\App\ffmpeg.exe',
      expectedFolder: r'C:\App',
      client: client(found),
      run: (exe, args) async {
        expect(exe, r'C:\App\ffmpeg.exe');
        seen = args;
        return (0, _tone(0.5));
      },
    );
    final outcome = await recognizer.identify(r'C:\m\a b.mp3', const Duration(seconds: 75, milliseconds: 500));
    expect(seen, [
      '-v', 'error', '-ss', '75.500', '-t', '10', '-i', r'C:\m\a b.mp3',
      '-ac', '1', '-ar', '16000', '-f', 's16le', '-',
    ]);
    expect(outcome, isA<MusicFound>());
    final result = (outcome as MusicFound).result;
    expect(result.title, 'Gülümse');
    expect(result.artist, 'Sezen Aksu');
    expect(requests, 1);
  });

  test('silence is not sent', () async {
    final recognizer = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(found),
      run: (_, _) async => (0, Uint8List(320000)),
    );
    expect(await recognizer.identify('x.mp3', Duration.zero), isA<MusicNotFound>());
    expect(requests, 0);
  });

  test('no track in the answer is not found', () async {
    final recognizer = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(http.Response('{"matches": []}', 200)),
      run: (_, _) async => (0, _tone(0.5)),
    );
    expect(await recognizer.identify('x.mp3', Duration.zero), isA<MusicNotFound>());
  });

  test('ffmpeg errors and HTTP errors are failures', () async {
    final noAudio = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(found),
      run: (_, _) async => (1, Uint8List(0)),
    );
    expect(await noAudio.identify('x.mp3', Duration.zero), isA<MusicFailed>());
    final offline = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(http.Response('down', 503)),
      run: (_, _) async => (0, _tone(0.5)),
    );
    expect(await offline.identify('x.mp3', Duration.zero), isA<MusicFailed>());
  });

  test('without ffmpeg the recognizer is unavailable', () async {
    final r = MusicRecognizer(ffmpegPath: null, expectedFolder: r'C:\App', client: client(found));
    expect(r.available, isFalse);
    expect(await r.identify('x.mp3', Duration.zero), isA<MusicFailed>());
  });

  test('PCM bytes are read little-endian, a trailing odd byte is dropped', () {
    final samples = pcm16FromBytes(Uint8List.fromList([0x01, 0x00, 0xff, 0x7f, 0x00, 0x80, 0x07]));
    expect(samples, [1, 32767, -32768]);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/system/music_recognizer_test.dart`
Expected: FAIL, `music_recognizer.dart` introuvable.

- [ ] **Step 3: Écrire `lib/core/system/music_recognizer.dart`**

```dart
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../shazam/audio_level.dart';
import '../shazam/shazam_client.dart';
import '../shazam/signature_format.dart';
import '../shazam/signature_generator.dart';
import '../util/time_format.dart';

/// Top-level so the isolate closure captures only the samples.
Future<DecodedSignature> _signatureOf(Int16List samples) =>
    Isolate.run(() => SignatureGenerator.fromPcm16kMono(samples));

typedef BytesRunner = Future<(int, Uint8List)> Function(String executable, List<String> arguments);

Future<(int, Uint8List)> _runForBytes(String executable, List<String> arguments) async {
  final r = await Process.run(executable, arguments, stdoutEncoding: null, stderrEncoding: null);
  final out = r.stdout;
  return (r.exitCode, out is Uint8List ? out : Uint8List.fromList(out as List<int>));
}

/// Signed 16-bit little-endian samples, as `ffmpeg -f s16le` writes them.
Int16List pcm16FromBytes(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = Int16List(bytes.length ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = data.getInt16(i * 2, Endian.little);
  }
  return samples;
}

sealed class MusicOutcome {
  const MusicOutcome();
}

class MusicFound extends MusicOutcome {
  const MusicFound(this.result);
  final RecognitionResult result;
}

class MusicNotFound extends MusicOutcome {
  const MusicNotFound();
}

class MusicFailed extends MusicOutcome {
  const MusicFailed(this.reason);
  final String reason;
}

abstract interface class MusicIdentifier {
  bool get available;
  String get expectedFolder;
  Future<MusicOutcome> identify(String path, Duration at);
}

class MusicRecognizer implements MusicIdentifier {
  MusicRecognizer({
    required String? ffmpegPath,
    required this.expectedFolder,
    required ShazamClient client,
    BytesRunner? run,
  })  : _ffmpeg = ffmpegPath,
        _client = client,
        _run = run ?? _runForBytes;

  final String? _ffmpeg;
  final ShazamClient _client;
  final BytesRunner _run;

  @override
  final String expectedFolder;

  @override
  bool get available => _ffmpeg != null;

  /// 10 s from [at], already 16 kHz mono 16-bit: no resampling in Dart.
  static List<String> extractArgs(String path, Duration at) => [
        '-v', 'error', '-ss', formatSeconds3(at), '-t', '10', '-i', path,
        '-ac', '1', '-ar', '16000', '-f', 's16le', '-',
      ];

  @override
  Future<MusicOutcome> identify(String path, Duration at) async {
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return const MusicFailed('ffmpeg.exe not found');
    (int, Uint8List) extracted;
    try {
      extracted = await _run(ffmpeg, extractArgs(path, at));
    } on ProcessException catch (e) {
      return MusicFailed(e.message);
    }
    final (code, bytes) = extracted;
    if (code != 0 || bytes.length < 2) return const MusicFailed('no audio could be read');
    final samples = pcm16FromBytes(bytes);
    if (isSilent(samples)) return const MusicNotFound();
    try {
      final signature = await _signatureOf(samples);
      final result = await _client.recognize(signature);
      return result == null ? const MusicNotFound() : MusicFound(result);
    } on ShazamException catch (e) {
      return MusicFailed(e.message);
    }
  }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/core/system/music_recognizer.dart test/core/system/music_recognizer_test.dart
git commit -m "feat(music): extract 10 s of audio with ffmpeg and recognize it with Shazam"
```

---

### Task 16: Contrôleur d'identification musicale

**Files:**
- Create: `lib/features/music_id/music_id_controller.dart`, `test/support/fake_music_identifier.dart`
- Test: `test/features/music_id/music_id_controller_test.dart`

**Interfaces:**
- Consumes: `MusicIdentifier`, `MusicOutcome` (tâche 15), `renameTarget` (plan 1), `PlayerController.renameOpenFile` (tâche 8), `SettingsController` (`autoRename`).
- Produces:
  - `sealed class MusicEvent` ; `MusicListeningEvent()`, `MusicNotFoundEvent()`, `MusicFailedEvent()`, `MusicRenamedEvent(String name)`, `MusicRenameFailedEvent()`, `MusicUnavailableEvent(String folder)`.
  - `class MusicCard { const MusicCard({required String path, required String artist, required String title, String? renamedFrom}); String get text; }` — `path` : fichier auquel le résultat appartient (son nom actuel).
  - `class MusicIdController extends ChangeNotifier { MusicIdController({required PlayerController player, required MusicIdentifier identifier, required SettingsController settings, bool Function(String path)? exists}); bool get busy; MusicCard? get card; Stream<MusicEvent> get events; Future<void> identify(); Future<void> renameToResult(); Future<void> undoRename(); void dismiss(); }` — renommage automatique si le réglage est actif ; un résultat ne renomme jamais un autre fichier que celui identifié.
  - Test : `class FakeMusicIdentifier implements MusicIdentifier` avec `calls`, `pending`, `isAvailable`.

- [ ] **Step 1: Écrire la doublure `test/support/fake_music_identifier.dart`**

```dart
import 'dart:async';

import 'package:uhf_media/core/system/music_recognizer.dart';

class FakeMusicIdentifier implements MusicIdentifier {
  bool isAvailable = true;
  final calls = <String>[];
  Completer<MusicOutcome>? pending;

  @override
  bool get available => isAvailable;

  @override
  String get expectedFolder => r'C:\App';

  @override
  Future<MusicOutcome> identify(String path, Duration at) {
    calls.add('$path@${at.inSeconds}');
    final completer = Completer<MusicOutcome>();
    pending = completer;
    return completer.future;
  }
}
```

- [ ] **Step 2: Écrire le test**

`test/features/music_id/music_id_controller_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/system/music_recognizer.dart';
import 'package:uhf_media/features/music_id/music_id_controller.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_music_identifier.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _found = MusicFound(RecognitionResult(title: 'Gülümse', artist: 'Sezen Aksu'));

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeMusicIdentifier identifier;
  late List<String> renames;
  late List<MusicEvent> events;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_music_');
    engine = FakeMediaEngine();
    identifier = FakeMusicIdentifier();
    renames = [];
    events = [];
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      renameFile: (from, to) async => renames.add('$from>$to'),
    );
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  MusicIdController make({bool autoRename = false}) {
    final settings = SettingsController(SettingsStore(dir), AppSettings.defaults().copyWith(autoRename: autoRename));
    final c = MusicIdController(player: player, identifier: identifier, settings: settings, exists: (_) => false);
    c.events.listen(events.add);
    return c;
  }

  Future<void> openAt(String path, Duration position) async {
    await player.open(path);
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(position);
    await settle();
  }

  test('identify listens at the position and shows the card', () async {
    final c = make();
    await openAt(r'C:\m\track01.mp3', const Duration(seconds: 75));
    final done = c.identify();
    await settle();
    expect(c.busy, isTrue);
    expect(identifier.calls, [r'C:\m\track01.mp3@75']);
    expect(events.single, isA<MusicListeningEvent>());
    identifier.pending!.complete(_found);
    await done;
    expect(c.busy, isFalse);
    expect(c.card!.text, 'Sezen Aksu - Gülümse');
    expect(renames, isEmpty);
  });

  test('a second identify while listening is ignored', () async {
    final c = make();
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    final done = c.identify();
    await settle();
    await c.identify();
    expect(identifier.calls, hasLength(1));
    identifier.pending!.complete(const MusicNotFound());
    await done;
  });

  test('automatic rename, then undo', () async {
    final c = make(autoRename: true);
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    final done = c.identify();
    await settle();
    identifier.pending!.complete(_found);
    await done;
    expect(renames, [r'C:\m\track01.mp3>C:\m\Sezen Aksu - Gülümse.mp3']);
    expect(player.fileName, 'Sezen Aksu - Gülümse.mp3');
    expect(c.card!.renamedFrom, r'C:\m\track01.mp3');
    expect(events.last, isA<MusicRenamedEvent>().having((e) => e.name, 'name', 'Sezen Aksu - Gülümse.mp3'));

    await c.undoRename();
    expect(renames.last, r'C:\m\Sezen Aksu - Gülümse.mp3>C:\m\track01.mp3');
    expect(player.fileName, 'track01.mp3');
    expect(c.card!.renamedFrom, isNull);
  });

  test('not found and failures leave the file alone', () async {
    final c = make(autoRename: true);
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    var done = c.identify();
    await settle();
    identifier.pending!.complete(const MusicNotFound());
    await done;
    expect(events.last, isA<MusicNotFoundEvent>());
    done = c.identify();
    await settle();
    identifier.pending!.complete(const MusicFailed('offline'));
    await done;
    expect(events.last, isA<MusicFailedEvent>());
    expect(c.card, isNull);
    expect(renames, isEmpty);
  });

  test('a result for a file closed in the meantime never renames the new one (review focus 5)', () async {
    final c = make(autoRename: true);
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    final done = c.identify();
    await settle();
    await player.open(r'C:\m\other.mp3');
    identifier.pending!.complete(_found);
    await done;
    expect(c.card!.path, r'C:\m\track01.mp3');
    await c.renameToResult();
    expect(renames, isEmpty);
    expect(player.fileName, 'other.mp3');
  });

  test('without ffmpeg the event names the expected folder', () async {
    identifier.isAvailable = false;
    final c = make();
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    await c.identify();
    expect(events.single, isA<MusicUnavailableEvent>().having((e) => e.folder, 'folder', r'C:\App'));
    expect(identifier.calls, isEmpty);
  });
}
```

- [ ] **Step 3: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/music_id/music_id_controller_test.dart`
Expected: FAIL, `music_id_controller.dart` introuvable.

- [ ] **Step 4: Écrire `lib/features/music_id/music_id_controller.dart`**

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/files/safe_rename.dart';
import '../../core/system/music_recognizer.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';

sealed class MusicEvent {
  const MusicEvent();
}

class MusicListeningEvent extends MusicEvent {
  const MusicListeningEvent();
}

class MusicNotFoundEvent extends MusicEvent {
  const MusicNotFoundEvent();
}

class MusicFailedEvent extends MusicEvent {
  const MusicFailedEvent();
}

class MusicRenamedEvent extends MusicEvent {
  const MusicRenamedEvent(this.name);
  final String name;
}

class MusicRenameFailedEvent extends MusicEvent {
  const MusicRenameFailedEvent();
}

class MusicUnavailableEvent extends MusicEvent {
  const MusicUnavailableEvent(this.folder);
  final String folder;
}

class MusicCard {
  const MusicCard({required this.path, required this.artist, required this.title, this.renamedFrom});

  /// The identified file, under its current name.
  final String path;
  final String artist;
  final String title;

  /// Previous name after a rename, for Undo.
  final String? renamedFrom;

  String get text => '$artist - $title';
}

class MusicIdController extends ChangeNotifier {
  MusicIdController({
    required PlayerController player,
    required MusicIdentifier identifier,
    required SettingsController settings,
    bool Function(String path)? exists,
  })  : _player = player,
        _identifier = identifier,
        _settings = settings,
        _exists = exists ?? ((path) => File(path).existsSync());

  final PlayerController _player;
  final MusicIdentifier _identifier;
  final SettingsController _settings;
  final bool Function(String path) _exists;
  final _events = StreamController<MusicEvent>.broadcast();
  bool _busy = false;
  MusicCard? _card;

  bool get busy => _busy;
  MusicCard? get card => _card;
  Stream<MusicEvent> get events => _events.stream;

  Future<void> identify() async {
    final path = _player.path;
    if (_busy || path == null) return;
    if (!_identifier.available) {
      _events.add(MusicUnavailableEvent(_identifier.expectedFolder));
      return;
    }
    _busy = true;
    _card = null;
    notifyListeners();
    _events.add(const MusicListeningEvent());
    final MusicOutcome outcome;
    try {
      outcome = await _identifier.identify(path, _player.position);
    } finally {
      _busy = false;
    }
    switch (outcome) {
      case MusicFound(:final result):
        _card = MusicCard(path: path, artist: result.artist, title: result.title);
        notifyListeners();
        if (_settings.value.autoRename) await renameToResult();
      case MusicNotFound():
        _events.add(const MusicNotFoundEvent());
        notifyListeners();
      case MusicFailed():
        _events.add(const MusicFailedEvent());
        notifyListeners();
    }
  }

  /// Renames the identified file to "Artist - Title.ext" while it plays.
  Future<void> renameToResult() async {
    final card = _card;
    if (card == null || card.renamedFrom != null || _player.path != card.path) return;
    final target = renameTarget(card.path, card.artist, card.title, exists: _exists);
    if (target == null) return;
    if (await _player.renameOpenFile(target)) {
      _card = MusicCard(path: target, artist: card.artist, title: card.title, renamedFrom: card.path);
      _events.add(MusicRenamedEvent(p.windows.basename(target)));
    } else {
      _events.add(const MusicRenameFailedEvent());
    }
    notifyListeners();
  }

  Future<void> undoRename() async {
    final card = _card;
    final from = card?.renamedFrom;
    if (card == null || from == null || _player.path != card.path) return;
    if (await _player.renameOpenFile(from)) {
      _card = MusicCard(path: from, artist: card.artist, title: card.title);
    } else {
      _events.add(const MusicRenameFailedEvent());
    }
    notifyListeners();
  }

  void dismiss() {
    _card = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_events.close());
    super.dispose();
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/music_id/music_id_controller.dart test/support/fake_music_identifier.dart test/features/music_id/music_id_controller_test.dart
git commit -m "feat(music): add identification controller with auto rename and undo"
```

---

### Task 17: Carte de musique, menu et raccourci

**Files:**
- Create: `lib/features/music_id/music_result_card.dart`
- Modify: `lib/features/player/player_menus.dart`, `lib/features/player/controls_overlay.dart`, `lib/features/shell/app_shell.dart`, `lib/main.dart`
- Test: `test/features/shell/app_shell_music_test.dart`

**Interfaces:**
- Consumes: `MusicIdController`, `MusicCard`, `MusicEvent` et ses cas (tâche 16), `MusicRecognizer`, `ShazamClient`, `UhfChip`, `UhfIconButton`, `FakeMusicIdentifier`.
- Produces:
  - `class MusicResultCard extends StatelessWidget { const MusicResultCard({super.key, required MusicIdController music, required ValueChanged<String> onCopy}); }` — sur `raised`, filet `line`, rayon 3 px : artiste (11 px, `textMuted`), titre (13 px, 500), *Renommer le fichier* ou *Annuler* après renommage, *Copier*, fermer.
  - `moreMenuEntries(..., MusicIdController? music)` : *Identifier la musique* (`Ctrl+I`) après la capture, *Renommer automatiquement après identification* (case) après les réglages des sous-titres.
  - `ControlsOverlay` et `AppShell` : paramètre optionnel `MusicIdController? music` ; `AppShell` : `Ctrl+I`, carte en bas à gauche au-dessus des messages, événements traduits en messages.

- [ ] **Step 1: Écrire le test**

`test/features/shell/app_shell_music_test.dart` :

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/system/music_recognizer.dart';
import 'package:uhf_media/features/music_id/music_id_controller.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/app_shell.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/ui/toast.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_music_identifier.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeMusicIdentifier identifier;
  late MusicIdController music;
  late ToastController toasts;
  late SettingsController settings;
  late List<String> renames;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_shell_music_');
    engine = FakeMediaEngine();
    renames = [];
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      renameFile: (from, to) async => renames.add('$from>$to'),
    );
    identifier = FakeMusicIdentifier();
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    music = MusicIdController(player: player, identifier: identifier, settings: settings, exists: (_) => false);
    toasts = ToastController();
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    toasts.dispose();
  }

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(AppShell(
      player: player,
      shell: ShellController(FakeWindowHost(), settings),
      settings: settings,
      toasts: toasts,
      music: music,
      videoBuilder: (_) => const ColoredBox(color: Colors.black),
      pickFile: (_) async => null,
      revealFile: (_) {},
    )));
    await player.open(r'C:\m\track01.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    await tester.pump();
  }

  Future<void> identify(WidgetTester tester, MusicOutcome outcome) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('Listening…'), findsOneWidget);
    identifier.pending!.complete(outcome);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('Ctrl+I shows the card; Copy puts "Artist - Title" on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpShell(tester);
    await identify(tester, const MusicFound(RecognitionResult(title: 'Gülümse', artist: 'Sezen Aksu')));
    expect(find.text('Sezen Aksu'), findsOneWidget);
    expect(find.text('Gülümse'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, 'Sezen Aksu - Gülümse');
    await finish(tester);
  });

  testWidgets('Rename the file renames it and offers Undo', (tester) async {
    await pumpShell(tester);
    await identify(tester, const MusicFound(RecognitionResult(title: 'Gülümse', artist: 'Sezen Aksu')));
    await tester.tap(find.text('Rename the file'));
    await tester.pump();
    await tester.pump();
    expect(renames, [r'C:\m\track01.mp3>C:\m\Sezen Aksu - Gülümse.mp3']);
    expect(find.text('Renamed to Sezen Aksu - Gülümse.mp3'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('nothing recognized shows a message and no card', (tester) async {
    await pumpShell(tester);
    await identify(tester, const MusicNotFound());
    expect(find.text('No song recognized'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    await finish(tester);
  });

  testWidgets('the more menu identifies music and toggles automatic rename', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename automatically after identification'));
    await tester.pumpAndSettle();
    expect(settings.value.autoRename, isTrue);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Identify music'));
    await tester.pumpAndSettle();
    expect(identifier.calls, hasLength(1));
    identifier.pending!.complete(const MusicNotFound());
    await finish(tester);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/shell/app_shell_music_test.dart`
Expected: FAIL à la compilation : `AppShell` n'a pas de paramètre `music`.

- [ ] **Step 3: Écrire `lib/features/music_id/music_result_card.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_chip.dart';
import '../../ui/uhf_icon_button.dart';
import 'music_id_controller.dart';

class MusicResultCard extends StatelessWidget {
  const MusicResultCard({super.key, required this.music, required this.onCopy});

  final MusicIdController music;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: music,
      builder: (context, _) {
        final card = music.card;
        if (card == null) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        final renamed = card.renamedFrom != null;
        return Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: UhfColors.raised,
            border: Border.all(color: UhfColors.line),
            borderRadius: BorderRadius.circular(UhfRadii.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UhfText.sans(size: 11, color: UhfColors.textMuted),
                        ),
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: UhfText.sans(weight: 500),
                        ),
                      ],
                    ),
                  ),
                  UhfIconButton(
                    icon: Symbols.close_sharp,
                    tooltip: l.tooltipClose,
                    size: 24,
                    iconSize: 16,
                    onPressed: music.dismiss,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  UhfChip(
                    label: renamed ? l.actionUndo : l.actionRenameFile,
                    onPressed: renamed ? music.undoRename : music.renameToResult,
                  ),
                  const SizedBox(width: 6),
                  UhfChip(label: l.actionCopy, onPressed: () => onCopy(card.text)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Ajouter les entrées de menu dans `lib/features/player/player_menus.dart`**

Ajouter l'import :

```dart
import '../music_id/music_id_controller.dart';
```

Dans la signature de `moreMenuEntries`, après `required VoidCallback onSubtitleSettings,`, ajouter :

```dart
  MusicIdController? music,
```

Dans la liste renvoyée, après l'entrée `UhfMenuEntry(label: l.menuScreenshot, shortcut: 'S', onSelected: player.screenshot),`, ajouter :

```dart
    if (music != null) UhfMenuEntry(label: l.menuIdentifyMusic, shortcut: 'Ctrl+I', onSelected: music.identify),
```

et, après l'entrée `UhfMenuEntry(label: l.menuSubtitleSettings, onSelected: onSubtitleSettings),`, ajouter :

```dart
    if (music != null)
      UhfMenuEntry(
        label: l.menuAutoRename,
        checked: settings.value.autoRename,
        onSelected: () => settings.update((s) => s.copyWith(autoRename: !s.autoRename)),
      ),
```

- [ ] **Step 5: Transmettre `music` dans `lib/features/player/controls_overlay.dart`**

Ajouter l'import :

```dart
import '../music_id/music_id_controller.dart';
```

Dans le constructeur, après `this.studio,`, ajouter `this.music,` et, après le champ `final StudioController? studio;`, ajouter :

```dart
  final MusicIdController? music;
```

Dans l'appel `moreMenuEntries(`, après `onSubtitleSettings: () => showSubtitleSettings(context, player),`, ajouter :

```dart
                          music: music,
```

- [ ] **Step 6: Intégrer dans `lib/features/shell/app_shell.dart`**

Ajouter les imports :

```dart
import '../music_id/music_id_controller.dart';
import '../music_id/music_result_card.dart';
```

Dans le constructeur, après `this.studio,`, ajouter `this.music,` et, après le champ `final StudioController? studio;`, ajouter :

```dart
  final MusicIdController? music;
```

Dans `_AppShellState`, après `StreamSubscription<StudioEvent>? _studioEvents;`, ajouter :

```dart
  StreamSubscription<MusicEvent>? _musicEvents;
```

Dans `initState`, après `_studioEvents = _studio?.events.listen(_onStudioEvent);`, ajouter :

```dart
    _musicEvents = widget.music?.events.listen(_onMusicEvent);
```

Dans `dispose`, après `unawaited(_studioEvents?.cancel());`, ajouter :

```dart
    unawaited(_musicEvents?.cancel());
```

Après la méthode `_onStudioEvent`, ajouter :

```dart
  void _onMusicEvent(MusicEvent event) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    widget.toasts.show(switch (event) {
      MusicListeningEvent() => l.toastListening,
      MusicNotFoundEvent() => l.toastMusicNotFound,
      MusicFailedEvent() => l.toastMusicFailed,
      MusicRenamedEvent(:final name) => l.toastRenamed(name),
      MusicRenameFailedEvent() => l.toastRenameFailed,
      MusicUnavailableEvent(:final folder) => l.toastFfmpegMissing(folder),
    });
  }
```

Dans `_bindings`, après la ligne de `Ctrl+E`, ajouter :

```dart
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () => widget.music?.identify(),
```

Dans les deux appels `ControlsOverlay(` (sous la vidéo dans le Studio, et superposé), après `studio: studio,`, ajouter :

```dart
                          music: widget.music,
```

Dans la `Stack` de `_stage`, juste avant `ToastHost(controller: widget.toasts),`, ajouter :

```dart
          if (widget.music != null)
            Positioned(
              left: 14,
              bottom: 140,
              child: MusicResultCard(
                music: widget.music!,
                onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
              ),
            ),
```

- [ ] **Step 7: Câbler `lib/main.dart`**

Ajouter les imports :

```dart
import 'core/shazam/shazam_client.dart';
import 'core/system/music_recognizer.dart';
import 'features/music_id/music_id_controller.dart';
```

Après la création de `studio`, ajouter :

```dart
  final music = MusicIdController(
    player: player,
    identifier: MusicRecognizer(
      ffmpegPath: locator.locate('ffmpeg'),
      expectedFolder: locator.executableDir,
      client: ShazamClient(),
    ),
    settings: settings,
  );
```

Dans l'appel `AppShell(`, après `studio: studio,`, ajouter `music: music,`.

- [ ] **Step 8: Lancer les tests et le build**

Run: `flutter test` puis `flutter analyze` puis `flutter build windows --debug`
Expected: `All tests passed!` (les tests de menus du plan 2, qui n'ont pas de `music`, restent verts), `No issues found!`, `√ Built build\windows\x64\runner\Debug\uhf_media.exe`

- [ ] **Step 9: Commit**

```bash
git add lib/features/music_id/music_result_card.dart lib/features/player/player_menus.dart lib/features/player/controls_overlay.dart lib/features/shell/app_shell.dart lib/main.dart test/features/shell/app_shell_music_test.dart
git commit -m "feat(music): add result card, menu entries and Ctrl+I"
```

---

### Task 18: Recette manuelle Studio et musique

**Files:**
- Modify: `tool/make_sample_media.ps1`

**Interfaces:**
- Consumes: l'application complète.
- Produces: trois fichiers d'essai de plus dans `%TEMP%\uhf_samples\` et un relevé de recette dans le ledger.

- [ ] **Step 1: Compléter `tool/make_sample_media.ps1`**

Avant la dernière ligne (`Get-ChildItem $out | Select-Object Name, Length`), ajouter :

```powershell
# 20 s vertical phone video (1080x1920, 30 fps, AAC).
ffmpeg -y -v error -f lavfi -i "testsrc2=size=1080x1920:rate=30:duration=20" `
  -f lavfi -i "sine=frequency=660:duration=20" `
  -c:v libx264 -preset veryfast -c:a aac (Join-Path $out 'phone_vertical.mp4')

# 20 s HEVC 10-bit (never encoded on the GPU).
ffmpeg -y -v error -f lavfi -i "testsrc2=size=1920x1080:rate=25:duration=20" `
  -c:v libx265 -pix_fmt yuv420p10le -preset ultrafast (Join-Path $out 'hevc_10bit.mkv')

# 20 s Blu-ray style m2ts with LPCM audio (re-encoded to FLAC in mkv).
ffmpeg -y -v error -f lavfi -i "testsrc2=size=1920x1080:rate=25:duration=20" `
  -f lavfi -i "sine=frequency=440:duration=20" `
  -c:v libx264 -preset veryfast -c:a pcm_bluray -ac 2 (Join-Path $out 'bluray_lpcm.m2ts')
```

- [ ] **Step 2: Générer les fichiers**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tool/make_sample_media.ps1` (avec `ffmpeg.exe` dans le `PATH`)
Expected: `phone_vertical.mp4`, `hevc_10bit.mkv`, `bluray_lpcm.m2ts` listés en plus des fichiers du plan 2, tailles non nulles.

- [ ] **Step 3: Recette (lancer l'exe release depuis l'Explorateur, `ffmpeg.exe` et `ffprobe.exe` copiés à côté de `uhf_media.exe`)**

Noter OK/KO pour chaque ligne dans le ledger :

1. `E` et le bouton Studio : la vidéo se réduit, les contrôles de lecture passent sous la vidéo, puis le panneau ; rien ne recouvre l'image ; `E` referme.
2. Rotation (`R` et puces) : aperçu immédiat, dimensions de sortie mises à jour (`1920 × 1080 · 16:9` → `1080 × 1920 · 9:16`).
3. Cadre (`C`, menu) : cadre exactement sur l'image (bords alignés, y compris après rotation et sur `phone_vertical.mp4`), 8 poignées et déplacement, lignes des tiers pendant le glissement, étiquette au-dessus ; ratios 16:9, 9:16, 1:1, 4:3 conservés par les poignées.
4. Découpe (`I`, `O`, puce) : plage de 60 s depuis la position, poignées, déplacement de la plage, clic hors plage, ±1 s ; la vidéo se met en pause et suit la poignée.
5. Export rotation + cadre + découpe de `multi_track.mkv` (piste audio 2 sélectionnée) : progression, temps restant, fichier `multi_track_crop_rot90_trim.mkv` lu correctement, bonne piste audio, durée de la découpe, image dans le bon sens.
6. *Annuler* pendant un export : message « Export annulé », aucun fichier partiel.
7. Deuxième export identique : nom ` (1)`.
8. `interlaced.ts` + cadre sans rotation : sortie entrelacée (ffprobe : `field_order` `tt`) ; avec rotation : sortie progressive à double fréquence.
9. `hevc_10bit.mkv` + rotation : export CPU (aucun essai GPU), sortie lue en 8 bits.
10. `bluray_lpcm.m2ts` + rotation : sortie `.mkv` avec audio FLAC lisible.
11. Sur une machine avec NVENC : export GPU ; en simulant un échec (pilote absent), message « nouvel essai sur le processeur » puis succès.
12. Export sans ffmpeg (renommer `ffmpeg.exe`) : message avec le dossier attendu ; la lecture continue de fonctionner.
13. Export sans modification : « Choisis d'abord une rotation, un cadre ou une découpe ».
14. Ouvrir un autre fichier pendant un export : l'export se termine, message *Afficher* ouvre l'Explorateur sur le bon fichier.
15. Musique (`Ctrl+I`, menu ⋯) sur un vrai morceau : « Écoute en cours… », carte artiste / titre, *Copier* dans le presse-papiers, *Renommer le fichier* pendant la lecture (le fichier est renommé, la lecture reprend à la même position, la reprise suit le nouveau nom), *Annuler* rétablit l'ancien nom.
16. Renommage automatique (menu ⋯) : renommage dès la reconnaissance, carte avec *Annuler*.
17. Silence (début de `multi_track.mkv` coupé, ou fichier muet) : « Aucun morceau reconnu », aucune requête réseau ; réseau coupé : message d'échec, fichier intact.
18. Fermer l'application pendant un export : fermeture en moins de 3 s, aucun fichier partiel, aucun ffmpeg restant dans le Gestionnaire des tâches.

- [ ] **Step 4: Corriger chaque point KO**

Pour chaque KO : écrire d'abord un test qui reproduit le défaut quand c'est possible, sinon décrire la reproduction dans le ledger ; corriger ; relancer `flutter test` ; refaire le point. Un KO non corrigé devient une ligne `Ruling:` avec son coût.

- [ ] **Step 5: Commit**

```bash
git add tool/make_sample_media.ps1
git commit -m "chore: add vertical, 10-bit and LPCM samples for studio checks"
```

---

## Plan suivant

- **Plan 4 — Distribution** : `tool/fetch_ffmpeg.ps1` (BtbN figé, SHA-256), copie CMake de `third_party/ffmpeg/` dans le bundle, métadonnées et icône de l'exe, installeur Inno Setup (installation par utilisateur, associations `OpenWithProgids`), README définitif, `THIRD_PARTY_NOTICES.md`, journal tournant dans `%APPDATA%\UHF Media\logs\` (spec §9).

