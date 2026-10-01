# UHF Media — Plan 1 : fondations et logique pure

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Créer le projet Flutter Windows à la racine du dépôt (Python déplacé dans `legacy/`), avec le design system « Signal », les traductions tr/fr/en, l'écran d'accueil UHF, et toute la logique pure testée : géométrie du recadrage, analyse ffprobe, commande d'export ffmpeg, nommage des fichiers, signature et client Shazam, réglages et reprise de lecture.

**Architecture:** Projet Flutter standard (`lib/app`, `lib/core`, `lib/features`, `lib/ui`, `lib/l10n`). Les modules de `lib/core/geometry`, `lib/core/ffmpeg`, `lib/core/files`, `lib/core/shazam` et `lib/core/util` n'importent ni Flutter ni `dart:io` (sauf `ShazamClient`, qui dépend de `package:http`) : ce sont des fonctions et des classes immuables testées directement. `lib/core/settings` utilise `dart:io` pour les fichiers JSON. À la fin du plan, `flutter run -d windows` affiche l'écran d'accueil UHF dans la langue du système.

**Tech Stack:** Flutter 3.41.4 stable, Dart 3.11.1, `fftea`, `http`, `path`, `intl`, `flutter_localizations` (gen-l10n), polices IBM Plex (OFL). Python `.venv` existant (`shazamio-core` 1.2.0) pour générer les références de signature.

**Spec:** `docs/superpowers/specs/2026-10-01-uhf-media-flutter-design.md`

## Global Constraints

- Windows 10/11 x64 uniquement ; `flutter create --platforms windows`.
- Flutter `>=3.41.0`, Dart SDK `^3.11.0` ; aucun paquet exigeant Dart 3.12 (donc pas de Riverpod).
- Nom de l'application : « UHF Media » ; nom du paquet Dart : `uhf_media` ; exe : `uhf_media.exe`.
- Couleurs exactes : `ink #0D0D0C`, `surface #161614`, `raised #1F1E1B`, `line #2B2A27`, `text #ECE9E2`, `textMuted #8C8981`, `signal #E8412C`, `signalYellow #F5D90A`.
- Polices : IBM Plex Sans (interface, graisses 400 et 500), IBM Plex Mono (valeurs mesurées) ; rayons 2–3 px ; ni ombre, ni dégradé, ni emoji.
- Langues : anglais (modèle et repli), français, turc.
- Modules purs (`lib/core/{geometry,ffmpeg,files,shazam,util}`) : aucun import de `package:flutter` ni de `dart:io`.
- Messages de commit : Conventional Commits, en anglais, **sans** ligne `Co-Authored-By` (voir `CLAUDE.md`).
- `video_studio_player.py` et l'ancien `README.md` sont déplacés dans `legacy/` et conservés, jamais supprimés.

## Review Focus

1. **Chemins avec espaces, accents ou caractères turcs** (`C:\Vidéos\şarkı test.mkv`) : chaque chemin doit rester un seul argument de la commande ffmpeg, sans guillemets ajoutés. Test dans la tâche 8.
2. **Liste de pistes sans `ff-index`** (piste externe, conteneur exotique) : l'export doit retomber sur `0:v:0` et `0:a:0?` au lieu d'échouer. Test dans la tâche 8.
3. **Audio trop court** (moins de 46 blocs de 128 échantillons, soit environ 0,37 s) : la signature doit être produite sans pic et sans plantage. Test dans la tâche 11.
4. **Dimensions source impaires et cadre collé aux bords** (1919×1079, n'importe quelle rotation) : le rectangle source doit rester dans l'image, avec des dimensions paires et positives. Test dans la tâche 6.
5. **Fichier de réglages absent, corrompu ou avec des types inattendus** : chargement des valeurs par défaut, fichier corrompu renommé en `.bak`. Test dans la tâche 13.

---

## File Structure

| Fichier | Responsabilité |
|---|---|
| `legacy/video_studio_player.py`, `legacy/README.md` | Ancienne application, conservée |
| `README.md` | Présentation courte du projet Flutter et commandes de build |
| `pubspec.yaml`, `l10n.yaml`, `analysis_options.yaml` | Configuration du projet |
| `assets/fonts/*` | IBM Plex Sans (variable), IBM Plex Mono 400/500, licences OFL |
| `lib/main.dart` | Point d'entrée : `runApp(const UhfApp())` |
| `lib/app/uhf_app.dart` | `MaterialApp` : thème, traductions, écran d'accueil |
| `lib/ui/tokens.dart` | Couleurs, rayons, durées, noms de polices |
| `lib/ui/typography.dart` | Styles de texte `UhfText` |
| `lib/ui/theme.dart` | `buildUhfTheme()` |
| `lib/l10n/app_{en,fr,tr}.arb` | Textes traduits |
| `lib/features/shell/idle_screen.dart` | Écran d'accueil UHF animé |
| `lib/core/util/time_format.dart` | `formatTimecode`, `reducedRatio` |
| `lib/core/geometry/geometry.dart` | `IntSize`, `IntRect`, `DRect`, `RatioRect` |
| `lib/core/geometry/rotation.dart` | `Rotation` |
| `lib/core/geometry/aspect_preset.dart` | `AspectPreset` |
| `lib/core/geometry/crop_math.dart` | `CropMath` |
| `lib/core/ffmpeg/probe_result.dart` | `ProbeResult.parse` (JSON ffprobe) |
| `lib/core/ffmpeg/export_plan.dart` | `ExportPlan`, `TrimRange`, `HwEncoder`, erreurs de validation |
| `lib/core/ffmpeg/export_command_builder.dart` | `ExportCommandBuilder.build`, `pickHwEncoder` |
| `lib/core/files/output_naming.dart` | `exportOutputPath`, `isMp4Family` |
| `lib/core/files/safe_rename.dart` | `sanitizeFileStem`, `renameTarget` |
| `lib/core/shazam/crc32.dart` | CRC-32 IEEE |
| `lib/core/shazam/signature_format.dart` | `DecodedSignature` (encodage / décodage binaire) |
| `lib/core/shazam/signature_generator.dart` | `SignatureGenerator.fromPcm16kMono` |
| `lib/core/shazam/audio_level.dart` | `isSilent` |
| `lib/core/shazam/shazam_client.dart` | `ShazamClient`, `RecognitionResult`, `ShazamException` |
| `lib/core/settings/json_file.dart` | Lecture tolérante et écriture atomique de JSON |
| `lib/core/settings/app_settings.dart` | `AppSettings` |
| `lib/core/settings/settings_store.dart` | `SettingsStore` |
| `lib/core/settings/resume_store.dart` | `ResumeStore` |
| `tool/gen_signature_fixtures.py` | Génère WAV + signatures de référence avec `shazamio-core` |
| `test/...` | Miroir de `lib/` ; `test/fixtures/shazam/*.wav|*.uri`, `test/support/wav.dart` |
| `.github/workflows/ci.yml` | `flutter analyze` + `flutter test` sur `windows-latest` |

---

### Task 1: Projet Flutter, legacy et application vide

**Files:**
- Move: `video_studio_player.py` → `legacy/video_studio_player.py`, `README.md` → `legacy/README.md`
- Create: projet Flutter à la racine (`flutter create`), `README.md`, `lib/main.dart`, `lib/app/uhf_app.dart`, `test/app/uhf_app_test.dart`
- Modify: `.gitignore`, `windows/runner/main.cpp`
- Delete: `test/widget_test.dart` (généré)
- Add to git: `CLAUDE.md` (déjà présent, non suivi)

**Interfaces:**
- Produces: `class UhfApp extends StatelessWidget { const UhfApp({super.key, this.home, this.locale}); final Widget? home; final Locale? locale; }`. `home` vaut `null` jusqu'à la tâche 4 (écran vide), puis `IdleScreen` par défaut.

- [ ] **Step 1: Déplacer le Python dans `legacy/`**

```powershell
New-Item -ItemType Directory -Force legacy | Out-Null
git mv video_studio_player.py legacy/video_studio_player.py
git mv README.md legacy/README.md
```

- [ ] **Step 2: Créer le projet Flutter à la racine**

```powershell
flutter create --org dev.uhfmedia --project-name uhf_media --platforms windows --empty .
```

Expected: « All done! ». Les fichiers existants (`.gitignore`, `CLAUDE.md`, `docs/`, `.venv/`) ne sont pas modifiés.

- [ ] **Step 3: Remplacer `.gitignore`**

`flutter create` ne touche pas à un `.gitignore` existant : ses entrées Flutter manquent donc. Remplacer tout le contenu de `.gitignore` par :

```gitignore
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache/
.pub/
build/
*.iml
.idea/
.vscode/
coverage/

# Python (legacy)
__pycache__/
*.pyc
.venv/

# PyInstaller (legacy)
dist/
*.spec

# External binaries (see README)
ffmpeg.exe
ffprobe.exe
libmpv-2.dll
third_party/ffmpeg/

# Installer output
installer/Output/
```

- [ ] **Step 4: Écrire le test de fumée de l'application**

Supprimer `test/widget_test.dart` s'il a été généré, puis créer `test/app/uhf_app_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';

void main() {
  testWidgets('UhfApp builds a MaterialApp titled UHF Media', (tester) async {
    await tester.pumpWidget(const UhfApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'UHF Media');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
```

- [ ] **Step 5: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/app/uhf_app_test.dart`
Expected: FAIL, « Target of URI doesn't exist: 'package:uhf_media/app/uhf_app.dart' ».

- [ ] **Step 6: Écrire `lib/app/uhf_app.dart` et `lib/main.dart`**

`lib/app/uhf_app.dart` :

```dart
import 'package:flutter/material.dart';

class UhfApp extends StatelessWidget {
  const UhfApp({super.key, this.home, this.locale});

  final Widget? home;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UHF Media',
      debugShowCheckedModeBanner: false,
      locale: locale,
      home: Scaffold(body: home ?? const SizedBox.expand()),
    );
  }
}
```

`lib/main.dart` (remplace le fichier généré) :

```dart
import 'package:flutter/material.dart';

import 'app/uhf_app.dart';

void main() {
  runApp(const UhfApp());
}
```

- [ ] **Step 7: Titre de la fenêtre native**

Dans `windows/runner/main.cpp`, remplacer `window.Create(L"uhf_media", origin, size)` par :

```cpp
  if (!window.Create(L"UHF Media", origin, size)) {
```

(Conserver le reste de la ligne et du bloc générés.)

- [ ] **Step 8: Écrire le nouveau `README.md`**

```markdown
# UHF Media

Windows video player with built-in editing tools (rotate, crop, trim, export) and song recognition. Flutter rewrite of the original PyQt5 app, which lives in [`legacy/`](legacy/).

Status: in development. Design: [`docs/superpowers/specs/2026-10-01-uhf-media-flutter-design.md`](docs/superpowers/specs/2026-10-01-uhf-media-flutter-design.md).

## Development

Requirements: Flutter 3.41 (stable), Visual Studio with the "Desktop development with C++" workload.

```bash
flutter pub get
flutter test
flutter run -d windows
```
```

- [ ] **Step 9: Lancer les tests et l'analyse**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 10: Vérifier le build Windows**

Run: `flutter build windows --debug`
Expected: `√ Built build\windows\x64\runner\Debug\uhf_media.exe`

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter app and move Python app to legacy/"
```

---

### Task 2: Design system « Signal » (jetons, typographie, thème, polices)

**Files:**
- Create: `assets/fonts/IBMPlexSans-Variable.ttf`, `assets/fonts/IBMPlexMono-Regular.ttf`, `assets/fonts/IBMPlexMono-Medium.ttf`, `assets/fonts/OFL-IBMPlexSans.txt`, `assets/fonts/OFL-IBMPlexMono.txt`
- Create: `lib/ui/tokens.dart`, `lib/ui/typography.dart`, `lib/ui/theme.dart`
- Modify: `pubspec.yaml` (section `flutter.fonts`), `lib/app/uhf_app.dart`
- Test: `test/ui/theme_test.dart`

**Interfaces:**
- Produces: `UhfColors.{ink,surface,raised,line,text,textMuted,signal,signalYellow}` (`Color`), `UhfRadii.{sm,md}` (`double`), `UhfDurations.{fast,base,controlsHide,toast,toastWithAction,idleBlink}` (`Duration`), `UhfFonts.{sans,mono}` (`String`), `UhfText.sans({double size, int weight, Color color})`, `UhfText.mono({...})`, `UhfText.{body,caption,label}`, `ThemeData buildUhfTheme()`.

- [ ] **Step 1: Télécharger les polices (Google Fonts, licence OFL)**

```powershell
New-Item -ItemType Directory -Force assets/fonts | Out-Null
$base = "https://raw.githubusercontent.com/google/fonts/main/ofl"
Invoke-WebRequest "$base/ibmplexsans/IBMPlexSans%5Bwdth,wght%5D.ttf" -OutFile assets/fonts/IBMPlexSans-Variable.ttf
Invoke-WebRequest "$base/ibmplexsans/OFL.txt" -OutFile assets/fonts/OFL-IBMPlexSans.txt
Invoke-WebRequest "$base/ibmplexmono/IBMPlexMono-Regular.ttf" -OutFile assets/fonts/IBMPlexMono-Regular.ttf
Invoke-WebRequest "$base/ibmplexmono/IBMPlexMono-Medium.ttf" -OutFile assets/fonts/IBMPlexMono-Medium.ttf
Invoke-WebRequest "$base/ibmplexmono/OFL.txt" -OutFile assets/fonts/OFL-IBMPlexMono.txt
Get-ChildItem assets/fonts | Select-Object Name, Length
```

Expected: cinq fichiers non vides (environ 537 Ko pour la variable Sans, environ 136 Ko pour chaque Mono).

- [ ] **Step 2: Déclarer les polices dans `pubspec.yaml`**

Sous la clé `flutter:` existante :

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: IBMPlexSans
      fonts:
        - asset: assets/fonts/IBMPlexSans-Variable.ttf
    - family: IBMPlexMono
      fonts:
        - asset: assets/fonts/IBMPlexMono-Regular.ttf
        - asset: assets/fonts/IBMPlexMono-Medium.ttf
          weight: 500
```

- [ ] **Step 3: Écrire le test du thème**

`test/ui/theme_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/ui/theme.dart';
import 'package:uhf_media/ui/tokens.dart';
import 'package:uhf_media/ui/typography.dart';

void main() {
  test('tokens hold the exact Signal palette', () {
    expect(UhfColors.ink, const Color(0xFF0D0D0C));
    expect(UhfColors.surface, const Color(0xFF161614));
    expect(UhfColors.raised, const Color(0xFF1F1E1B));
    expect(UhfColors.line, const Color(0xFF2B2A27));
    expect(UhfColors.text, const Color(0xFFECE9E2));
    expect(UhfColors.textMuted, const Color(0xFF8C8981));
    expect(UhfColors.signal, const Color(0xFFE8412C));
    expect(UhfColors.signalYellow, const Color(0xFFF5D90A));
  });

  test('theme is dark, flat and uses IBM Plex Sans', () {
    final theme = buildUhfTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, UhfColors.ink);
    expect(theme.colorScheme.primary, UhfColors.signal);
    expect(theme.colorScheme.surface, UhfColors.surface);
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.textTheme.bodyMedium!.fontFamily, UhfFonts.sans);
    expect(theme.textTheme.bodyMedium!.fontSize, 13);
  });

  test('mono style uses tabular figures', () {
    final style = UhfText.mono();
    expect(style.fontFamily, UhfFonts.mono);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  test('sans weight 500 sets both fontWeight and the wght axis', () {
    final style = UhfText.sans(weight: 500);
    expect(style.fontWeight, FontWeight.w500);
    expect(style.fontVariations, contains(const FontVariation('wght', 500)));
  });
}
```

- [ ] **Step 4: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/ui/theme_test.dart`
Expected: FAIL, imports `package:uhf_media/ui/...` introuvables.

- [ ] **Step 5: Écrire `lib/ui/tokens.dart`**

```dart
import 'dart:ui';

abstract final class UhfColors {
  static const ink = Color(0xFF0D0D0C);
  static const surface = Color(0xFF161614);
  static const raised = Color(0xFF1F1E1B);
  static const line = Color(0xFF2B2A27);
  static const text = Color(0xFFECE9E2);
  static const textMuted = Color(0xFF8C8981);
  static const signal = Color(0xFFE8412C);
  static const signalYellow = Color(0xFFF5D90A);
}

abstract final class UhfRadii {
  static const sm = 2.0;
  static const md = 3.0;
}

abstract final class UhfDurations {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 160);
  static const controlsHide = Duration(milliseconds: 2500);
  static const toast = Duration(seconds: 4);
  static const toastWithAction = Duration(seconds: 8);
  static const idleBlink = Duration(milliseconds: 500);
}

abstract final class UhfFonts {
  static const sans = 'IBMPlexSans';
  static const mono = 'IBMPlexMono';
}
```

- [ ] **Step 6: Écrire `lib/ui/typography.dart`**

```dart
import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class UhfText {
  static TextStyle sans({
    double size = 13,
    int weight = 400,
    Color color = UhfColors.text,
  }) {
    return TextStyle(
      fontFamily: UhfFonts.sans,
      fontSize: size,
      fontWeight: weight >= 500 ? FontWeight.w500 : FontWeight.w400,
      // The bundled IBM Plex Sans is a variable font: the wght axis must be
      // set explicitly, fontWeight alone does not move it on Windows.
      fontVariations: [FontVariation('wght', weight.toDouble())],
      color: color,
      height: 1.35,
    );
  }

  static TextStyle mono({
    double size = 12,
    int weight = 400,
    Color color = UhfColors.text,
  }) {
    return TextStyle(
      fontFamily: UhfFonts.mono,
      fontSize: size,
      fontWeight: weight >= 500 ? FontWeight.w500 : FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: color,
      height: 1.35,
    );
  }

  static final TextStyle body = sans();
  static final TextStyle caption = sans(size: 11, color: UhfColors.textMuted);
  static final TextStyle label = sans(weight: 500);

  static TextTheme get textTheme => TextTheme(
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: caption,
        labelLarge: label,
        labelMedium: label,
        labelSmall: caption,
        titleSmall: label,
        titleMedium: sans(size: 15, weight: 500),
      );
}
```

- [ ] **Step 7: Écrire `lib/ui/theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildUhfTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: UhfColors.signal,
    onPrimary: UhfColors.ink,
    secondary: UhfColors.text,
    onSecondary: UhfColors.ink,
    error: UhfColors.signal,
    onError: UhfColors.ink,
    surface: UhfColors.surface,
    onSurface: UhfColors.text,
    onSurfaceVariant: UhfColors.textMuted,
    outline: UhfColors.line,
    outlineVariant: UhfColors.line,
    surfaceContainerHighest: UhfColors.raised,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: UhfColors.ink,
    canvasColor: UhfColors.ink,
    fontFamily: UhfFonts.sans,
    textTheme: UhfText.textTheme,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: UhfColors.text.withValues(alpha: 0.06),
    focusColor: Colors.transparent,
    visualDensity: VisualDensity.compact,
    dividerColor: UhfColors.line,
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: UhfColors.raised,
        borderRadius: BorderRadius.circular(UhfRadii.sm),
        border: Border.all(color: UhfColors.line),
      ),
      textStyle: UhfText.sans(size: 11),
    ),
  );
}
```

- [ ] **Step 8: Appliquer le thème dans `UhfApp`**

Dans `lib/app/uhf_app.dart`, ajouter `import '../ui/theme.dart';` et le paramètre `theme: buildUhfTheme(),` dans `MaterialApp`.

- [ ] **Step 9: Lancer les tests**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 10: Commit**

```bash
git add assets/fonts pubspec.yaml lib/ui lib/app/uhf_app.dart test/ui
git commit -m "feat(ui): add Signal design tokens, typography and theme"
```

---

### Task 3: Traductions turc, français, anglais

**Files:**
- Create: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_tr.arb`
- Modify: `pubspec.yaml` (dépendances + `generate: true`), `lib/app/uhf_app.dart`
- Test: `test/l10n/l10n_test.dart`

**Interfaces:**
- Produces: `AppLocalizations` (généré dans `lib/l10n/app_localizations.dart`), clés `appTitle`, `idleHint`. `UhfApp` déclare `localizationsDelegates` et `supportedLocales` ; une langue non prise en charge retombe sur l'anglais.

- [ ] **Step 1: Ajouter les dépendances**

```powershell
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

Puis, dans `pubspec.yaml`, sous `flutter:`, ajouter `generate: true` (au même niveau que `uses-material-design`).

- [ ] **Step 2: Créer `l10n.yaml`**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

- [ ] **Step 3: Créer les fichiers ARB**

`lib/l10n/app_en.arb` :

```json
{
  "@@locale": "en",
  "appTitle": "UHF Media",
  "idleHint": "Drop a video here · Ctrl+O",
  "@idleHint": { "description": "Hint under the UHF logo when no file is open." }
}
```

`lib/l10n/app_fr.arb` :

```json
{
  "@@locale": "fr",
  "appTitle": "UHF Media",
  "idleHint": "Glisse une vidéo ici · Ctrl+O"
}
```

`lib/l10n/app_tr.arb` :

```json
{
  "@@locale": "tr",
  "appTitle": "UHF Media",
  "idleHint": "Bir videoyu buraya sürükleyin · Ctrl+O"
}
```

- [ ] **Step 4: Écrire le test**

`test/l10n/l10n_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';
import 'package:uhf_media/l10n/app_localizations.dart';

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Text(AppLocalizations.of(context).idleHint);
}

void main() {
  const cases = {
    Locale('en'): 'Drop a video here · Ctrl+O',
    Locale('fr'): 'Glisse une vidéo ici · Ctrl+O',
    Locale('tr'): 'Bir videoyu buraya sürükleyin · Ctrl+O',
    Locale('de'): 'Drop a video here · Ctrl+O',
  };

  for (final entry in cases.entries) {
    testWidgets('idleHint in ${entry.key}', (tester) async {
      await tester.pumpWidget(UhfApp(locale: entry.key, home: const _Hint()));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  test('supported locales are en, fr and tr', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {'en', 'fr', 'tr'},
    );
  });
}
```

- [ ] **Step 5: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/l10n/l10n_test.dart`
Expected: FAIL. Soit `app_localizations.dart` n'existe pas encore, soit le texte n'est pas trouvé, faute de délégués.

- [ ] **Step 6: Générer les traductions et brancher `UhfApp`**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart` créé.

Dans `lib/app/uhf_app.dart`, ajouter `import '../l10n/app_localizations.dart';` et, dans `MaterialApp` :

```dart
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (device, supported) {
        if (device == null) return const Locale('en');
        for (final locale in supported) {
          if (locale.languageCode == device.languageCode) return locale;
        }
        return const Locale('en');
      },
```

- [ ] **Step 7: Lancer les tests**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add l10n.yaml lib/l10n pubspec.yaml pubspec.lock lib/app/uhf_app.dart test/l10n
git commit -m "feat(l10n): add Turkish, French and English localizations"
```

---

### Task 4: Écran d'accueil UHF

**Files:**
- Create: `lib/features/shell/idle_screen.dart`
- Modify: `lib/app/uhf_app.dart` (accueil par défaut)
- Test: `test/features/shell/idle_screen_test.dart`

**Interfaces:**
- Consumes: `UhfColors`, `UhfText.caption`, `UhfDurations.idleBlink`, `AppLocalizations.idleHint`.
- Produces: `class IdleScreen extends StatefulWidget`, `class IdleSignalPainter extends CustomPainter { IdleSignalPainter({required bool barVisible}); final bool barVisible; static const Size logoSize; }`. `UhfApp(home: null)` affiche `IdleScreen`.

- [ ] **Step 1: Écrire le test**

`test/features/shell/idle_screen_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';
import 'package:uhf_media/features/shell/idle_screen.dart';

IdleSignalPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is IdleSignalPainter),
  );
  return paint.painter! as IdleSignalPainter;
}

void main() {
  testWidgets('shows the logo and the localized hint', (tester) async {
    await tester.pumpWidget(const UhfApp(locale: Locale('fr')));
    await tester.pump();
    expect(find.byType(IdleScreen), findsOneWidget);
    expect(find.text('Glisse une vidéo ici · Ctrl+O'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('last signal bar blinks every 500 ms', (tester) async {
    await tester.pumpWidget(const UhfApp());
    await tester.pump();
    expect(_painter(tester).barVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).barVisible, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).barVisible, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  test('painter repaints only when the blink state changes', () {
    final on = IdleSignalPainter(barVisible: true);
    expect(on.shouldRepaint(IdleSignalPainter(barVisible: true)), isFalse);
    expect(on.shouldRepaint(IdleSignalPainter(barVisible: false)), isTrue);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/shell/idle_screen_test.dart`
Expected: FAIL, `idle_screen.dart` introuvable.

- [ ] **Step 3: Écrire `lib/features/shell/idle_screen.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';

/// Start screen shown while no file is open: the red pixel "UHF" of an old
/// TV channel search, over a yellow signal bar whose last stroke blinks.
class IdleScreen extends StatefulWidget {
  const IdleScreen({super.key});

  @override
  State<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends State<IdleScreen> {
  late final Timer _timer;
  bool _barVisible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(UhfDurations.idleBlink, (_) {
      setState(() => _barVisible = !_barVisible);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: UhfColors.ink,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: IdleSignalPainter.logoSize,
              painter: IdleSignalPainter(barVisible: _barVisible),
            ),
            const SizedBox(height: 28),
            Text(AppLocalizations.of(context).idleHint, style: UhfText.caption),
          ],
        ),
      ),
    );
  }
}

class IdleSignalPainter extends CustomPainter {
  IdleSignalPainter({required this.barVisible});

  final bool barVisible;

  static const double _pixel = 10;
  static const double _textWidth = (3 * 5 + 2) * _pixel;
  static const double _textHeight = 7 * _pixel;
  static const double _rowGap = 26;
  static const double _barHeight = 34;
  static const int _barCount = 6;
  static const double _dotSize = 5;
  static const double _dotPitch = 10;

  static const Size logoSize = Size(_textWidth, _textHeight + _rowGap + _barHeight);

  // 5x7 bitmap glyphs; '1' is a filled pixel.
  static const Map<String, List<String>> _glyphs = {
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
    'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = UhfColors.signal;
    var cursorX = 0.0;
    for (final ch in 'UHF'.split('')) {
      final rows = _glyphs[ch]!;
      for (var row = 0; row < rows.length; row++) {
        for (var col = 0; col < rows[row].length; col++) {
          if (rows[row][col] == '1') {
            canvas.drawRect(
              Rect.fromLTWH(cursorX + col * _pixel, row * _pixel, _pixel, _pixel),
              red,
            );
          }
        }
      }
      cursorX += 6 * _pixel;
    }

    final yellow = Paint()..color = UhfColors.signalYellow;
    const rowTop = _textHeight + _rowGap;
    const half = _textWidth / 2;
    const pitch = half / _barCount;
    const barWidth = pitch * 0.4;
    for (var i = 0; i < _barCount; i++) {
      if (i == _barCount - 1 && !barVisible) continue;
      canvas.drawRect(Rect.fromLTWH(i * pitch, rowTop, barWidth, _barHeight), yellow);
    }
    const dotY = rowTop + _barHeight - _dotSize;
    var x = half + _dotPitch / 2;
    while (x + _dotSize <= _textWidth) {
      canvas.drawOval(Rect.fromLTWH(x, dotY, _dotSize, _dotSize), yellow);
      x += _dotPitch;
    }
  }

  @override
  bool shouldRepaint(IdleSignalPainter oldDelegate) => oldDelegate.barVisible != barVisible;
}
```

- [ ] **Step 4: Faire de `IdleScreen` l'accueil par défaut**

Dans `lib/app/uhf_app.dart`, ajouter `import '../features/shell/idle_screen.dart';` et remplacer `home: Scaffold(body: home ?? const SizedBox.expand()),` par :

```dart
      home: Scaffold(body: home ?? const IdleScreen()),
```

- [ ] **Step 5: Corriger le test de fumée de la tâche 1**

`IdleScreen` démarre un `Timer` : dans `test/app/uhf_app_test.dart`, ajouter `await tester.pumpWidget(const SizedBox());` à la fin du test, pour qu'aucun timer ne reste en attente.

- [ ] **Step 6: Lancer les tests**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 7: Vérifier à l'écran**

Run: `flutter run -d windows`
Expected : fenêtre « UHF Media » sur fond `#0D0D0C`, logo UHF rouge centré, barre jaune dont le dernier trait clignote, indication dans la langue du système. Fermer la fenêtre.

- [ ] **Step 8: Commit**

```bash
git add lib/features/shell lib/app/uhf_app.dart test/features test/app
git commit -m "feat(shell): add animated UHF idle screen"
```

---

### Task 5: Formatage des temps et des ratios

**Files:**
- Create: `lib/core/util/time_format.dart`
- Test: `test/core/util/time_format_test.dart`

**Interfaces:**
- Produces: `String formatTimecode(Duration? d)` → `HH:MM:SS` (heures sur au moins 2 chiffres, négatif ou `null` → `00:00:00`) ; `String formatSeconds3(Duration d)` → secondes avec 3 décimales (`"12.345"`) pour ffmpeg ; `String reducedRatio(int w, int h)` → `"16:9"`, `""` si une dimension est ≤ 0.

- [ ] **Step 1: Écrire le test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/util/time_format.dart';

void main() {
  group('formatTimecode', () {
    test('formats hours, minutes and seconds with two digits', () {
      expect(formatTimecode(const Duration(hours: 1, minutes: 48, seconds: 30)), '01:48:30');
      expect(formatTimecode(const Duration(minutes: 3, seconds: 7)), '00:03:07');
    });
    test('truncates milliseconds', () {
      expect(formatTimecode(const Duration(seconds: 59, milliseconds: 999)), '00:00:59');
    });
    test('null and negative become zero', () {
      expect(formatTimecode(null), '00:00:00');
      expect(formatTimecode(const Duration(seconds: -5)), '00:00:00');
    });
    test('keeps hours beyond 99', () {
      expect(formatTimecode(const Duration(hours: 120)), '120:00:00');
    });
  });

  test('formatSeconds3 prints seconds with three decimals', () {
    expect(formatSeconds3(const Duration(minutes: 1, seconds: 2, milliseconds: 345)), '62.345');
    expect(formatSeconds3(Duration.zero), '0.000');
  });

  group('reducedRatio', () {
    test('reduces by the greatest common divisor', () {
      expect(reducedRatio(1920, 1080), '16:9');
      expect(reducedRatio(1080, 1920), '9:16');
      expect(reducedRatio(1000, 1000), '1:1');
      expect(reducedRatio(1918, 1078), '959:539');
    });
    test('invalid sizes give an empty string', () {
      expect(reducedRatio(0, 1080), '');
      expect(reducedRatio(1920, -1), '');
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/util/time_format_test.dart`
Expected: FAIL, fichier introuvable.

- [ ] **Step 3: Écrire `lib/core/util/time_format.dart`**

```dart
String formatTimecode(Duration? d) {
  final totalSeconds = (d == null || d.isNegative) ? 0 : d.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}

String formatSeconds3(Duration d) {
  final ms = d.isNegative ? 0 : d.inMilliseconds;
  return '${ms ~/ 1000}.${(ms % 1000).toString().padLeft(3, '0')}';
}

String reducedRatio(int w, int h) {
  if (w <= 0 || h <= 0) return '';
  final g = _gcd(w, h);
  return '${w ~/ g}:${h ~/ g}';
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/core/util/time_format_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/util test/core/util
git commit -m "feat(core): add timecode and aspect ratio formatting"
```

---

### Task 6: Géométrie du recadrage

**Files:**
- Create: `lib/core/geometry/geometry.dart`, `lib/core/geometry/rotation.dart`, `lib/core/geometry/aspect_preset.dart`, `lib/core/geometry/crop_math.dart`
- Test: `test/core/geometry/crop_math_test.dart`

**Interfaces:**
- Produces:
  - `class IntSize { const IntSize(int width, int height); }`, `class IntRect { const IntRect(int x, int y, int width, int height); }`, `class DRect { const DRect(double left, double top, double width, double height); }`, `class RatioRect { const RatioRect(double left, double top, double width, double height); }`, toutes avec `==`, `hashCode` et `toString`.
  - `enum Rotation { none, cw90, ccw90, half }`, avec `int degrees` (0, 90, 270, 180, valeur de `video-rotate`), `bool swapsAxes`, `Rotation next` (ordre none → cw90 → ccw90 → half → none) et `String suffix` (`''`, `'_rot90'`, `'_rot270'`, `'_rot180'`).
  - `enum AspectPreset { free, r16x9, r9x16, r1x1, r4x3 }`, avec `double? ratio` et `String label` (`'16:9'`…, `''` pour `free`, dont le libellé est traduit dans le plan 3).
  - `abstract final class CropMath` :
    - `static IntSize displaySize(IntSize source, Rotation r)` ;
    - `static DRect? videoRectInViewport(IntSize source, Rotation r, double viewportWidth, double viewportHeight)` (`null` si une taille est nulle) ;
    - `static IntRect displayToSource(RatioRect crop, Rotation r, IntSize source)` ;
    - `static IntRect adjustForInterlace(IntRect r)` ;
    - `static IntSize outputSize(IntRect sourceCrop, Rotation r)` ;
    - `static const RatioRect defaultCrop` (0,15 ; 0,15 ; 0,7 ; 0,7) ;
    - `static RatioRect fitPreset(AspectPreset p, IntSize display)`.

- [ ] **Step 1: Écrire le test**

`test/core/geometry/crop_math_test.dart` :

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/aspect_preset.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

void main() {
  const fullHd = IntSize(1920, 1080);

  group('Rotation', () {
    test('mpv degrees and axis swap', () {
      expect(Rotation.none.degrees, 0);
      expect(Rotation.cw90.degrees, 90);
      expect(Rotation.ccw90.degrees, 270);
      expect(Rotation.half.degrees, 180);
      expect(Rotation.cw90.swapsAxes, isTrue);
      expect(Rotation.half.swapsAxes, isFalse);
    });
    test('next cycles 0, 90, -90, 180', () {
      expect(Rotation.none.next, Rotation.cw90);
      expect(Rotation.cw90.next, Rotation.ccw90);
      expect(Rotation.ccw90.next, Rotation.half);
      expect(Rotation.half.next, Rotation.none);
    });
  });

  test('displaySize swaps for quarter turns', () {
    expect(CropMath.displaySize(fullHd, Rotation.cw90), const IntSize(1080, 1920));
    expect(CropMath.displaySize(fullHd, Rotation.half), fullHd);
  });

  test('videoRectInViewport letterboxes', () {
    expect(
      CropMath.videoRectInViewport(fullHd, Rotation.none, 1000, 1000),
      const DRect(0, 218.75, 1000, 562.5),
    );
    expect(
      CropMath.videoRectInViewport(fullHd, Rotation.cw90, 1000, 1000),
      const DRect(218.75, 0, 562.5, 1000),
    );
    expect(CropMath.videoRectInViewport(fullHd, Rotation.none, 0, 500), isNull);
  });

  group('displayToSource (values from the Python implementation)', () {
    test('no rotation', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.25, 0.25, 0.5, 0.5), Rotation.none, fullHd),
        const IntRect(480, 270, 960, 540),
      );
    });
    test('90 degrees clockwise', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.1, 0.2, 0.5, 0.25), Rotation.cw90, fullHd),
        const IntRect(384, 432, 480, 540),
      );
    });
    test('90 degrees counter-clockwise', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.1, 0.2, 0.5, 0.25), Rotation.ccw90, fullHd),
        const IntRect(1056, 108, 480, 540),
      );
    });
    test('180 degrees', () {
      expect(
        CropMath.displayToSource(const RatioRect(0.1, 0.2, 0.5, 0.25), Rotation.half, fullHd),
        const IntRect(768, 594, 960, 270),
      );
    });
    test('odd source sizes give even dimensions', () {
      expect(
        CropMath.displayToSource(const RatioRect(0, 0, 1, 1), Rotation.none, const IntSize(1919, 1079)),
        const IntRect(0, 0, 1918, 1078),
      );
    });
    test('any crop stays inside the source, even and positive (review focus 4)', () {
      final rnd = Random(42);
      for (final source in const [IntSize(1919, 1079), IntSize(1080, 1920), IntSize(721, 481)]) {
        for (final rotation in Rotation.values) {
          for (var i = 0; i < 500; i++) {
            final w = 0.02 + rnd.nextDouble() * 0.98;
            final h = 0.02 + rnd.nextDouble() * 0.98;
            final crop = RatioRect(rnd.nextDouble() * (1 - w), rnd.nextDouble() * (1 - h), w, h);
            final r = CropMath.displayToSource(crop, rotation, source);
            expect(r.x, greaterThanOrEqualTo(0), reason: '$crop $rotation');
            expect(r.y, greaterThanOrEqualTo(0), reason: '$crop $rotation');
            expect(r.width.isEven && r.height.isEven, isTrue, reason: '$crop $rotation');
            expect(r.width, greaterThan(0));
            expect(r.height, greaterThan(0));
            expect(r.x + r.width, lessThanOrEqualTo(source.width), reason: '$crop $rotation');
            expect(r.y + r.height, lessThanOrEqualTo(source.height), reason: '$crop $rotation');
          }
        }
      }
    });
  });

  test('adjustForInterlace makes y even and height a multiple of 4', () {
    expect(CropMath.adjustForInterlace(const IntRect(10, 33, 200, 102)), const IntRect(10, 32, 200, 100));
    expect(CropMath.adjustForInterlace(const IntRect(0, 0, 200, 100)), const IntRect(0, 0, 200, 100));
  });

  test('outputSize swaps for quarter turns', () {
    expect(CropMath.outputSize(const IntRect(384, 432, 480, 540), Rotation.cw90), const IntSize(540, 480));
    expect(CropMath.outputSize(const IntRect(0, 0, 960, 270), Rotation.half), const IntSize(960, 270));
  });

  group('fitPreset', () {
    test('free returns the default 70 % crop', () {
      expect(CropMath.fitPreset(AspectPreset.free, fullHd), CropMath.defaultCrop);
    });
    test('16:9 on a 16:9 picture fills the 70 % box', () {
      final r = CropMath.fitPreset(AspectPreset.r16x9, fullHd);
      expect(r.left, closeTo(0.15, 1e-9));
      expect(r.top, closeTo(0.15, 1e-9));
      expect(r.width, closeTo(0.7, 1e-9));
      expect(r.height, closeTo(0.7, 1e-9));
    });
    test('9:16 on a 16:9 picture is height-bound and centered', () {
      final r = CropMath.fitPreset(AspectPreset.r9x16, fullHd);
      expect(r.height, closeTo(0.7, 1e-9));
      expect(r.width, closeTo(425.25 / 1920, 1e-9));
      expect(r.left, closeTo((1 - 425.25 / 1920) / 2, 1e-9));
      expect(r.width * 1920 / (r.height * 1080), closeTo(9 / 16, 1e-9));
    });
    test('1:1 on a vertical picture is width-bound', () {
      final r = CropMath.fitPreset(AspectPreset.r1x1, const IntSize(1080, 1920));
      expect(r.width, closeTo(0.7, 1e-9));
      expect(r.width * 1080, closeTo(r.height * 1920, 1e-6));
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/geometry/crop_math_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/core/geometry/geometry.dart`**

```dart
class IntSize {
  const IntSize(this.width, this.height);
  final int width;
  final int height;

  @override
  bool operator ==(Object other) => other is IntSize && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(width, height);
  @override
  String toString() => 'IntSize($width, $height)';
}

class IntRect {
  const IntRect(this.x, this.y, this.width, this.height);
  final int x;
  final int y;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is IntRect && other.x == x && other.y == y && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(x, y, width, height);
  @override
  String toString() => 'IntRect($x, $y, $width, $height)';
}

/// A rectangle in logical pixels (viewport space).
class DRect {
  const DRect(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is DRect && other.left == left && other.top == top && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(left, top, width, height);
  @override
  String toString() => 'DRect($left, $top, $width, $height)';
}

/// A rectangle expressed as fractions (0..1) of the displayed picture.
class RatioRect {
  const RatioRect(this.left, this.top, this.width, this.height);
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is RatioRect && other.left == left && other.top == top && other.width == width && other.height == height;
  @override
  int get hashCode => Object.hash(left, top, width, height);
  @override
  String toString() => 'RatioRect($left, $top, $width, $height)';
}
```

- [ ] **Step 4: Écrire `lib/core/geometry/rotation.dart` et `aspect_preset.dart`**

`rotation.dart` :

```dart
enum Rotation {
  none(0, ''),
  cw90(90, '_rot90'),
  ccw90(270, '_rot270'),
  half(180, '_rot180');

  const Rotation(this.degrees, this.suffix);

  /// Value of mpv's `video-rotate` property.
  final int degrees;

  /// Output file name suffix.
  final String suffix;

  bool get swapsAxes => this == cw90 || this == ccw90;

  Rotation get next => switch (this) {
        none => cw90,
        cw90 => ccw90,
        ccw90 => half,
        half => none,
      };
}
```

`aspect_preset.dart` :

```dart
enum AspectPreset {
  free(null, ''),
  r16x9(16 / 9, '16:9'),
  r9x16(9 / 16, '9:16'),
  r1x1(1, '1:1'),
  r4x3(4 / 3, '4:3');

  const AspectPreset(this.ratio, this.label);

  /// Width / height of the output picture, null when unconstrained.
  final double? ratio;
  final String label;
}
```

- [ ] **Step 5: Écrire `lib/core/geometry/crop_math.dart`**

```dart
import 'dart:math' as math;

import 'aspect_preset.dart';
import 'geometry.dart';
import 'rotation.dart';

abstract final class CropMath {
  static const RatioRect defaultCrop = RatioRect(0.15, 0.15, 0.7, 0.7);

  static IntSize displaySize(IntSize source, Rotation r) =>
      r.swapsAxes ? IntSize(source.height, source.width) : source;

  /// Where the picture is drawn inside a viewport (letterboxed, centered).
  static DRect? videoRectInViewport(IntSize source, Rotation r, double viewportWidth, double viewportHeight) {
    final display = displaySize(source, r);
    if (viewportWidth <= 0 || viewportHeight <= 0 || display.width <= 0 || display.height <= 0) {
      return null;
    }
    final scale = math.min(viewportWidth / display.width, viewportHeight / display.height);
    final w = display.width * scale;
    final h = display.height * scale;
    return DRect((viewportWidth - w) / 2, (viewportHeight - h) / 2, w, h);
  }

  /// Maps a crop drawn on the rotated picture back to unrotated source
  /// pixels, where ffmpeg's crop filter runs (before transpose).
  static IntRect displayToSource(RatioRect crop, Rotation r, IntSize source) {
    final display = displaySize(source, r);
    final rx = crop.left * display.width;
    final ry = crop.top * display.height;
    final rw = crop.width * display.width;
    final rh = crop.height * display.height;
    final w0 = source.width;
    final h0 = source.height;

    final (double x, double y, double w, double h) = switch (r) {
      Rotation.none => (rx, ry, rw, rh),
      Rotation.cw90 => (ry, h0 - rx - rw, rh, rw),
      Rotation.ccw90 => (w0 - ry - rh, rx, rh, rw),
      Rotation.half => (w0 - rx - rw, h0 - ry - rh, rw, rh),
    };

    var ix = math.max(0, x.toInt());
    var iy = math.max(0, y.toInt());
    var iw = math.min(w.toInt(), w0);
    var ih = math.min(h.toInt(), h0);
    iw -= iw % 2;
    ih -= ih % 2;
    iw = math.max(2, iw);
    ih = math.max(2, ih);
    if (ix + iw > w0) ix -= ix + iw - w0;
    if (iy + ih > h0) iy -= iy + ih - h0;
    return IntRect(math.max(0, ix), math.max(0, iy), iw, ih);
  }

  /// x264 interlaced encoding needs an even top edge (keeps field parity)
  /// and a height divisible by 4.
  static IntRect adjustForInterlace(IntRect r) {
    final y = r.y.isOdd ? r.y - 1 : r.y;
    return IntRect(r.x, y, r.width, r.height - r.height % 4);
  }

  static IntSize outputSize(IntRect sourceCrop, Rotation r) => r.swapsAxes
      ? IntSize(sourceCrop.height, sourceCrop.width)
      : IntSize(sourceCrop.width, sourceCrop.height);

  /// Largest rectangle of the preset's ratio that fits in 70 % of the
  /// displayed picture, centered.
  static RatioRect fitPreset(AspectPreset preset, IntSize display) {
    final ratio = preset.ratio;
    if (ratio == null || display.width <= 0 || display.height <= 0) return defaultCrop;
    final boxW = display.width * 0.7;
    final boxH = display.height * 0.7;
    double w;
    double h;
    if (boxW / boxH > ratio) {
      h = boxH;
      w = h * ratio;
    } else {
      w = boxW;
      h = w / ratio;
    }
    final rw = w / display.width;
    final rh = h / display.height;
    return RatioRect((1 - rw) / 2, (1 - rh) / 2, rw, rh);
  }
}
```

- [ ] **Step 6: Lancer les tests**

Run: `flutter test test/core/geometry/crop_math_test.dart`
Expected: PASS. Si le test aléatoire échoue sur un cas où `width` ou `height` vaut 2 alors que la source fait moins de 2 px, ce cas est hors domaine : les sources mesurent au moins 2 px.

- [ ] **Step 7: Commit**

```bash
git add lib/core/geometry test/core/geometry
git commit -m "feat(core): add crop geometry with rotation mapping and aspect presets"
```

---

### Task 7: Analyse du JSON ffprobe

**Files:**
- Create: `lib/core/ffmpeg/probe_result.dart`
- Test: `test/core/ffmpeg/probe_result_test.dart`

**Interfaces:**
- Produces:
  - `enum FieldOrder { progressive, tff, bff }` ;
  - `class SubtitleStreamInfo { const SubtitleStreamInfo({required int index, required String codec, required bool isText}); }` ;
  - `class ProbeResult`, avec `int? videoBitRate`, `FieldOrder fieldOrder`, `String? frameRate`, `int bitDepth`, `Duration? duration`, `List<SubtitleStreamInfo> subtitles`, `bool get isInterlaced`, et `static ProbeResult parse(String json)` (lève `FormatException` si le JSON n'est pas un objet).
  - La commande qui produit ce JSON (plan 3) : `ffprobe -v error -print_format json -show_streams -show_format <fichier>`.

- [ ] **Step 1: Écrire le test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';

const _progressiveMkv = '''
{
  "streams": [
    {"index": 0, "codec_type": "video", "codec_name": "h264", "pix_fmt": "yuv420p",
     "bits_per_raw_sample": "8", "field_order": "progressive", "r_frame_rate": "30000/1001",
     "bit_rate": "8000000"},
    {"index": 1, "codec_type": "audio", "codec_name": "aac"},
    {"index": 2, "codec_type": "subtitle", "codec_name": "subrip"},
    {"index": 3, "codec_type": "subtitle", "codec_name": "hdmv_pgs_subtitle"}
  ],
  "format": {"duration": "5400.250000", "bit_rate": "9000000"}
}
''';

const _interlacedTs = '''
{
  "streams": [
    {"index": 0, "codec_type": "video", "codec_name": "mpeg2video", "pix_fmt": "yuv420p",
     "field_order": "tt", "r_frame_rate": "25/1"}
  ],
  "format": {"duration": "60.0", "bit_rate": "15000000"}
}
''';

const _hdrHevc = '''
{
  "streams": [
    {"index": 0, "codec_type": "video", "codec_name": "hevc", "pix_fmt": "yuv420p10le",
     "field_order": "bb", "r_frame_rate": "0/0"}
  ],
  "format": {}
}
''';

void main() {
  test('progressive mkv: stream bit rate, fps fraction, subtitles', () {
    final p = ProbeResult.parse(_progressiveMkv);
    expect(p.videoBitRate, 8000000);
    expect(p.fieldOrder, FieldOrder.progressive);
    expect(p.isInterlaced, isFalse);
    expect(p.frameRate, '30000/1001');
    expect(p.bitDepth, 8);
    expect(p.duration, const Duration(seconds: 5400, milliseconds: 250));
    expect(p.subtitles.map((s) => (s.index, s.isText)).toList(), [(2, true), (3, false)]);
  });

  test('interlaced ts: tff, format bit rate fallback', () {
    final p = ProbeResult.parse(_interlacedTs);
    expect(p.fieldOrder, FieldOrder.tff);
    expect(p.isInterlaced, isTrue);
    expect(p.videoBitRate, 15000000);
    expect(p.frameRate, '25/1');
  });

  test('10-bit from pix_fmt, bff, unknown fps and bit rate', () {
    final p = ProbeResult.parse(_hdrHevc);
    expect(p.bitDepth, 10);
    expect(p.fieldOrder, FieldOrder.bff);
    expect(p.frameRate, isNull);
    expect(p.videoBitRate, isNull);
    expect(p.duration, isNull);
  });

  test('no video stream yields defaults', () {
    final p = ProbeResult.parse('{"streams": [], "format": {}}');
    expect(p.bitDepth, 8);
    expect(p.fieldOrder, FieldOrder.progressive);
    expect(p.subtitles, isEmpty);
  });

  test('non-object JSON is a FormatException', () {
    expect(() => ProbeResult.parse('[]'), throwsFormatException);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/ffmpeg/probe_result_test.dart`
Expected: FAIL, fichier introuvable.

- [ ] **Step 3: Écrire `lib/core/ffmpeg/probe_result.dart`**

```dart
import 'dart:convert';

enum FieldOrder { progressive, tff, bff }

class SubtitleStreamInfo {
  const SubtitleStreamInfo({required this.index, required this.codec, required this.isText});

  /// Absolute stream index, usable as `-map 0:<index>`.
  final int index;
  final String codec;

  /// Text subtitles can be converted to mov_text; image ones cannot.
  final bool isText;
}

class ProbeResult {
  const ProbeResult({
    required this.videoBitRate,
    required this.fieldOrder,
    required this.frameRate,
    required this.bitDepth,
    required this.duration,
    required this.subtitles,
  });

  final int? videoBitRate;
  final FieldOrder fieldOrder;

  /// Fraction as ffprobe prints it ("30000/1001"), null when unknown.
  final String? frameRate;
  final int bitDepth;
  final Duration? duration;
  final List<SubtitleStreamInfo> subtitles;

  bool get isInterlaced => fieldOrder != FieldOrder.progressive;

  static const _textSubtitleCodecs = {'subrip', 'srt', 'ass', 'ssa', 'webvtt', 'mov_text', 'text'};

  static ProbeResult parse(String json) {
    final root = jsonDecode(json);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('ffprobe output is not a JSON object');
    }
    final streams = (root['streams'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final format = root['format'] is Map<String, dynamic> ? root['format'] as Map<String, dynamic> : const {};
    final video = streams.where((s) => s['codec_type'] == 'video').firstOrNull;

    return ProbeResult(
      videoBitRate: _positiveInt(video?['bit_rate']) ?? _positiveInt(format['bit_rate']),
      fieldOrder: _fieldOrder(video?['field_order']),
      frameRate: _frameRate(video?['r_frame_rate']),
      bitDepth: _bitDepth(video),
      duration: _duration(format['duration']),
      subtitles: [
        for (final s in streams)
          if (s['codec_type'] == 'subtitle' && s['index'] is int)
            SubtitleStreamInfo(
              index: s['index'] as int,
              codec: '${s['codec_name'] ?? ''}',
              isText: _textSubtitleCodecs.contains(s['codec_name']),
            ),
      ],
    );
  }

  static int? _positiveInt(Object? v) {
    final parsed = v is int ? v : int.tryParse('${v ?? ''}');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static FieldOrder _fieldOrder(Object? v) {
    final s = '${v ?? ''}'.toLowerCase();
    if (s.startsWith('t')) return FieldOrder.tff;
    if (s.startsWith('b')) return FieldOrder.bff;
    return FieldOrder.progressive;
  }

  static String? _frameRate(Object? v) {
    final s = '${v ?? ''}'.trim();
    if (s.isEmpty || s == '0/0' || s == 'N/A') return null;
    return s;
  }

  static int _bitDepth(Map<String, dynamic>? video) {
    if (video == null) return 8;
    final raw = _positiveInt(video['bits_per_raw_sample']);
    if (raw != null) return raw;
    final pix = '${video['pix_fmt'] ?? ''}';
    if (pix.contains('10le') || pix.contains('10be')) return 10;
    if (pix.contains('12le') || pix.contains('12be')) return 12;
    return 8;
  }

  static Duration? _duration(Object? v) {
    final seconds = double.tryParse('${v ?? ''}');
    if (seconds == null || seconds <= 0) return null;
    return Duration(microseconds: (seconds * 1e6).round());
  }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/core/ffmpeg/probe_result_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/ffmpeg/probe_result.dart test/core/ffmpeg/probe_result_test.dart
git commit -m "feat(ffmpeg): parse ffprobe JSON into ProbeResult"
```

---

### Task 8: Commande d'export ffmpeg

**Files:**
- Create: `lib/core/ffmpeg/export_plan.dart`, `lib/core/ffmpeg/export_command_builder.dart`
- Test: `test/core/ffmpeg/export_command_builder_test.dart`

**Interfaces:**
- Consumes: `IntRect`, `Rotation` (tâche 6), `ProbeResult`, `FieldOrder`, `SubtitleStreamInfo` (tâche 7), `formatSeconds3` (tâche 5).
- Produces:
  - `class TrimRange { const TrimRange(Duration start, Duration end); Duration get length; }` ;
  - `enum HwEncoder { nvenc('h264_nvenc'), qsv('h264_qsv'), amf('h264_amf'); final String ffmpegName; }` ;
  - `class ExportPlan { const ExportPlan({required String inputPath, required String outputPath, Rotation rotation = Rotation.none, IntRect? crop, TrimRange? trim, int? videoFfIndex, int? audioFfIndex}); }`, où `crop` est en pixels source, issu de `CropMath.displayToSource` ;
  - `enum ExportPlanError { noChanges, trimTooShort, cropTooSmall }` et `class ExportPlanException implements Exception { final ExportPlanError error; }` ;
  - `class ExportCommand { final List<String> args; final bool usesHardware; final bool bobDeinterlace; final List<String> videoFilters; }`. Les `args` ne contiennent pas le chemin de ffmpeg, que l'`ExportRunner` du plan 3 ajoute en tête ;
  - `abstract final class ExportCommandBuilder { static ExportCommand build(ExportPlan plan, ProbeResult probe, {HwEncoder? hwEncoder}); }`. L'appelant relance avec `hwEncoder: null` pour passer au CPU ;
  - `HwEncoder? pickHwEncoder(String encodersOutput)`, qui analyse la sortie de `ffmpeg -hide_banner -encoders`.

- [ ] **Step 1: Écrire le test**

`test/core/ffmpeg/export_command_builder_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_command_builder.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

ProbeResult _probe({
  int? bitRate = 8000000,
  FieldOrder fieldOrder = FieldOrder.progressive,
  String? frameRate = '25/1',
  int bitDepth = 8,
  List<SubtitleStreamInfo> subtitles = const [],
}) =>
    ProbeResult(
      videoBitRate: bitRate,
      fieldOrder: fieldOrder,
      frameRate: frameRate,
      bitDepth: bitDepth,
      duration: const Duration(minutes: 10),
      subtitles: subtitles,
    );

const _head = ['-y', '-hide_banner', '-nostdin', '-nostats', '-progress', 'pipe:1'];

void main() {
  group('validation', () {
    test('nothing selected', () {
      expect(
        () => ExportCommandBuilder.build(
          const ExportPlan(inputPath: 'in.mp4', outputPath: 'out.mp4'),
          _probe(),
        ),
        throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.noChanges)),
      );
    });
    test('trim shorter than 0.1 s', () {
      expect(
        () => ExportCommandBuilder.build(
          const ExportPlan(
            inputPath: 'in.mp4',
            outputPath: 'out.mp4',
            trim: TrimRange(Duration(seconds: 5), Duration(seconds: 5, milliseconds: 50)),
          ),
          _probe(),
        ),
        throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.trimTooShort)),
      );
    });
    test('crop smaller than 2 px after interlace adjustment', () {
      expect(
        () => ExportCommandBuilder.build(
          const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', crop: IntRect(0, 1, 100, 2)),
          _probe(fieldOrder: FieldOrder.tff),
        ),
        throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.cropTooSmall)),
      );
    });
  });

  test('GPU, crop + rotate, known bit rate, mkv', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(
        inputPath: r'C:\v\in.mkv',
        outputPath: r'C:\v\in_crop_rot90.mkv',
        rotation: Rotation.cw90,
        crop: IntRect(384, 432, 480, 540),
        videoFfIndex: 0,
        audioFfIndex: 2,
      ),
      _probe(),
      hwEncoder: HwEncoder.nvenc,
    );
    expect(cmd.usesHardware, isTrue);
    expect(cmd.args, [
      ..._head,
      '-i', r'C:\v\in.mkv',
      '-filter:v', 'crop=480:540:384:432,transpose=1,format=yuv420p',
      '-map', '0:0', '-map', '0:2',
      '-map', '0:s?', '-c:s', 'copy',
      '-c:v', 'h264_nvenc', '-b:v', '8000000', '-maxrate', '8000000', '-bufsize', '16000000',
      '-rc:v', 'vbr', '-preset', 'p4',
      '-pix_fmt', 'yuv420p', '-c:a', 'copy', '-map_metadata', '0',
      r'C:\v\in_crop_rot90.mkv',
    ]);
  });

  test('CPU with bit rate, 180 degrees, trim with a single input seek', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(
        inputPath: 'in.mkv',
        outputPath: 'out.mkv',
        rotation: Rotation.half,
        trim: TrimRange(Duration(minutes: 1, seconds: 2, milliseconds: 345), Duration(minutes: 2)),
      ),
      _probe(),
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.args, [
      ..._head,
      '-ss', '62.345', '-i', 'in.mkv', '-t', '57.655',
      '-filter:v', 'hflip,vflip',
      '-map', '0:v:0', '-map', '0:a:0?',
      '-map', '0:s?', '-c:s', 'copy',
      '-c:v', 'libx264', '-b:v', '8000000', '-minrate', '8000000', '-maxrate', '8000000',
      '-bufsize', '16000000', '-preset', 'medium',
      '-pix_fmt', 'yuv420p', '-c:a', 'copy', '-map_metadata', '0',
      'out.mkv',
    ]);
  });

  test('unknown bit rate falls back to CRF and never uses the GPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', rotation: Rotation.ccw90),
      _probe(bitRate: null),
      hwEncoder: HwEncoder.qsv,
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.args, containsAllInOrder(['-filter:v', 'transpose=2', '-c:v', 'libx264', '-crf', '16', '-preset', 'slow']));
  });

  test('10-bit source never uses the GPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', rotation: Rotation.cw90),
      _probe(bitDepth: 10),
      hwEncoder: HwEncoder.amf,
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.args, isNot(contains('format=yuv420p')));
  });

  test('interlaced without rotation keeps fields on the CPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.ts', outputPath: 'out.mkv', crop: IntRect(10, 33, 640, 362)),
      _probe(fieldOrder: FieldOrder.bff, frameRate: '30000/1001'),
      hwEncoder: HwEncoder.nvenc,
    );
    expect(cmd.usesHardware, isFalse);
    expect(cmd.bobDeinterlace, isFalse);
    expect(cmd.videoFilters, ['crop=640:360:10:32']);
    expect(
      cmd.args,
      containsAllInOrder([
        '-flags:v', '+ildct+ilme', '-x264opts', 'bff=1', '-r', '30000/1001', '-fps_mode', 'cfr',
        '-pix_fmt', 'yuv420p',
      ]),
    );
  });

  test('interlaced with rotation bob-deinterlaces first and may use the GPU', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.ts', outputPath: 'out.mkv', rotation: Rotation.cw90),
      _probe(fieldOrder: FieldOrder.tff),
      hwEncoder: HwEncoder.nvenc,
    );
    expect(cmd.bobDeinterlace, isTrue);
    expect(cmd.usesHardware, isTrue);
    expect(cmd.videoFilters.first, 'yadif=mode=send_field:parity=auto:deint=interlaced');
    expect(cmd.args, isNot(contains('-x264opts')));
  });

  test('mp4 family output converts text subtitles and drops image ones', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mov', outputPath: 'out_rot90.mov', rotation: Rotation.cw90),
      _probe(subtitles: const [
        SubtitleStreamInfo(index: 2, codec: 'subrip', isText: true),
        SubtitleStreamInfo(index: 3, codec: 'hdmv_pgs_subtitle', isText: false),
      ]),
    );
    expect(cmd.args, containsAllInOrder(['-map', '0:2', '-c:s', 'mov_text']));
    expect(cmd.args, isNot(contains('0:3')));
    expect(cmd.args, isNot(contains('0:s?')));
  });

  test('mp4 output without text subtitles maps none', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mp4', outputPath: 'out.mp4', rotation: Rotation.cw90),
      _probe(),
    );
    expect(cmd.args, isNot(contains('-c:s')));
  });

  test('paths with spaces and Turkish characters stay single arguments (review focus 1)', () {
    const input = r'C:\Vidéos\şarkı test (1).mkv';
    const output = r'C:\Vidéos\şarkı test (1)_rot90.mkv';
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: input, outputPath: output, rotation: Rotation.cw90),
      _probe(),
    );
    expect(cmd.args[cmd.args.indexOf('-i') + 1], input);
    expect(cmd.args.last, output);
    expect(cmd.args.where((a) => a.contains('"')), isEmpty);
  });

  test('missing ff-index falls back to first video and optional first audio (review focus 2)', () {
    final cmd = ExportCommandBuilder.build(
      const ExportPlan(inputPath: 'in.mkv', outputPath: 'out.mkv', rotation: Rotation.cw90, audioFfIndex: null),
      _probe(),
    );
    expect(cmd.args, containsAllInOrder(['-map', '0:v:0', '-map', '0:a:0?']));
  });

  group('pickHwEncoder', () {
    test('prefers NVENC, then QSV, then AMF', () {
      expect(pickHwEncoder(' V....D h264_amf  AMD\n V....D h264_qsv  Intel\n V....D h264_nvenc NVIDIA'), HwEncoder.nvenc);
      expect(pickHwEncoder(' V....D h264_amf  AMD\n V....D h264_qsv  Intel'), HwEncoder.qsv);
      expect(pickHwEncoder(' V....D h264_amf  AMD'), HwEncoder.amf);
      expect(pickHwEncoder(' V....D libx264  x264'), isNull);
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/ffmpeg/export_command_builder_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/core/ffmpeg/export_plan.dart`**

```dart
import '../geometry/geometry.dart';
import '../geometry/rotation.dart';

class TrimRange {
  const TrimRange(this.start, this.end);
  final Duration start;
  final Duration end;
  Duration get length => end - start;
}

enum HwEncoder {
  nvenc('h264_nvenc'),
  qsv('h264_qsv'),
  amf('h264_amf');

  const HwEncoder(this.ffmpegName);
  final String ffmpegName;
}

class ExportPlan {
  const ExportPlan({
    required this.inputPath,
    required this.outputPath,
    this.rotation = Rotation.none,
    this.crop,
    this.trim,
    this.videoFfIndex,
    this.audioFfIndex,
  });

  final String inputPath;
  final String outputPath;
  final Rotation rotation;

  /// Crop in unrotated source pixels (see CropMath.displayToSource).
  final IntRect? crop;
  final TrimRange? trim;

  /// mpv `ff-index` of the selected tracks, used as `-map 0:<index>`.
  final int? videoFfIndex;
  final int? audioFfIndex;
}

enum ExportPlanError { noChanges, trimTooShort, cropTooSmall }

class ExportPlanException implements Exception {
  const ExportPlanException(this.error);
  final ExportPlanError error;

  @override
  String toString() => 'ExportPlanException($error)';
}
```

- [ ] **Step 4: Écrire `lib/core/ffmpeg/export_command_builder.dart`**

```dart
import '../geometry/crop_math.dart';
import '../geometry/rotation.dart';
import '../util/time_format.dart';
import 'export_plan.dart';
import 'probe_result.dart';

class ExportCommand {
  const ExportCommand({
    required this.args,
    required this.usesHardware,
    required this.bobDeinterlace,
    required this.videoFilters,
  });

  /// ffmpeg arguments, without the executable path.
  final List<String> args;
  final bool usesHardware;
  final bool bobDeinterlace;
  final List<String> videoFilters;
}

HwEncoder? pickHwEncoder(String encodersOutput) {
  for (final encoder in HwEncoder.values) {
    if (encodersOutput.contains(encoder.ffmpegName)) return encoder;
  }
  return null;
}

bool _isMp4Family(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.m4v');
}

abstract final class ExportCommandBuilder {
  static const _minTrim = Duration(milliseconds: 100);

  static ExportCommand build(ExportPlan plan, ProbeResult probe, {HwEncoder? hwEncoder}) {
    final doRotate = plan.rotation != Rotation.none;
    final doCrop = plan.crop != null;
    final trim = plan.trim;
    if (!doRotate && !doCrop && trim == null) {
      throw const ExportPlanException(ExportPlanError.noChanges);
    }
    if (trim != null && trim.length < _minTrim) {
      throw const ExportPlanException(ExportPlanError.trimTooShort);
    }

    final preserveInterlace = probe.isInterlaced && !doRotate;
    final bob = probe.isInterlaced && doRotate;

    final filters = <String>[];
    if (bob) filters.add('yadif=mode=send_field:parity=auto:deint=interlaced');
    if (doCrop) {
      final crop = preserveInterlace ? CropMath.adjustForInterlace(plan.crop!) : plan.crop!;
      if (crop.width < 2 || crop.height < 2) {
        throw const ExportPlanException(ExportPlanError.cropTooSmall);
      }
      filters.add('crop=${crop.width}:${crop.height}:${crop.x}:${crop.y}');
    }
    switch (plan.rotation) {
      case Rotation.cw90:
        filters.add('transpose=1');
      case Rotation.ccw90:
        filters.add('transpose=2');
      case Rotation.half:
        filters..add('hflip')..add('vflip');
      case Rotation.none:
        break;
    }

    final bitRate = probe.videoBitRate;
    final useHw = hwEncoder != null && bitRate != null && !preserveInterlace && probe.bitDepth <= 8;
    final videoFilters = [...filters, if (useHw) 'format=yuv420p'];

    final args = <String>['-y', '-hide_banner', '-nostdin', '-nostats', '-progress', 'pipe:1'];
    if (trim != null) {
      args.addAll(['-ss', formatSeconds3(trim.start), '-i', plan.inputPath, '-t', formatSeconds3(trim.length)]);
    } else {
      args.addAll(['-i', plan.inputPath]);
    }
    if (videoFilters.isNotEmpty) args.addAll(['-filter:v', videoFilters.join(',')]);

    args.addAll(['-map', plan.videoFfIndex != null ? '0:${plan.videoFfIndex}' : '0:v:0']);
    args.addAll(['-map', plan.audioFfIndex != null ? '0:${plan.audioFfIndex}' : '0:a:0?']);
    if (_isMp4Family(plan.outputPath)) {
      final textSubs = probe.subtitles.where((s) => s.isText).toList();
      for (final s in textSubs) {
        args.addAll(['-map', '0:${s.index}']);
      }
      if (textSubs.isNotEmpty) args.addAll(['-c:s', 'mov_text']);
    } else {
      args.addAll(['-map', '0:s?', '-c:s', 'copy']);
    }

    if (useHw) {
      args.addAll([
        '-c:v', hwEncoder.ffmpegName,
        '-b:v', '$bitRate', '-maxrate', '$bitRate', '-bufsize', '${bitRate * 2}',
      ]);
      if (hwEncoder == HwEncoder.nvenc) args.addAll(['-rc:v', 'vbr', '-preset', 'p4']);
    } else if (bitRate != null) {
      args.addAll([
        '-c:v', 'libx264',
        '-b:v', '$bitRate', '-minrate', '$bitRate', '-maxrate', '$bitRate',
        '-bufsize', '${bitRate * 2}', '-preset', 'medium',
      ]);
    } else {
      args.addAll(['-c:v', 'libx264', '-crf', '16', '-preset', 'slow']);
    }

    if (preserveInterlace) {
      args.addAll([
        '-flags:v', '+ildct+ilme',
        '-x264opts', probe.fieldOrder == FieldOrder.tff ? 'tff=1' : 'bff=1',
      ]);
      if (probe.frameRate != null) args.addAll(['-r', probe.frameRate!]);
      args.addAll(['-fps_mode', 'cfr']);
    }

    args.addAll(['-pix_fmt', 'yuv420p', '-c:a', 'copy', '-map_metadata', '0', plan.outputPath]);

    return ExportCommand(
      args: List.unmodifiable(args),
      usesHardware: useHw,
      bobDeinterlace: bob,
      videoFilters: List.unmodifiable(videoFilters),
    );
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/core/ffmpeg/export_command_builder_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/ffmpeg test/core/ffmpeg
git commit -m "feat(ffmpeg): build export commands with GPU, interlace and subtitle rules"
```

---

### Task 9: Nommage des sorties et renommage sûr

**Files:**
- Create: `lib/core/files/output_naming.dart`, `lib/core/files/safe_rename.dart`
- Test: `test/core/files/output_naming_test.dart`, `test/core/files/safe_rename_test.dart`
- Modify: `pubspec.yaml` (`path`)

**Interfaces:**
- Consumes: `Rotation.suffix` (tâche 6).
- Produces:
  - `bool isMp4Family(String path)` ;
  - `String exportOutputPath(String inputPath, {required bool crop, required Rotation rotation, required bool trim, required bool Function(String path) exists})`, avec les suffixes dans l'ordre `_crop`, rotation, `_trim`, l'extension conservée pour mp4/mov/m4v et `.mkv` sinon, et ` (n)` en cas de collision ;
  - `String sanitizeFileStem(String raw)` ;
  - `String? renameTarget(String oldPath, String artist, String title, {required bool Function(String path) exists})`, qui renvoie `null` si le nom ne change pas (comparaison insensible à la casse) ou s'il est vide après nettoyage.
  - Les chemins sont traités au format Windows (`p.windows`), quelle que soit la machine de test.

- [ ] **Step 1: Ajouter `path`**

Run: `flutter pub add path`

- [ ] **Step 2: Écrire les tests**

`test/core/files/output_naming_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/files/output_naming.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

void main() {
  bool none(String _) => false;

  test('mp4 family keeps its extension', () {
    expect(isMp4Family(r'C:\a\b.MP4'), isTrue);
    expect(isMp4Family(r'C:\a\b.mov'), isTrue);
    expect(isMp4Family(r'C:\a\b.m4v'), isTrue);
    expect(isMp4Family(r'C:\a\b.webm'), isFalse);
  });

  test('suffix order is crop, rotation, trim', () {
    expect(
      exportOutputPath(r'C:\v\clip.mp4', crop: true, rotation: Rotation.cw90, trim: true, exists: none),
      r'C:\v\clip_crop_rot90_trim.mp4',
    );
    expect(
      exportOutputPath(r'C:\v\clip.MOV', crop: false, rotation: Rotation.half, trim: false, exists: none),
      r'C:\v\clip_rot180.MOV',
    );
  });

  test('other containers become mkv', () {
    expect(
      exportOutputPath(r'C:\v\clip.webm', crop: false, rotation: Rotation.ccw90, trim: false, exists: none),
      r'C:\v\clip_rot270.mkv',
    );
    expect(
      exportOutputPath(r'C:\v\clip', crop: true, rotation: Rotation.none, trim: false, exists: none),
      r'C:\v\clip_crop.mkv',
    );
  });

  test('collisions get a numbered suffix', () {
    final taken = {r'C:\v\clip_trim.mkv', r'C:\v\clip_trim (1).mkv'};
    expect(
      exportOutputPath(r'C:\v\clip.avi', crop: false, rotation: Rotation.none, trim: true, exists: taken.contains),
      r'C:\v\clip_trim (2).mkv',
    );
  });
}
```

`test/core/files/safe_rename_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/files/safe_rename.dart';

void main() {
  bool none(String _) => false;

  test('sanitizeFileStem removes forbidden characters and trailing dots', () {
    expect(sanitizeFileStem(r'AC/DC: Back <In> "Black"?*|\ '), 'ACDC Back In Black');
    expect(sanitizeFileStem('Song...'), 'Song');
    expect(sanitizeFileStem('Tab\tName'), 'TabName');
  });

  test('builds Artist - Title with the original extension', () {
    expect(
      renameTarget(r'C:\m\track01.mp3', 'Sezen Aksu', 'Gülümse', exists: none),
      r'C:\m\Sezen Aksu - Gülümse.mp3',
    );
  });

  test('collisions get (1), (2)', () {
    final taken = {r'C:\m\A - B.mkv', r'C:\m\A - B (1).mkv'};
    expect(renameTarget(r'C:\m\x.mkv', 'A', 'B', exists: taken.contains), r'C:\m\A - B (2).mkv');
  });

  test('same name, ignoring case, means no rename', () {
    expect(renameTarget(r'C:\m\a - b.mp3', 'A', 'B', exists: (_) => true), isNull);
  });

  test('empty name after cleaning means no rename', () {
    expect(renameTarget(r'C:\m\x.mp3', '???', '', exists: none), isNull);
  });
}
```

- [ ] **Step 3: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/files`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 4: Écrire `lib/core/files/output_naming.dart`**

```dart
import 'package:path/path.dart' as p;

import '../geometry/rotation.dart';

final _win = p.windows;

bool isMp4Family(String path) {
  final ext = _win.extension(path).toLowerCase();
  return ext == '.mp4' || ext == '.mov' || ext == '.m4v';
}

String exportOutputPath(
  String inputPath, {
  required bool crop,
  required Rotation rotation,
  required bool trim,
  required bool Function(String path) exists,
}) {
  final dir = _win.dirname(inputPath);
  final stem = _win.basenameWithoutExtension(inputPath);
  final ext = isMp4Family(inputPath) ? _win.extension(inputPath) : '.mkv';
  final suffix = '${crop ? '_crop' : ''}${rotation.suffix}${trim ? '_trim' : ''}';
  return uniquePath(_win.join(dir, '$stem$suffix'), ext, exists);
}

/// `<base><ext>`, or `<base> (n)<ext>` with the smallest free n.
String uniquePath(String base, String ext, bool Function(String path) exists) {
  var candidate = '$base$ext';
  var n = 1;
  while (exists(candidate)) {
    candidate = '$base ($n)$ext';
    n++;
  }
  return candidate;
}
```

- [ ] **Step 5: Écrire `lib/core/files/safe_rename.dart`**

```dart
import 'package:path/path.dart' as p;

import 'output_naming.dart';

final _win = p.windows;
final _forbidden = RegExp(r'[\\/*?:"<>|\x00-\x1F]');

String sanitizeFileStem(String raw) {
  var s = raw.replaceAll(_forbidden, '').trim();
  while (s.endsWith('.') || s.endsWith(' ')) {
    s = s.substring(0, s.length - 1);
  }
  return s.replaceAll(RegExp(r' {2,}'), ' ');
}

String? renameTarget(
  String oldPath,
  String artist,
  String title, {
  required bool Function(String path) exists,
}) {
  final stem = sanitizeFileStem('$artist - $title');
  final cleanedParts = stem.split(' - ').where((part) => part.trim().isNotEmpty);
  if (stem.isEmpty || cleanedParts.isEmpty || stem == '-') return null;
  final dir = _win.dirname(oldPath);
  final ext = _win.extension(oldPath);
  final direct = _win.join(dir, '$stem$ext');
  if (direct.toLowerCase() == oldPath.toLowerCase()) return null;
  return uniquePath(_win.join(dir, stem), ext, exists);
}
```

- [ ] **Step 6: Lancer les tests**

Run: `flutter test test/core/files`
Expected: PASS. Pour `'???'` + `''`, le nom nettoyé vaut `-` : la fonction renvoie bien `null`.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/files test/core/files
git commit -m "feat(files): add export output naming and safe rename targets"
```

---

### Task 10: Format binaire des signatures Shazam

**Files:**
- Create: `lib/core/shazam/crc32.dart`, `lib/core/shazam/signature_format.dart`, `tool/gen_signature_fixtures.py`, `test/fixtures/shazam/{chord,noisy,sweep}.wav`, `test/fixtures/shazam/{chord,noisy,sweep}.uri`
- Test: `test/core/shazam/signature_format_test.dart`

**Interfaces:**
- Produces:
  - `int crc32(List<int> bytes)` (CRC-32 IEEE, comme zlib) ;
  - `enum FrequencyBand { b250_520, b520_1450, b1450_3500, b3500_5500 }` (l'index de chaque valeur est l'identifiant du format) ;
  - `class FrequencyPeak { const FrequencyPeak({required int fftPassNumber, required int peakMagnitude, required int correctedPeakFrequencyBin}); }` ;
  - `class DecodedSignature { DecodedSignature({required int sampleRateHz, required int numberSamples, required Map<FrequencyBand, List<FrequencyPeak>> peaks}); Uint8List encode(); String toDataUri(); int get sampleMs; static DecodedSignature decode(Uint8List bytes); static DecodedSignature fromDataUri(String uri); }`. Le décodage lève `FormatException` si les nombres magiques, la taille ou le CRC ne correspondent pas.
- Source du format : `shazamio-core` (MIT), `src/fingerprinting/signature_format.rs`.

- [ ] **Step 1: Écrire le générateur de références `tool/gen_signature_fixtures.py`**

```python
"""Generate the WAV probes and shazamio-core signatures the Dart port is checked against.

Run from the repository root with the project's virtualenv:
    .venv/Scripts/python tool/gen_signature_fixtures.py
Requires numpy and shazamio-core (see legacy/README.md).
"""

import asyncio
import pathlib
import wave

import numpy as np
import shazamio_core

OUT = pathlib.Path(__file__).resolve().parent.parent / "test" / "fixtures" / "shazam"
RATE = 16000
SECONDS = 8


def chord(t):
    return (
        0.25 * np.sin(2 * np.pi * 440 * t)
        + 0.2 * np.sin(2 * np.pi * 1320 * t)
        + 0.15 * np.sin(2 * np.pi * 2750 * t)
        + 0.1 * np.sin(2 * np.pi * 4400 * t)
    ) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.5 * t))


def noisy(t):
    rng = np.random.default_rng(7)
    tone = 0.3 * np.sin(2 * np.pi * 660 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t))
    return tone + 0.15 * rng.standard_normal(len(t))


def sweep(t):
    freq = 300 + (5000 - 300) * t / SECONDS
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return 0.4 * np.sin(phase)


PROBES = {"chord": chord, "noisy": noisy, "sweep": sweep}


async def main():
    OUT.mkdir(parents=True, exist_ok=True)
    recognizer = shazamio_core.Recognizer(segment_duration_seconds=10)
    t = np.arange(RATE * SECONDS) / RATE
    for name, fn in PROBES.items():
        pcm = (np.clip(fn(t), -1, 1) * 32767).astype("<i2")
        wav_path = OUT / f"{name}.wav"
        with wave.open(str(wav_path), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(RATE)
            wf.writeframes(pcm.tobytes())
        signature = await recognizer.recognize_path(str(wav_path))
        (OUT / f"{name}.uri").write_text(signature.signature.uri + "\n", encoding="ascii")
        print(name, signature.signature.samples, "ms")


asyncio.run(main())
```

- [ ] **Step 2: Générer les références**

Run: `.venv/Scripts/python tool/gen_signature_fixtures.py`
Expected: trois lignes `chord 8000 ms`, `noisy 8000 ms` et `sweep 8000 ms`, plus six fichiers dans `test/fixtures/shazam/`. Si le `.venv` n'existe plus, le recréer avec Python 3.13 en suivant `legacy/README.md` (`numpy`, `shazamio-core==1.2.0`).

- [ ] **Step 3: Écrire le test**

`test/core/shazam/signature_format_test.dart` :

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/shazam/crc32.dart';
import 'package:uhf_media/core/shazam/signature_format.dart';

void main() {
  test('crc32 matches the zlib check value', () {
    expect(crc32('123456789'.codeUnits), 0xCBF43926);
    expect(crc32(const []), 0);
  });

  test('encode then decode round-trips peaks, including a pass gap of 255+', () {
    final sig = DecodedSignature(
      sampleRateHz: 16000,
      numberSamples: 128000,
      peaks: {
        FrequencyBand.b520_1450: const [
          FrequencyPeak(fftPassNumber: 3, peakMagnitude: 9000, correctedPeakFrequencyBin: 5000),
          FrequencyPeak(fftPassNumber: 3, peakMagnitude: 8000, correctedPeakFrequencyBin: 6000),
          FrequencyPeak(fftPassNumber: 400, peakMagnitude: 7000, correctedPeakFrequencyBin: 7000),
        ],
        FrequencyBand.b250_520: const [
          FrequencyPeak(fftPassNumber: 10, peakMagnitude: 6500, correctedPeakFrequencyBin: 2000),
        ],
      },
    );
    final bytes = sig.encode();
    expect(bytes.length % 4, 0);
    final back = DecodedSignature.decode(bytes);
    expect(back.sampleRateHz, 16000);
    expect(back.numberSamples, 128000);
    expect(back.sampleMs, 8000);
    expect(back.peaks[FrequencyBand.b520_1450]!.map((p) => p.fftPassNumber), [3, 3, 400]);
    expect(back.peaks[FrequencyBand.b250_520]!.single.correctedPeakFrequencyBin, 2000);
    expect(back.encode(), bytes);
  });

  test('an empty signature encodes to the 56-byte header', () {
    final sig = DecodedSignature(sampleRateHz: 16000, numberSamples: 1000, peaks: const {});
    final bytes = sig.encode();
    expect(bytes.length, 56);
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(0, Endian.little), 0xcafe2580);
    expect(data.getUint32(28, Endian.little), 3 << 27);
    expect(data.getUint32(40, Endian.little), 1000 + 3840);
  });

  test('a corrupted payload fails the CRC check', () {
    final bytes = DecodedSignature(sampleRateHz: 16000, numberSamples: 1000, peaks: const {}).encode();
    bytes[20] ^= 0xff;
    expect(() => DecodedSignature.decode(bytes), throwsFormatException);
  });

  for (final name in ['chord', 'noisy', 'sweep']) {
    test('shazamio-core signature "$name" decodes and re-encodes byte for byte', () {
      final uri = File('test/fixtures/shazam/$name.uri').readAsStringSync().trim();
      final sig = DecodedSignature.fromDataUri(uri);
      expect(sig.sampleRateHz, 16000);
      expect(sig.peaks.values.expand((p) => p), isNotEmpty);
      expect(sig.toDataUri(), uri);
    });
  }
}
```

- [ ] **Step 4: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/shazam/signature_format_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 5: Écrire `lib/core/shazam/crc32.dart`**

```dart
final List<int> _table = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

/// CRC-32 (IEEE 802.3), identical to zlib's crc32.
int crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc = _table[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
```

- [ ] **Step 6: Écrire `lib/core/shazam/signature_format.dart`**

```dart
// Binary Shazam signature format, ported from shazamio-core
// (src/fingerprinting/signature_format.rs, MIT License).

import 'dart:convert';
import 'dart:typed_data';

import 'crc32.dart';

enum FrequencyBand { b250_520, b520_1450, b1450_3500, b3500_5500 }

class FrequencyPeak {
  const FrequencyPeak({
    required this.fftPassNumber,
    required this.peakMagnitude,
    required this.correctedPeakFrequencyBin,
  });

  final int fftPassNumber;
  final int peakMagnitude;
  final int correctedPeakFrequencyBin;
}

const _dataUriPrefix = 'data:audio/vnd.shazam.sig;base64,';
const _magic1 = 0xcafe2580;
const _magic2 = 0x94119c00;
const _sampleRateIds = {8000: 1, 11025: 2, 16000: 3, 32000: 4, 44100: 5, 48000: 6};

class DecodedSignature {
  DecodedSignature({required this.sampleRateHz, required this.numberSamples, required this.peaks});

  final int sampleRateHz;
  final int numberSamples;
  final Map<FrequencyBand, List<FrequencyPeak>> peaks;

  int get sampleMs => numberSamples * 1000 ~/ sampleRateHz;

  // sample_rate * 0.24, computed in integers to avoid float rounding.
  static int _extraSamples(int sampleRateHz) => sampleRateHz * 24 ~/ 100;

  Uint8List encode() {
    final rateId = _sampleRateIds[sampleRateHz];
    if (rateId == null) throw ArgumentError.value(sampleRateHz, 'sampleRateHz', 'unsupported');

    final out = BytesBuilder();
    void u32(int v) => out.add((ByteData(4)..setUint32(0, v & 0xFFFFFFFF, Endian.little)).buffer.asUint8List());

    u32(_magic1);
    u32(0); // crc32, patched below
    u32(0); // size minus header, patched below
    u32(_magic2);
    u32(0);
    u32(0);
    u32(0);
    u32(rateId << 27);
    u32(0);
    u32(0);
    u32(numberSamples + _extraSamples(sampleRateHz));
    u32((15 << 19) + 0x40000);
    u32(0x40000000);
    u32(0); // size minus header, patched below

    final bands = peaks.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    for (final band in bands) {
      final buf = BytesBuilder();
      var pass = 0;
      for (final peak in peaks[band]!) {
        if (peak.fftPassNumber < pass) {
          throw StateError('peaks must be sorted by fft pass number');
        }
        if (peak.fftPassNumber - pass >= 255) {
          buf.addByte(0xff);
          buf.add((ByteData(4)..setUint32(0, peak.fftPassNumber, Endian.little)).buffer.asUint8List());
          pass = peak.fftPassNumber;
        }
        buf.addByte(peak.fftPassNumber - pass);
        buf.add((ByteData(4)
              ..setUint16(0, peak.peakMagnitude, Endian.little)
              ..setUint16(2, peak.correctedPeakFrequencyBin, Endian.little))
            .buffer
            .asUint8List());
        pass = peak.fftPassNumber;
      }
      final bytes = buf.takeBytes();
      u32(0x60030040 + band.index);
      u32(bytes.length);
      out.add(bytes);
      final padding = (4 - bytes.length % 4) % 4;
      for (var i = 0; i < padding; i++) {
        out.addByte(0);
      }
    }

    final result = out.takeBytes();
    final view = ByteData.sublistView(result);
    view.setUint32(8, result.length - 48, Endian.little);
    view.setUint32(52, result.length - 48, Endian.little);
    view.setUint32(4, crc32(Uint8List.sublistView(result, 8)), Endian.little);
    return result;
  }

  String toDataUri() => '$_dataUriPrefix${base64.encode(encode())}';

  static DecodedSignature fromDataUri(String uri) {
    if (!uri.startsWith(_dataUriPrefix)) throw const FormatException('not a Shazam signature data URI');
    return decode(base64.decode(uri.substring(_dataUriPrefix.length)));
  }

  static DecodedSignature decode(Uint8List bytes) {
    if (bytes.length < 56) throw const FormatException('signature too short');
    final data = ByteData.sublistView(bytes);
    int u32(int offset) => data.getUint32(offset, Endian.little);

    if (u32(0) != _magic1 || u32(12) != _magic2) throw const FormatException('bad signature magic');
    if (u32(8) != bytes.length - 48) throw const FormatException('bad signature size');
    if (u32(4) != crc32(Uint8List.sublistView(bytes, 8))) throw const FormatException('bad signature CRC');

    final rateId = u32(28) >> 27;
    final sampleRate = _sampleRateIds.entries
        .firstWhere((e) => e.value == rateId, orElse: () => throw const FormatException('bad sample rate id'))
        .key;
    final numberSamples = u32(40) - _extraSamples(sampleRate);

    final peaks = <FrequencyBand, List<FrequencyPeak>>{};
    var offset = 56;
    while (offset + 8 <= bytes.length) {
      final bandId = u32(offset) - 0x60030040;
      final size = u32(offset + 4);
      offset += 8;
      if (bandId < 0 || bandId >= FrequencyBand.values.length || offset + size > bytes.length) {
        throw const FormatException('bad frequency band block');
      }
      final list = <FrequencyPeak>[];
      final end = offset + size;
      var pass = 0;
      var i = offset;
      while (i < end) {
        final offsetByte = bytes[i++];
        if (offsetByte == 0xff) {
          pass = data.getUint32(i, Endian.little);
          i += 4;
          continue;
        }
        pass += offsetByte;
        list.add(FrequencyPeak(
          fftPassNumber: pass,
          peakMagnitude: data.getUint16(i, Endian.little),
          correctedPeakFrequencyBin: data.getUint16(i + 2, Endian.little),
        ));
        i += 4;
      }
      peaks[FrequencyBand.values[bandId]] = list;
      offset = end + (4 - size % 4) % 4;
    }
    return DecodedSignature(sampleRateHz: sampleRate, numberSamples: numberSamples, peaks: peaks);
  }
}
```

- [ ] **Step 7: Lancer les tests**

Run: `flutter test test/core/shazam/signature_format_test.dart`
Expected: PASS, dont la ré-encodage octet par octet des trois signatures produites par `shazamio-core`.

- [ ] **Step 8: Commit**

```bash
git add lib/core/shazam/crc32.dart lib/core/shazam/signature_format.dart tool/gen_signature_fixtures.py test/fixtures/shazam test/core/shazam/signature_format_test.dart
git commit -m "feat(shazam): port the binary signature format from shazamio-core"
```

---

### Task 11: Générateur de signature Shazam

**Files:**
- Create: `lib/core/shazam/signature_generator.dart`, `lib/core/shazam/audio_level.dart`, `test/support/wav.dart`
- Modify: `pubspec.yaml` (`fftea`)
- Test: `test/core/shazam/signature_generator_test.dart`, `test/core/shazam/audio_level_test.dart`

**Interfaces:**
- Consumes: `DecodedSignature`, `FrequencyBand`, `FrequencyPeak` (tâche 10).
- Produces:
  - `abstract final class SignatureGenerator { static DecodedSignature fromPcm16kMono(Int16List samples); }`. L'entrée est en PCM 16 bits, mono, 16 kHz, telle que produite par `ffmpeg -ac 1 -ar 16000 -f s16le` (plan 3) ;
  - `bool isSilent(Int16List samples, {double threshold = 0.01})` (RMS normalisée sur 32768) ;
  - côté tests : `Int16List readPcm16Wav(String path)`.
- Source de l'algorithme : `shazamio-core` (MIT), `src/fingerprinting/algorithm.rs`. Rust calcule en `f32` et Dart en `f64` : les pics peuvent légèrement différer près des seuils. Le test compare donc les pics avec une tolérance, pas octet par octet.

- [ ] **Step 1: Ajouter `fftea`**

Run: `flutter pub add fftea`

- [ ] **Step 2: Écrire l'aide WAV `test/support/wav.dart`**

```dart
import 'dart:io';
import 'dart:typed_data';

/// Reads the samples of a 16-bit PCM WAV file.
Int16List readPcm16Wav(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      final samples = Int16List(size ~/ 2);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = data.getInt16(offset + 8 + i * 2, Endian.little);
      }
      return samples;
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw FormatException('no data chunk in $path');
}
```

- [ ] **Step 3: Écrire les tests**

`test/core/shazam/audio_level_test.dart` :

```dart
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/shazam/audio_level.dart';

void main() {
  test('digital silence and near-silence are silent', () {
    expect(isSilent(Int16List(16000)), isTrue);
    expect(isSilent(Int16List.fromList(List.filled(16000, 100))), isTrue);
  });

  test('a -10 dBFS tone is not silent', () {
    final tone = Int16List.fromList(
      List.generate(16000, (i) => (10362 * sin(2 * pi * 440 * i / 16000)).round()),
    );
    expect(isSilent(tone), isFalse);
  });

  test('empty input is silent', () {
    expect(isSilent(Int16List(0)), isTrue);
  });
}
```

`test/core/shazam/signature_generator_test.dart` :

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/shazam/signature_format.dart';
import 'package:uhf_media/core/shazam/signature_generator.dart';

import '../../support/wav.dart';

typedef _Peak = ({FrequencyBand band, int pass, int bin});

List<_Peak> _flatten(DecodedSignature s) => [
      for (final e in s.peaks.entries)
        for (final p in e.value) (band: e.key, pass: p.fftPassNumber, bin: p.correctedPeakFrequencyBin),
    ];

double _matchedShare(List<_Peak> from, List<_Peak> against) {
  if (from.isEmpty) return 1;
  var matched = 0;
  for (final a in from) {
    final hit = against.any((b) => b.band == a.band && (b.pass - a.pass).abs() <= 1 && (b.bin - a.bin).abs() <= 64);
    if (hit) matched++;
  }
  return matched / from.length;
}

void main() {
  for (final name in ['chord', 'noisy', 'sweep']) {
    test('peaks of "$name" match shazamio-core within tolerance', () {
      final pcm = readPcm16Wav('test/fixtures/shazam/$name.wav');
      final ours = SignatureGenerator.fromPcm16kMono(pcm);
      final theirs = DecodedSignature.fromDataUri(
        File('test/fixtures/shazam/$name.uri').readAsStringSync().trim(),
      );

      expect(ours.sampleRateHz, 16000);
      expect(ours.numberSamples, theirs.numberSamples);

      final a = _flatten(ours);
      final b = _flatten(theirs);
      expect(b.length, greaterThan(10), reason: 'fixture should contain peaks');
      expect(_matchedShare(a, b), greaterThanOrEqualTo(0.9), reason: 'precision ${a.length} vs ${b.length}');
      expect(_matchedShare(b, a), greaterThanOrEqualTo(0.9), reason: 'recall ${a.length} vs ${b.length}');
    });
  }

  test('peaks are sorted by pass number so the signature encodes', () {
    final pcm = readPcm16Wav('test/fixtures/shazam/chord.wav');
    final sig = SignatureGenerator.fromPcm16kMono(pcm);
    for (final list in sig.peaks.values) {
      for (var i = 1; i < list.length; i++) {
        expect(list[i].fftPassNumber, greaterThanOrEqualTo(list[i - 1].fftPassNumber));
      }
    }
    expect(() => sig.encode(), returnsNormally);
  });

  test('audio shorter than 46 blocks yields no peaks and still encodes (review focus 3)', () {
    final sig = SignatureGenerator.fromPcm16kMono(Int16List(1000));
    expect(sig.numberSamples, 1000);
    expect(sig.peaks.values.expand((p) => p), isEmpty);
    expect(sig.encode().length, 56);
  });

  test('digital silence yields no peaks', () {
    final sig = SignatureGenerator.fromPcm16kMono(Int16List(16000 * 3));
    expect(sig.peaks.values.expand((p) => p), isEmpty);
  });
}
```

- [ ] **Step 4: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/shazam/signature_generator_test.dart test/core/shazam/audio_level_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 5: Écrire `lib/core/shazam/audio_level.dart`**

```dart
import 'dart:math' as math;
import 'dart:typed_data';

/// True when the RMS level (samples normalized to -1..1) is under [threshold].
bool isSilent(Int16List samples, {double threshold = 0.01}) {
  if (samples.isEmpty) return true;
  var sum = 0.0;
  for (final s in samples) {
    final v = s / 32768.0;
    sum += v * v;
  }
  return math.sqrt(sum / samples.length) < threshold;
}
```

- [ ] **Step 6: Écrire `lib/core/shazam/signature_generator.dart`**

```dart
// Shazam fingerprinting, ported from shazamio-core
// (src/fingerprinting/algorithm.rs, MIT License).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'signature_format.dart';

abstract final class SignatureGenerator {
  static DecodedSignature fromPcm16kMono(Int16List samples) {
    final state = _State();
    final chunkCount = samples.length ~/ 128;
    for (var c = 0; c < chunkCount; c++) {
      state.doFft(samples, c * 128);
      state.doPeakSpreading();
      state.numSpreadFftsDone++;
      if (state.numSpreadFftsDone >= 46) state.doPeakRecognition();
    }
    return DecodedSignature(sampleRateHz: 16000, numberSamples: samples.length, peaks: state.peaks);
  }
}

// numpy.hanning(2050)[1:-1], the window shazamio-core tabulates.
final Float64List _hanning = Float64List.fromList(
  List.generate(2048, (i) => 0.5 - 0.5 * math.cos(2 * math.pi * (i + 1) / 2049)),
);

const _neighborOffsets = [-10, -7, -4, -3, 1, 2, 5, 8];
const _otherOffsets = [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249];

class _State {
  final Int16List ring = Int16List(2048);
  int ringIndex = 0;
  final Float64List reordered = Float64List(2048);
  final List<Float32List> fftOutputs = List.generate(256, (_) => Float32List(1025));
  int fftOutputsIndex = 0;
  final List<Float32List> spreadOutputs = List.generate(256, (_) => Float32List(1025));
  int spreadOutputsIndex = 0;
  int numSpreadFftsDone = 0;
  final FFT fft = FFT(2048);
  final Map<FrequencyBand, List<FrequencyPeak>> peaks = {};

  void doFft(Int16List samples, int start) {
    for (var i = 0; i < 128; i++) {
      ring[ringIndex + i] = samples[start + i];
    }
    ringIndex = (ringIndex + 128) & 2047;

    for (var i = 0; i < 2048; i++) {
      reordered[i] = ring[(i + ringIndex) & 2047] * _hanning[i];
    }

    final spectrum = fft.realFft(reordered);
    final out = fftOutputs[fftOutputsIndex];
    for (var i = 0; i <= 1024; i++) {
      final c = spectrum[i];
      final v = (c.x * c.x + c.y * c.y) / (1 << 17);
      out[i] = v > 1e-10 ? v : 1e-10;
    }
    fftOutputsIndex = (fftOutputsIndex + 1) & 255;
  }

  void doPeakSpreading() {
    final latest = fftOutputs[(fftOutputsIndex - 1) & 255];
    final spread = spreadOutputs[spreadOutputsIndex];
    spread.setAll(0, latest);
    for (var p = 0; p <= 1022; p++) {
      spread[p] = math.max(spread[p], math.max(spread[p + 1], spread[p + 2]));
    }
    final copy = Float32List.fromList(spread);
    for (final former in const [1, 3, 6]) {
      final target = spreadOutputs[(spreadOutputsIndex - former) & 255];
      for (var p = 0; p <= 1024; p++) {
        if (copy[p] > target[p]) target[p] = copy[p];
      }
    }
    spreadOutputsIndex = (spreadOutputsIndex + 1) & 255;
  }

  static double _magnitude(double v) => math.max(math.log(v), 1 / 64) * 1477.3 + 6144.0;

  void doPeakRecognition() {
    final fft46 = fftOutputs[(fftOutputsIndex - 46) & 255];
    final fft49 = spreadOutputs[(spreadOutputsIndex - 49) & 255];

    for (var bin = 10; bin <= 1014; bin++) {
      final v = fft46[bin];
      if (v < 1 / 64 || v < fft49[bin - 1]) continue;

      var maxNeighbor = 0.0;
      for (final o in _neighborOffsets) {
        maxNeighbor = math.max(maxNeighbor, fft49[bin + o]);
      }
      if (v <= maxNeighbor) continue;

      var maxOther = maxNeighbor;
      for (final o in _otherOffsets) {
        maxOther = math.max(maxOther, spreadOutputs[(spreadOutputsIndex + o) & 255][bin - 1]);
      }
      if (v <= maxOther) continue;

      final passNumber = numSpreadFftsDone - 46;
      final magnitude = _magnitude(v);
      final before = _magnitude(fft46[bin - 1]);
      final after = _magnitude(fft46[bin + 1]);
      final variation1 = magnitude * 2 - before - after;
      final variation2 = (after - before) * 32 / variation1;
      final correctedBin = (bin * 64 + _toI32(variation2)) & 0xFFFF;
      final frequencyHz = correctedBin * (16000 / 2 / 1024 / 64);

      final band = switch (frequencyHz.toInt()) {
        >= 250 && <= 519 => FrequencyBand.b250_520,
        >= 520 && <= 1449 => FrequencyBand.b520_1450,
        >= 1450 && <= 3499 => FrequencyBand.b1450_3500,
        >= 3500 && <= 5500 => FrequencyBand.b3500_5500,
        _ => null,
      };
      if (band == null) continue;

      (peaks[band] ??= []).add(FrequencyPeak(
        fftPassNumber: passNumber,
        peakMagnitude: magnitude.clamp(0, 65535).toInt(),
        correctedPeakFrequencyBin: correctedBin,
      ));
    }
  }

  // Rust's `f32 as i32`: truncates toward zero, saturates, NaN becomes 0.
  static int _toI32(double v) {
    if (v.isNaN) return 0;
    if (v >= 2147483647) return 2147483647;
    if (v <= -2147483648) return -2147483648;
    return v.truncate();
  }
}
```

- [ ] **Step 7: Lancer les tests**

Run: `flutter test test/core/shazam`
Expected: PASS. Si la comparaison avec `shazamio-core` descend sous 0,9, comparer d'abord le premier pic de chaque bande (bin et pass). Un écart systématique d'un bloc signale une erreur d'index de l'anneau ; un écart d'échelle sur les magnitudes signale une normalisation différente de la FFT. Corriger le port, jamais la tolérance.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/shazam test/core/shazam test/support
git commit -m "feat(shazam): port the Shazam signature generator to Dart"
```

---

### Task 12: Client Shazam

**Files:**
- Create: `lib/core/shazam/shazam_client.dart`
- Modify: `pubspec.yaml` (`http`)
- Test: `test/core/shazam/shazam_client_test.dart`

**Interfaces:**
- Consumes: `DecodedSignature.toDataUri()` et `DecodedSignature.sampleMs` (tâche 10).
- Produces:
  - `class RecognitionResult { const RecognitionResult({required String title, required String artist}); }` ;
  - `class ShazamException implements Exception { final String message; }` ;
  - `class ShazamClient { ShazamClient({http.Client? client, math.Random? random, DateTime Function()? now, String language = 'en-US', String country = 'GB', String timezone = 'Europe/Paris', Duration timeout = const Duration(seconds: 15)}); Future<RecognitionResult?> recognize(DecodedSignature signature); void close(); static RecognitionResult? parseResponse(Object? json); }`.
  - `recognize` renvoie `null` si Shazam ne trouve rien, et lève `ShazamException` en cas d'erreur réseau, de statut HTTP autre que 2xx, de JSON invalide ou de délai dépassé.
- Source du protocole : `shazamio` (MIT), `shazamio/misc.py` (`ShazamUrl.SEARCH_FROM_FILE`, `Request.headers`) et `converter.py` (`data_search`).

- [ ] **Step 1: Ajouter `http`**

Run: `flutter pub add http`

- [ ] **Step 2: Écrire le test**

```dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/shazam/signature_format.dart';

final _signature = DecodedSignature(sampleRateHz: 16000, numberSamples: 160000, peaks: const {});

ShazamClient _client(MockClientHandler handler) => ShazamClient(
      client: MockClient(handler),
      random: Random(1),
      now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
    );

void main() {
  test('sends the shazamio request shape', () async {
    late http.Request sent;
    final client = _client((request) async {
      sent = request;
      return http.Response('{"matches": []}', 200);
    });

    await client.recognize(_signature);

    expect(sent.method, 'POST');
    expect(sent.url.host, 'amp.shazam.com');
    expect(
      sent.url.path,
      matches(RegExp(r'^/discovery/v5/en-US/GB/iphone/-/tag/[0-9A-F-]{36}/[0-9A-F-]{36}$')),
    );
    expect(sent.url.queryParameters['shazamapiversion'], 'v3');
    expect(sent.url.queryParameters['sync'], 'true');
    expect(sent.headers['X-Shazam-Platform'], 'IPHONE');
    expect(sent.headers['X-Shazam-AppVersion'], '14.1.0');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(sent.headers['User-Agent'], startsWith('Dalvik/'));

    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['timezone'], 'Europe/Paris');
    expect(body['timestamp'], 1700000000000);
    expect(body['signature'], {'uri': _signature.toDataUri(), 'samplems': 10000});
    expect(body['context'], <String, dynamic>{});
    expect(body['geolocation'], <String, dynamic>{});
  });

  test('a track in the response is a result', () async {
    final client = _client((_) async => http.Response(
          jsonEncode({'track': {'title': 'Gülümse', 'subtitle': 'Sezen Aksu'}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    final result = await client.recognize(_signature);
    expect(result!.title, 'Gülümse');
    expect(result.artist, 'Sezen Aksu');
  });

  test('no track means not found', () async {
    final client = _client((_) async => http.Response('{"matches": []}', 200));
    expect(await client.recognize(_signature), isNull);
  });

  test('missing fields fall back to Unknown', () {
    final r = ShazamClient.parseResponse({'track': <String, dynamic>{}});
    expect(r!.title, 'Unknown');
    expect(r.artist, 'Unknown Artist');
  });

  test('HTTP errors and invalid JSON are ShazamException', () async {
    await expectLater(
      _client((_) async => http.Response('oops', 503)).recognize(_signature),
      throwsA(isA<ShazamException>()),
    );
    await expectLater(
      _client((_) async => http.Response('<html>', 200)).recognize(_signature),
      throwsA(isA<ShazamException>()),
    );
  });

  test('network failure is ShazamException', () async {
    final client = _client((_) async => throw http.ClientException('offline'));
    await expectLater(client.recognize(_signature), throwsA(isA<ShazamException>()));
  });
}
```

- [ ] **Step 3: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/shazam/shazam_client_test.dart`
Expected: FAIL, fichier introuvable.

- [ ] **Step 4: Écrire `lib/core/shazam/shazam_client.dart`**

```dart
// Shazam recognition request, following shazamio (MIT License):
// shazamio/misc.py (ShazamUrl.SEARCH_FROM_FILE, Request.headers) and
// shazamio/converter.py (data_search). The endpoint is unofficial.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'signature_format.dart';

class RecognitionResult {
  const RecognitionResult({required this.title, required this.artist});
  final String title;
  final String artist;
}

class ShazamException implements Exception {
  const ShazamException(this.message);
  final String message;

  @override
  String toString() => 'ShazamException: $message';
}

class ShazamClient {
  ShazamClient({
    http.Client? client,
    math.Random? random,
    DateTime Function()? now,
    this.language = 'en-US',
    this.country = 'GB',
    this.timezone = 'Europe/Paris',
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _random = random ?? math.Random.secure(),
        _now = now ?? DateTime.now;

  final http.Client _client;
  final math.Random _random;
  final DateTime Function() _now;
  final String language;
  final String country;
  final String timezone;
  final Duration timeout;

  static const _userAgents = [
    'Dalvik/2.1.0 (Linux; U; Android 5.0.2; VS980 4G Build/LRX22G)',
    'Dalvik/1.6.0 (Linux; U; Android 4.4.2; SM-T210 Build/KOT49H)',
    'Dalvik/2.1.0 (Linux; U; Android 5.1.1; SM-P905V Build/LMY47X)',
    'Dalvik/1.6.0 (Linux; U; Android 4.4.4; Vodafone Smart Tab 4G Build/KTU84P)',
  ];

  Future<RecognitionResult?> recognize(DecodedSignature signature) async {
    final uri = Uri.parse(
      'https://amp.shazam.com/discovery/v5/$language/$country/iphone/-/tag/${_uuid()}/${_uuid()}'
      '?sync=true&webv3=true&sampling=true&connected=&shazamapiversion=v3&sharehub=true'
      '&hubv5minorversion=v5.1&hidelb=true&video=v3',
    );
    final body = jsonEncode({
      'timezone': timezone,
      'signature': {'uri': signature.toDataUri(), 'samplems': signature.sampleMs},
      'timestamp': _now().millisecondsSinceEpoch,
      'context': <String, Object?>{},
      'geolocation': <String, Object?>{},
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'X-Shazam-Platform': 'IPHONE',
              'X-Shazam-AppVersion': '14.1.0',
              'Accept': '*/*',
              'Accept-Language': language,
              'Content-Type': 'application/json',
              'User-Agent': _userAgents[_random.nextInt(_userAgents.length)],
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ShazamException('request timed out');
    } on http.ClientException catch (e) {
      throw ShazamException(e.message);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ShazamException('HTTP ${response.statusCode}');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ShazamException('invalid JSON response');
    }
    return parseResponse(json);
  }

  static RecognitionResult? parseResponse(Object? json) {
    if (json is! Map<String, dynamic>) throw const ShazamException('unexpected response');
    final track = json['track'];
    if (track is! Map<String, dynamic>) return null;
    final title = track['title'];
    final artist = track['subtitle'];
    return RecognitionResult(
      title: title is String && title.isNotEmpty ? title : 'Unknown',
      artist: artist is String && artist.isNotEmpty ? artist : 'Unknown Artist',
    );
  }

  void close() => _client.close();

  String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final hex = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/core/shazam/shazam_client_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/shazam/shazam_client.dart test/core/shazam/shazam_client_test.dart
git commit -m "feat(shazam): add Shazam recognition client"
```

---

### Task 13: Réglages et reprise de lecture

**Files:**
- Create: `lib/core/settings/json_file.dart`, `lib/core/settings/app_settings.dart`, `lib/core/settings/settings_store.dart`, `lib/core/settings/resume_store.dart`
- Test: `test/core/settings/settings_store_test.dart`, `test/core/settings/resume_store_test.dart`

**Interfaces:**
- Produces:
  - `Future<Map<String, dynamic>?> readJsonObject(File file)` : `null` si le fichier est absent ; un fichier corrompu est renommé `<nom>.bak` et la fonction renvoie `null`. `Future<void> writeJsonAtomic(File file, Map<String, dynamic> json)` écrit dans `<nom>.tmp`, puis renomme.
  - `class AppSettings`, avec `double volume` (0–100, 80 par défaut), `bool muted`, `int subtitleScale` (50–300, 100), `int subtitlePos` (0–100, 100), `double? windowX`, `double? windowY`, `double windowWidth` (1100), `double windowHeight` (780), `bool maximized`, `bool alwaysOnTop`, `String language` (`'system' | 'en' | 'fr' | 'tr'`), `bool autoRename`, `String? lastOpenDir`, ainsi que `copyWith`, `toJson` et `factory AppSettings.fromJson(Map<String, dynamic>)`. Les valeurs invalides retombent sur la valeur par défaut.
  - `class SettingsStore { SettingsStore(Directory dir); Future<AppSettings> load(); Future<void> save(AppSettings s); }` (fichier `settings.json`).
  - `class ResumeStore { ResumeStore(Directory dir, {DateTime Function()? now, int maxEntries = 500}); Future<void> load(); Duration? resumePositionFor(String path, Duration duration); void record(String path, Duration position); void clear(String path); void migrate(String oldPath, String newPath); Future<void> flush(); int get length; }` (fichier `resume.json`). Clé : chemin Windows normalisé en minuscules.
  - Règle de reprise : la position est utilisée seulement si `position > 10 s` et `position < duration - 30 s`.

- [ ] **Step 1: Écrire les tests**

`test/core/settings/settings_store_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('uhf_settings_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('missing file gives defaults', () async {
    final s = await SettingsStore(dir).load();
    expect(s.volume, 80);
    expect(s.subtitleScale, 100);
    expect(s.subtitlePos, 100);
    expect(s.windowWidth, 1100);
    expect(s.windowHeight, 780);
    expect(s.language, 'system');
    expect(s.autoRename, isFalse);
  });

  test('save then load round-trips', () async {
    final store = SettingsStore(dir);
    final saved = AppSettings.defaults().copyWith(
      volume: 35,
      muted: true,
      subtitleScale: 140,
      subtitlePos: 92,
      windowX: 10,
      windowY: 20,
      maximized: true,
      alwaysOnTop: true,
      language: 'tr',
      autoRename: true,
      lastOpenDir: r'C:\Vidéos',
    );
    await store.save(saved);
    final loaded = await store.load();
    expect(loaded.toJson(), saved.toJson());
    expect(File('${dir.path}/settings.json.tmp').existsSync(), isFalse);
  });

  test('corrupted file gives defaults and is kept as .bak (review focus 5)', () async {
    File('${dir.path}/settings.json').writeAsStringSync('{not json');
    final s = await SettingsStore(dir).load();
    expect(s.volume, 80);
    expect(File('${dir.path}/settings.json.bak').existsSync(), isTrue);
    expect(File('${dir.path}/settings.json').existsSync(), isFalse);
  });

  test('wrong types and out-of-range values fall back per field (review focus 5)', () async {
    File('${dir.path}/settings.json').writeAsStringSync(
      '{"volume": "loud", "subtitleScale": 9000, "subtitlePos": 50, "language": "de", "muted": 1}',
    );
    final s = await SettingsStore(dir).load();
    expect(s.volume, 80);
    expect(s.subtitleScale, 100);
    expect(s.subtitlePos, 50);
    expect(s.language, 'system');
    expect(s.muted, isFalse);
  });
}
```

`test/core/settings/resume_store_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/resume_store.dart';

void main() {
  late Directory dir;
  var clock = DateTime(2026, 10, 1);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_resume_');
    clock = DateTime(2026, 10, 1);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ResumeStore store({int max = 500}) => ResumeStore(dir, now: () => clock, maxEntries: max);
  const movie = Duration(hours: 2);

  test('applies only between 10 s from the start and 30 s from the end', () async {
    final s = store()..record(r'C:\v\a.mkv', const Duration(minutes: 41));
    expect(s.resumePositionFor(r'C:\v\a.mkv', movie), const Duration(minutes: 41));

    s.record(r'C:\v\a.mkv', const Duration(seconds: 10));
    expect(s.resumePositionFor(r'C:\v\a.mkv', movie), isNull);

    s.record(r'C:\v\a.mkv', movie - const Duration(seconds: 30));
    expect(s.resumePositionFor(r'C:\v\a.mkv', movie), isNull);
  });

  test('keys ignore case and separators style', () async {
    final s = store()..record(r'C:\Videos\A.MKV', const Duration(minutes: 5));
    expect(s.resumePositionFor('c:/videos/a.mkv', movie), const Duration(minutes: 5));
  });

  test('persists across instances', () async {
    final a = store()..record(r'C:\v\a.mkv', const Duration(minutes: 3));
    await a.flush();
    final b = store();
    await b.load();
    expect(b.resumePositionFor(r'C:\v\a.mkv', movie), const Duration(minutes: 3));
  });

  test('clear and migrate', () async {
    final s = store()..record(r'C:\v\old.mkv', const Duration(minutes: 3));
    s.migrate(r'C:\v\old.mkv', r'C:\v\Artist - Title.mkv');
    expect(s.resumePositionFor(r'C:\v\old.mkv', movie), isNull);
    expect(s.resumePositionFor(r'C:\v\Artist - Title.mkv', movie), const Duration(minutes: 3));
    s.clear(r'C:\v\Artist - Title.mkv');
    expect(s.resumePositionFor(r'C:\v\Artist - Title.mkv', movie), isNull);
  });

  test('keeps only the most recent entries', () async {
    final s = store(max: 3);
    for (var i = 0; i < 5; i++) {
      clock = clock.add(const Duration(minutes: 1));
      s.record('C:\\v\\$i.mkv', const Duration(minutes: 5));
    }
    expect(s.length, 3);
    expect(s.resumePositionFor(r'C:\v\0.mkv', movie), isNull);
    expect(s.resumePositionFor(r'C:\v\4.mkv', movie), const Duration(minutes: 5));
  });

  test('corrupted file starts empty (review focus 5)', () async {
    File('${dir.path}/resume.json').writeAsStringSync('garbage');
    final s = store();
    await s.load();
    expect(s.length, 0);
    expect(File('${dir.path}/resume.json.bak').existsSync(), isTrue);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/settings`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/core/settings/json_file.dart`**

```dart
import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>?> readJsonObject(File file) async {
  if (!await file.exists()) return null;
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Fall through: keep the unreadable file aside and start fresh.
  }
  final backup = File('${file.path}.bak');
  if (await backup.exists()) await backup.delete();
  await file.rename(backup.path);
  return null;
}

Future<void> writeJsonAtomic(File file, Map<String, dynamic> json) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(json), flush: true);
  await tmp.rename(file.path);
}
```

- [ ] **Step 4: Écrire `lib/core/settings/app_settings.dart`**

```dart
class AppSettings {
  const AppSettings({
    required this.volume,
    required this.muted,
    required this.subtitleScale,
    required this.subtitlePos,
    required this.windowX,
    required this.windowY,
    required this.windowWidth,
    required this.windowHeight,
    required this.maximized,
    required this.alwaysOnTop,
    required this.language,
    required this.autoRename,
    required this.lastOpenDir,
  });

  factory AppSettings.defaults() => const AppSettings(
        volume: 80,
        muted: false,
        subtitleScale: 100,
        subtitlePos: 100,
        windowX: null,
        windowY: null,
        windowWidth: 1100,
        windowHeight: 780,
        maximized: false,
        alwaysOnTop: false,
        language: 'system',
        autoRename: false,
        lastOpenDir: null,
      );

  static const languages = {'system', 'en', 'fr', 'tr'};

  final double volume;
  final bool muted;
  final int subtitleScale;
  final int subtitlePos;
  final double? windowX;
  final double? windowY;
  final double windowWidth;
  final double windowHeight;
  final bool maximized;
  final bool alwaysOnTop;
  final String language;
  final bool autoRename;
  final String? lastOpenDir;

  AppSettings copyWith({
    double? volume,
    bool? muted,
    int? subtitleScale,
    int? subtitlePos,
    double? windowX,
    double? windowY,
    double? windowWidth,
    double? windowHeight,
    bool? maximized,
    bool? alwaysOnTop,
    String? language,
    bool? autoRename,
    String? lastOpenDir,
  }) =>
      AppSettings(
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
        subtitleScale: subtitleScale ?? this.subtitleScale,
        subtitlePos: subtitlePos ?? this.subtitlePos,
        windowX: windowX ?? this.windowX,
        windowY: windowY ?? this.windowY,
        windowWidth: windowWidth ?? this.windowWidth,
        windowHeight: windowHeight ?? this.windowHeight,
        maximized: maximized ?? this.maximized,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
        language: language ?? this.language,
        autoRename: autoRename ?? this.autoRename,
        lastOpenDir: lastOpenDir ?? this.lastOpenDir,
      );

  Map<String, dynamic> toJson() => {
        'volume': volume,
        'muted': muted,
        'subtitleScale': subtitleScale,
        'subtitlePos': subtitlePos,
        'windowX': windowX,
        'windowY': windowY,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'maximized': maximized,
        'alwaysOnTop': alwaysOnTop,
        'language': language,
        'autoRename': autoRename,
        'lastOpenDir': lastOpenDir,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final d = AppSettings.defaults();

    double readNum(String key, double fallback, {double? min, double? max}) {
      final v = json[key];
      if (v is! num) return fallback;
      final x = v.toDouble();
      if ((min != null && x < min) || (max != null && x > max)) return fallback;
      return x;
    }

    double? readOptionalNum(String key) => json[key] is num ? (json[key] as num).toDouble() : null;

    int readInt(String key, int fallback, int min, int max) {
      final v = json[key];
      return (v is int && v >= min && v <= max) ? v : fallback;
    }

    bool readBool(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;

    final lang = json['language'];
    final dir = json['lastOpenDir'];
    return AppSettings(
      volume: readNum('volume', d.volume, min: 0, max: 100),
      muted: readBool('muted', d.muted),
      subtitleScale: readInt('subtitleScale', d.subtitleScale, 50, 300),
      subtitlePos: readInt('subtitlePos', d.subtitlePos, 0, 100),
      windowX: readOptionalNum('windowX'),
      windowY: readOptionalNum('windowY'),
      windowWidth: readNum('windowWidth', d.windowWidth, min: 320),
      windowHeight: readNum('windowHeight', d.windowHeight, min: 240),
      maximized: readBool('maximized', d.maximized),
      alwaysOnTop: readBool('alwaysOnTop', d.alwaysOnTop),
      language: lang is String && languages.contains(lang) ? lang : d.language,
      autoRename: readBool('autoRename', d.autoRename),
      lastOpenDir: dir is String && dir.isNotEmpty ? dir : null,
    );
  }
}
```

- [ ] **Step 5: Écrire `lib/core/settings/settings_store.dart`**

```dart
import 'dart:io';

import 'app_settings.dart';
import 'json_file.dart';

class SettingsStore {
  SettingsStore(Directory dir) : _file = File('${dir.path}${Platform.pathSeparator}settings.json');

  final File _file;

  Future<AppSettings> load() async {
    final json = await readJsonObject(_file);
    return json == null ? AppSettings.defaults() : AppSettings.fromJson(json);
  }

  Future<void> save(AppSettings settings) => writeJsonAtomic(_file, settings.toJson());
}
```

- [ ] **Step 6: Écrire `lib/core/settings/resume_store.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'json_file.dart';

class _Entry {
  _Entry(this.positionMs, this.updatedMs);
  int positionMs;
  int updatedMs;
}

class ResumeStore {
  ResumeStore(Directory dir, {DateTime Function()? now, this.maxEntries = 500})
      : _file = File('${dir.path}${Platform.pathSeparator}resume.json'),
        _now = now ?? DateTime.now;

  static const _minFromStart = Duration(seconds: 10);
  static const _minFromEnd = Duration(seconds: 30);

  final File _file;
  final DateTime Function() _now;
  final int maxEntries;
  final Map<String, _Entry> _entries = {};

  int get length => _entries.length;

  static String _key(String path) => p.windows.normalize(path).toLowerCase();

  Future<void> load() async {
    _entries.clear();
    final json = await readJsonObject(_file);
    final entries = json?['entries'];
    if (entries is! Map<String, dynamic>) return;
    entries.forEach((key, value) {
      if (value is Map<String, dynamic> && value['pos_ms'] is int && value['updated'] is int) {
        _entries[key] = _Entry(value['pos_ms'] as int, value['updated'] as int);
      }
    });
    _trim();
  }

  Duration? resumePositionFor(String path, Duration duration) {
    final entry = _entries[_key(path)];
    if (entry == null) return null;
    final position = Duration(milliseconds: entry.positionMs);
    if (position <= _minFromStart || position >= duration - _minFromEnd) return null;
    return position;
  }

  void record(String path, Duration position) {
    _entries[_key(path)] = _Entry(position.inMilliseconds, _now().millisecondsSinceEpoch);
    _trim();
  }

  void clear(String path) => _entries.remove(_key(path));

  void migrate(String oldPath, String newPath) {
    final entry = _entries.remove(_key(oldPath));
    if (entry != null) _entries[_key(newPath)] = entry;
  }

  Future<void> flush() => writeJsonAtomic(_file, {
        'version': 1,
        'entries': {
          for (final e in _entries.entries) e.key: {'pos_ms': e.value.positionMs, 'updated': e.value.updatedMs},
        },
      });

  void _trim() {
    if (_entries.length <= maxEntries) return;
    final sorted = _entries.entries.toList()..sort((a, b) => a.value.updatedMs.compareTo(b.value.updatedMs));
    for (final e in sorted.take(_entries.length - maxEntries)) {
      _entries.remove(e.key);
    }
  }
}
```

- [ ] **Step 7: Lancer les tests**

Run: `flutter test test/core/settings`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/core/settings test/core/settings
git commit -m "feat(settings): add settings and resume stores with atomic JSON files"
```

---

### Task 14: Intégration continue et vérification finale

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: l'ensemble des tests des tâches 1 à 13.

- [ ] **Step 1: Écrire `.github/workflows/ci.yml`**

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.4'
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

- [ ] **Step 2: Vérification complète en local**

Run: `flutter analyze` puis `flutter test`
Expected: `No issues found!` et `All tests passed!`

- [ ] **Step 3: Vérifier qu'aucun module pur n'importe Flutter ni `dart:io`**

Run: `git grep -nE "package:flutter|dart:io" -- lib/core/geometry lib/core/ffmpeg lib/core/files lib/core/util lib/core/shazam`
Expected: aucune ligne.

- [ ] **Step 4: Build Windows de contrôle**

Run: `flutter build windows --release`
Expected: `√ Built build\windows\x64\runner\Release\uhf_media.exe`. Le lancer : l'écran d'accueil UHF s'affiche.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run analyze and tests on Windows"
```

---

## Plans suivants (écrits après l'exécution de ce plan)

- **Plan 2 — Lecteur et fenêtre** : `media_kit` (`PlayerService`, `parseTrackList`), `window_manager` (barre de titre, plein écran, toujours au premier plan), instance unique, glisser-déposer, `file_picker`, mode Lecture (contrôles superposés, timeline, volume, pistes, sous-titres et leurs réglages, mono G/D), menu ⋯, messages, raccourcis de lecture, capture, reprise de lecture et réglages branchés, désentrelacement de lecture, fin de fichier.
- **Plan 3 — Studio et musique** : mode Studio (panneau, timeline de découpe, rotation, cadre de recadrage et ratios, dimensions), `ProbeService`, `ExportRunner` (progression, annulation, repli CPU), « Afficher dans l'Explorateur », extraction audio et `Recognizer`, carte de résultat, renommage pendant la lecture (fermer, renommer, rouvrir), raccourcis Studio.
- **Plan 4 — Distribution** : `tool/fetch_ffmpeg.ps1` (BtbN figé + SHA-256), copie CMake dans le bundle, métadonnées de l'exe et icône, installeur Inno Setup (installation par utilisateur, ProgID, OpenWithProgids), README définitif, `THIRD_PARTY_NOTICES.md`, recette manuelle.
