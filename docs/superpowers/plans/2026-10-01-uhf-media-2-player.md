# UHF Media — Plan 2 : lecteur et fenêtre

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre l'application utilisable comme lecteur : moteur vidéo media_kit, fenêtre sans barre native (déplacement, agrandissement, plein écran, toujours au premier plan), instance unique, ouverture par dialogue, glisser-déposer et ligne de commande, mode Lecture complet (contrôles superposés auto-masqués, timeline, volume, pistes audio, sous-titres et leurs réglages, mono G/D, menu ⋯), capture, reprise de lecture, réglages mémorisés, raccourcis clavier de lecture.

**Architecture:** Le moteur vidéo est caché derrière l'interface `MediaEngine` (`lib/core/media`), implémentée par `MediaKitEngine` et simulée par `FakeMediaEngine` dans les tests. La fenêtre est cachée derrière `WindowHost` (`lib/features/shell`), implémentée par `WindowManagerHost`. L'état vit dans des `ChangeNotifier` : `PlayerController`, `ShellController`, `SettingsController`, `ToastController`. Les contrôleurs n'emploient pas de textes traduits : `PlayerController` émet des `PlayerEvent` que `AppShell` traduit en messages. Les accès système (ffprobe, PowerShell, explorateur) vivent dans `lib/core/system`. `main.dart` assemble tout.

**Tech Stack:** Flutter 3.41.4, `media_kit` 1.2.6 + `media_kit_video` 2.0.1 + `media_kit_libs_video` 1.0.7, `window_manager` 0.5.2, `windows_single_instance` 1.2.0, `desktop_drop` 0.8.4, `file_picker` 13.1.0, `material_symbols_icons` 4.2960.0, `path`.

**Spec:** `docs/superpowers/specs/2026-10-01-uhf-media-flutter-design.md` (sections 3 « Lecture », 4.3, 4.4, 5, 6, 7, 8, 9).

## Global Constraints

- Tout ce qui figure dans « Global Constraints » du plan 1 s'applique (couleurs, polices, rayons 2–3 px, ni ombre ni dégradé ni emoji, tr/fr/en, Conventional Commits sans `Co-Authored-By`).
- `lib/core/{geometry,ffmpeg,files,shazam,util,media}` n'importent ni `package:flutter` ni `dart:io`, sauf `lib/core/media/media_kit_engine.dart` (adaptateur natif). Les accès système vont dans `lib/core/system/`.
- Icônes : `Symbols.<nom>_sharp` de `material_symbols_icons`, `weight: 300`, 18 px ; boutons de fenêtre dessinés (traits 1 px).
- Durées : contrôles masqués après 2,5 s de lecture sans mouvement ; messages 4 s (8 s avec action) ; animations 120–160 ms.
- Raccourcis (spec §7) livrés ici : `Espace`, `←`/`→` (±3 s), `Shift+←`/`Shift+→` (image), `↑`/`↓` (volume ±5), `M`, `F`, `Échap`, `Ctrl+O`, `S`, `Ctrl+T`. `E`, `Ctrl+I`, `I`, `O`, `R`, `C`, `Ctrl+E` arrivent au plan 3.
- Les contrôles ne prennent jamais le focus clavier : les raccourcis s'appliquent toujours à la fenêtre.
- Sous-titres désactivés à chaque ouverture ; mono G/D remis à stéréo à chaque ouverture ; en fin de fichier : retour au début, en pause.
- Réglages dans `%APPDATA%\UHF Media\` (`settings.json`, `resume.json`).
- Dossier de capture : Bureau Windows réel (OneDrive compris), nom `UHF_AAAAMMJJ_HHMMSS.png`.

## Review Focus

1. **Ouvrir un 2ᵉ fichier pendant la lecture du 1ᵉʳ** : la position du 1ᵉʳ est enregistrée, mono et sous-titres sont réinitialisés, la reprise du 2ᵉ ne s'applique qu'une fois (pas à chaque nouvel événement de durée). Test dans la tâche 7.
2. **Glisser plusieurs fichiers, ou un sous-titre sans vidéo ouverte** : le premier fichier média s'ouvre ; un sous-titre seul sans vidéo est ignoré sans erreur. Test dans la tâche 13.
3. **Raccourcis après un clic sur un contrôle** (bouton, curseur de volume) : `Espace` et les flèches continuent d'agir sur la lecture. Test dans la tâche 13.
4. **Durée inconnue ou nulle** (flux audio, fichier en cours de chargement) : la timeline ne divise pas par zéro, les sauts restent bornés à `[0, durée]`. Tests dans les tâches 7 et 10.
5. **2ᵉ instance lancée avec un chemin inexistant ou une option** (`--flag`) : la fenêtre passe au premier plan et rien ne s'ouvre. Test dans la tâche 14.

---

## File Structure

| Fichier | Responsabilité |
|---|---|
| `lib/core/media/track_info.dart` | `TrackInfo`, `TrackType`, `parseTrackList` (JSON `track-list` de mpv) |
| `lib/core/media/pan_mode.dart` | `PanMode` (valeur `af` de mpv) |
| `lib/core/media/media_engine.dart` | Interface `MediaEngine` |
| `lib/core/media/media_kit_engine.dart` | Adaptateur media_kit (`Player`, `NativePlayer`, `VideoController`) |
| `lib/core/files/media_files.dart` | Extensions acceptées, `isSubtitleFile`, `screenshotFileName` |
| `lib/core/system/process_runner.dart` | `ProcessRunner`, `defaultProcessRunner` |
| `lib/core/system/ffmpeg_locator.dart` | Trouve `ffmpeg.exe` / `ffprobe.exe` (dossier de l'exe, puis `PATH`) |
| `lib/core/system/probe_service.dart` | Lance ffprobe et renvoie `ProbeResult` |
| `lib/core/system/known_folders.dart` | Bureau Windows, `revealInExplorer` |
| `lib/core/system/launch_args.dart` | `firstExistingFile` |
| `lib/l10n/app_{en,fr,tr}.arb` | Textes du lecteur |
| `lib/ui/theme.dart` | + thèmes menus, curseurs, dialogues, boutons texte |
| `lib/ui/uhf_icon_button.dart` | Bouton icône sans focus |
| `lib/ui/uhf_menu.dart` | `UhfMenuEntry`, `UhfMenuButton` |
| `lib/ui/toast.dart` | `ToastController`, `ToastHost` |
| `lib/features/settings/settings_controller.dart` | `SettingsController` (sauvegarde différée, langue) |
| `lib/features/player/player_controller.dart` | `PlayerController`, `PlayerEvent` |
| `lib/features/player/player_settings_binding.dart` | Synchronise volume / sous-titres → réglages |
| `lib/features/shell/window_host.dart` | Interface `WindowHost`, `WindowEvent` |
| `lib/features/shell/window_manager_host.dart` | Adaptateur `window_manager` |
| `lib/features/shell/shell_controller.dart` | `ShellController` |
| `lib/features/shell/title_bar.dart` | Barre de titre 30 px |
| `lib/features/player/timeline.dart` | Timeline (clic, glissement, survol) |
| `lib/features/player/volume_control.dart` | Bouton muet + curseur |
| `lib/features/player/player_menus.dart` | Entrées des menus audio, sous-titres, ⋯ |
| `lib/features/player/subtitle_settings_dialog.dart` | Taille et position en direct |
| `lib/features/player/controls_visibility.dart` | Masquage automatique |
| `lib/features/player/controls_overlay.dart` | Barre de contrôles superposée |
| `lib/features/shell/app_shell.dart` | Écran principal : scène, dépôt, raccourcis, messages |
| `lib/features/shell/second_instance.dart` | File d'attente des arguments d'une 2ᵉ instance |
| `lib/app/uhf_root.dart` | Racine : langue depuis les réglages + `AppShell` |
| `lib/main.dart` | Démarrage |
| `windows/runner/flutter_window.cpp` | Fenêtre affichée par `window_manager`, pas par le runner |
| `test/support/fake_media_engine.dart`, `fake_window_host.dart`, `harness.dart` | Doublures de test |

---

### Task 1: Dépendances, pistes et mode mono

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/media/track_info.dart`, `lib/core/media/pan_mode.dart`
- Test: `test/core/media/track_info_test.dart`

**Interfaces:**
- Produces:
  - `enum TrackType { video, audio, subtitle }`
  - `class TrackInfo { const TrackInfo({required TrackType type, required int id, int? ffIndex, bool selected = false, String? title, String? language, String? codec, bool external = false}); String? get label; }`
  - `List<TrackInfo> parseTrackList(String json)` — tolérant : JSON invalide ou non-liste → `[]` ; entrées sans `type` connu ou sans `id` entier ignorées.
  - `enum PanMode { stereo, left, right }` avec `String audioFilter` (`''`, `'lavfi=[pan=stereo|c0=c0|c1=c0]'`, `'lavfi=[pan=stereo|c0=c1|c1=c1]'`).

- [ ] **Step 1: Ajouter les dépendances**

```powershell
flutter pub add media_kit media_kit_video media_kit_libs_video window_manager windows_single_instance desktop_drop file_picker material_symbols_icons
```

Expected: `Changed N dependencies!` ; `pubspec.yaml` contient `media_kit: ^1.2.6`, `media_kit_video: ^2.0.1`, `media_kit_libs_video: ^1.0.7`, `window_manager: ^0.5.2`, `windows_single_instance: ^1.2.0`, `desktop_drop: ^0.8.4`, `file_picker: ^13.1.0`, `material_symbols_icons: ^4.2960.0`.

- [ ] **Step 2: Écrire le test**

`test/core/media/track_info_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';

const _json = '''
[
  {"id": 1, "type": "video", "ff-index": 0, "selected": true, "codec": "h264"},
  {"id": 1, "type": "audio", "ff-index": 1, "selected": true, "lang": "fre", "title": "VF 5.1"},
  {"id": 2, "type": "audio", "ff-index": 2, "lang": "eng"},
  {"id": 1, "type": "sub", "ff-index": 3, "lang": "eng"},
  {"id": 2, "type": "sub", "external": true, "title": "film.srt"},
  {"id": 3, "type": "sub"},
  {"type": "audio"},
  {"id": "x", "type": "audio"},
  {"id": 9, "type": "attachment"}
]
''';

void main() {
  test('parses video, audio and subtitle tracks', () {
    final tracks = parseTrackList(_json);
    expect(tracks.length, 6);
    expect(tracks.where((t) => t.type == TrackType.audio).map((t) => t.id), [1, 2]);
    final video = tracks.first;
    expect(video.type, TrackType.video);
    expect(video.ffIndex, 0);
    expect(video.selected, isTrue);
    expect(video.codec, 'h264');
  });

  test('external subtitles have no ff-index', () {
    final ext = parseTrackList(_json).firstWhere((t) => t.external);
    expect(ext.type, TrackType.subtitle);
    expect(ext.ffIndex, isNull);
  });

  test('label joins title and upper-case language', () {
    final tracks = parseTrackList(_json);
    expect(tracks[1].label, 'VF 5.1 · FRE');
    expect(tracks[2].label, 'ENG');
    expect(tracks[4].label, 'film.srt');
    expect(tracks[5].label, isNull);
  });

  test('invalid JSON and non-lists give an empty list', () {
    expect(parseTrackList('not json'), isEmpty);
    expect(parseTrackList('{"id": 1}'), isEmpty);
    expect(parseTrackList(''), isEmpty);
  });

  test('pan modes map to mpv audio filters', () {
    expect(PanMode.stereo.audioFilter, '');
    expect(PanMode.left.audioFilter, 'lavfi=[pan=stereo|c0=c0|c1=c0]');
    expect(PanMode.right.audioFilter, 'lavfi=[pan=stereo|c0=c1|c1=c1]');
  });
}
```

- [ ] **Step 3: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/media/track_info_test.dart`
Expected: FAIL, `track_info.dart` introuvable.

- [ ] **Step 4: Écrire `lib/core/media/track_info.dart`**

```dart
import 'dart:convert';

enum TrackType { video, audio, subtitle }

class TrackInfo {
  const TrackInfo({
    required this.type,
    required this.id,
    this.ffIndex,
    this.selected = false,
    this.title,
    this.language,
    this.codec,
    this.external = false,
  });

  final TrackType type;

  /// mpv track id (`aid` / `sid` value).
  final int id;

  /// Stream index in the container, usable as ffmpeg `-map 0:<ffIndex>`.
  final int? ffIndex;
  final bool selected;
  final String? title;
  final String? language;
  final String? codec;
  final bool external;

  /// "Commentary · ENG", "ENG", or null when mpv knows neither.
  String? get label {
    final parts = [
      if (title != null && title!.isNotEmpty) title!,
      if (language != null && language!.isNotEmpty) language!.toUpperCase(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Parses mpv's `track-list` property, read as a JSON string.
List<TrackInfo> parseTrackList(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (root is! List) return const [];

  final tracks = <TrackInfo>[];
  for (final item in root.whereType<Map<String, dynamic>>()) {
    final type = switch (item['type']) {
      'video' => TrackType.video,
      'audio' => TrackType.audio,
      'sub' => TrackType.subtitle,
      _ => null,
    };
    final id = item['id'];
    if (type == null || id is! int) continue;
    String? text(String key) => item[key] is String ? item[key] as String : null;
    final ff = item['ff-index'];
    tracks.add(TrackInfo(
      type: type,
      id: id,
      ffIndex: ff is int ? ff : null,
      selected: item['selected'] == true,
      title: text('title'),
      language: text('lang'),
      codec: text('codec'),
      external: item['external'] == true,
    ));
  }
  return tracks;
}
```

- [ ] **Step 5: Écrire `lib/core/media/pan_mode.dart`**

```dart
enum PanMode {
  stereo(''),
  left('lavfi=[pan=stereo|c0=c0|c1=c0]'),
  right('lavfi=[pan=stereo|c0=c1|c1=c1]');

  const PanMode(this.audioFilter);

  /// Value of mpv's `af` property. `pan` is a libavfilter filter, so mpv
  /// needs the `lavfi=[...]` wrapper.
  final String audioFilter;
}
```

- [ ] **Step 6: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/media test/core/media
git commit -m "feat(media): add player dependencies, track list parsing and pan modes"
```

---

### Task 2: Interface du moteur et adaptateur media_kit

**Files:**
- Create: `lib/core/media/media_engine.dart`, `lib/core/media/media_kit_engine.dart`, `test/support/fake_media_engine.dart`
- Test: `test/core/media/fake_media_engine_test.dart`

**Interfaces:**
- Consumes: `TrackInfo`, `parseTrackList`, `PanMode` (tâche 1), `IntSize`, `Rotation` (plan 1).
- Produces:
  - `abstract interface class MediaEngine` : flux `position`, `duration` (`Duration`), `playing`, `completed` (`bool`), `videoSize` (`IntSize`), `tracksChanged` (`void`), `errors` (`String`) ; méthodes `open(String path)`, `play()`, `pause()`, `seek(Duration)`, `frameStep({required bool forward})`, `setVolume(double)`, `setMuted(bool)`, `readTracks() → Future<List<TrackInfo>>`, `selectAudio(int id)`, `selectSubtitle(int? id)` (`null` = désactivés), `addSubtitle(String path)`, `setSubtitleScale(int percent)`, `setSubtitlePosition(int position)`, `setPan(PanMode)`, `setRotation(Rotation)`, `setDeinterlace(bool)`, `screenshotTo(String path)`, `close()`, `dispose()`. Toutes les méthodes renvoient `Future<void>` sauf `readTracks`.
  - `class MediaKitEngine implements MediaEngine { MediaKitEngine(); final Player player; late final VideoController controller; }`.
  - Test : `class FakeMediaEngine implements MediaEngine` avec `final List<String> calls`, `List<TrackInfo> tracks`, `void emitPosition(Duration)`, `emitDuration`, `emitPlaying`, `emitCompleted`, `emitVideoSize`, `emitTracksChanged()`, `emitError(String)`.
- L'adaptateur natif n'est pas testable sans libmpv : il est vérifié par `flutter analyze`, le build, et la recette manuelle de la tâche 15. Le test de cette tâche vérifie la doublure, qui sert de contrat aux tâches suivantes.

- [ ] **Step 1: Écrire le test de la doublure**

`test/core/media/fake_media_engine_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/media_engine.dart';
import 'package:uhf_media/core/media/pan_mode.dart';

import '../../support/fake_media_engine.dart';

void main() {
  test('fake engine records calls in mpv terms', () async {
    final MediaEngine engine = FakeMediaEngine();
    await engine.open(r'C:\v\a.mkv');
    await engine.selectSubtitle(null);
    await engine.selectAudio(2);
    await engine.setPan(PanMode.left);
    await engine.setRotation(Rotation.cw90);
    await engine.setSubtitleScale(140);
    expect((engine as FakeMediaEngine).calls, [
      r'open C:\v\a.mkv',
      'sid no',
      'aid 2',
      'af lavfi=[pan=stereo|c0=c0|c1=c0]',
      'video-rotate 90',
      'sub-scale 140',
    ]);
  });

  test('fake engine streams deliver emitted values', () async {
    final engine = FakeMediaEngine();
    final seen = <Duration>[];
    engine.position.listen(seen.add);
    engine.emitPosition(const Duration(seconds: 3));
    await Future<void>.delayed(Duration.zero);
    expect(seen, [const Duration(seconds: 3)]);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/core/media/fake_media_engine_test.dart`
Expected: FAIL, `media_engine.dart` introuvable.

- [ ] **Step 3: Écrire `lib/core/media/media_engine.dart`**

```dart
import '../geometry/geometry.dart';
import '../geometry/rotation.dart';
import 'pan_mode.dart';
import 'track_info.dart';

/// Playback engine seen by the app. Implemented over libmpv by
/// MediaKitEngine; every call maps to one mpv property or command.
abstract interface class MediaEngine {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<bool> get completed;
  Stream<IntSize> get videoSize;
  Stream<void> get tracksChanged;
  Stream<String> get errors;

  Future<void> open(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> frameStep({required bool forward});
  Future<void> setVolume(double volume);
  Future<void> setMuted(bool muted);
  Future<List<TrackInfo>> readTracks();
  Future<void> selectAudio(int id);

  /// null turns subtitles off.
  Future<void> selectSubtitle(int? id);
  Future<void> addSubtitle(String path);
  Future<void> setSubtitleScale(int percent);
  Future<void> setSubtitlePosition(int position);
  Future<void> setPan(PanMode mode);
  Future<void> setRotation(Rotation rotation);
  Future<void> setDeinterlace(bool enabled);

  /// PNG with subtitles burnt in, written by mpv.
  Future<void> screenshotTo(String path);
  Future<void> close();
  Future<void> dispose();
}
```

- [ ] **Step 4: Écrire la doublure `test/support/fake_media_engine.dart`**

```dart
import 'dart:async';

import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/media_engine.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';

class FakeMediaEngine implements MediaEngine {
  final calls = <String>[];
  List<TrackInfo> tracks = const [];
  bool throwOnOpen = false;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _videoSize = StreamController<IntSize>.broadcast();
  final _tracksChanged = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();

  void emitPosition(Duration d) => _position.add(d);
  void emitDuration(Duration d) => _duration.add(d);
  void emitPlaying(bool v) => _playing.add(v);
  void emitCompleted(bool v) => _completed.add(v);
  void emitVideoSize(IntSize s) => _videoSize.add(s);
  void emitTracksChanged() => _tracksChanged.add(null);
  void emitError(String e) => _errors.add(e);

  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<IntSize> get videoSize => _videoSize.stream;
  @override
  Stream<void> get tracksChanged => _tracksChanged.stream;
  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<void> open(String path) async {
    calls.add('open $path');
    if (throwOnOpen) throw Exception('cannot open');
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration position) async => calls.add('seek ${position.inMilliseconds}');
  @override
  Future<void> frameStep({required bool forward}) async =>
      calls.add(forward ? 'frame-step' : 'frame-back-step');
  @override
  Future<void> setVolume(double volume) async => calls.add('volume ${volume.round()}');
  @override
  Future<void> setMuted(bool muted) async => calls.add('mute ${muted ? 'yes' : 'no'}');
  @override
  Future<List<TrackInfo>> readTracks() async => tracks;
  @override
  Future<void> selectAudio(int id) async => calls.add('aid $id');
  @override
  Future<void> selectSubtitle(int? id) async => calls.add('sid ${id ?? 'no'}');
  @override
  Future<void> addSubtitle(String path) async => calls.add('sub-add $path');
  @override
  Future<void> setSubtitleScale(int percent) async => calls.add('sub-scale $percent');
  @override
  Future<void> setSubtitlePosition(int position) async => calls.add('sub-pos $position');
  @override
  Future<void> setPan(PanMode mode) async => calls.add('af ${mode.audioFilter}');
  @override
  Future<void> setRotation(Rotation rotation) async => calls.add('video-rotate ${rotation.degrees}');
  @override
  Future<void> setDeinterlace(bool enabled) async => calls.add('deinterlace ${enabled ? 'yes' : 'no'}');
  @override
  Future<void> screenshotTo(String path) async => calls.add('screenshot $path');
  @override
  Future<void> close() async => calls.add('stop');
  @override
  Future<void> dispose() async => calls.add('dispose');
}
```

- [ ] **Step 5: Écrire l'adaptateur `lib/core/media/media_kit_engine.dart`**

```dart
import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../geometry/geometry.dart';
import '../geometry/rotation.dart';
import 'media_engine.dart';
import 'pan_mode.dart';
import 'track_info.dart';

class MediaKitEngine implements MediaEngine {
  MediaKitEngine()
      : player = Player(
          configuration: const PlayerConfiguration(
            title: 'UHF Media',
            // mpv renders subtitles itself: sub-scale, sub-pos and
            // screenshots with subtitles depend on it.
            libass: true,
          ),
        ) {
    controller = VideoController(player);
    unawaited(_native.setProperty('keep-open', 'yes'));
    _subscriptions
      ..add(player.stream.width.listen((_) => _emitSize()))
      ..add(player.stream.height.listen((_) => _emitSize()));
  }

  final Player player;
  late final VideoController controller;
  final _videoSize = StreamController<IntSize>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  NativePlayer get _native => player.platform! as NativePlayer;

  void _emitSize() {
    final w = player.state.width;
    final h = player.state.height;
    if (w != null && h != null && w > 0 && h > 0) _videoSize.add(IntSize(w, h));
  }

  @override
  Stream<Duration> get position => player.stream.position;
  @override
  Stream<Duration> get duration => player.stream.duration;
  @override
  Stream<bool> get playing => player.stream.playing;
  @override
  Stream<bool> get completed => player.stream.completed;
  @override
  Stream<IntSize> get videoSize => _videoSize.stream;
  @override
  Stream<void> get tracksChanged => player.stream.tracks.map((_) {});
  @override
  Stream<String> get errors => player.stream.error;

  @override
  Future<void> open(String path) async {
    await player.open(Media(path), play: true);
    await _native.setProperty('sid', 'no');
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> frameStep({required bool forward}) =>
      _native.command([forward ? 'frame-step' : 'frame-back-step']);
  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);
  @override
  Future<void> setMuted(bool muted) => _native.setProperty('mute', muted ? 'yes' : 'no');
  @override
  Future<List<TrackInfo>> readTracks() async => parseTrackList(await _native.getProperty('track-list'));
  @override
  Future<void> selectAudio(int id) => _native.setProperty('aid', '$id');
  @override
  Future<void> selectSubtitle(int? id) => _native.setProperty('sid', id == null ? 'no' : '$id');
  @override
  Future<void> addSubtitle(String path) => _native.command(['sub-add', path, 'select']);
  @override
  Future<void> setSubtitleScale(int percent) => _native.setProperty('sub-scale', '${percent / 100}');
  @override
  Future<void> setSubtitlePosition(int position) => _native.setProperty('sub-pos', '$position');
  @override
  Future<void> setPan(PanMode mode) => _native.setProperty('af', mode.audioFilter);
  @override
  Future<void> setRotation(Rotation rotation) => _native.setProperty('video-rotate', '${rotation.degrees}');
  @override
  Future<void> setDeinterlace(bool enabled) => _native.setProperty('deinterlace', enabled ? 'yes' : 'no');
  @override
  Future<void> screenshotTo(String path) => _native.command(['screenshot-to-file', path, 'subtitles']);
  @override
  Future<void> close() => player.stop();

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _videoSize.close();
    await player.dispose();
  }
}
```

- [ ] **Step 6: Lancer les tests et l'analyse**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 7: Vérifier que l'adaptateur compile en natif**

Run: `flutter build windows --debug`
Expected: `√ Built build\windows\x64\runner\Debug\uhf_media.exe`. Le premier build télécharge libmpv (media_kit_libs_windows_video) : il faut une connexion Internet.

- [ ] **Step 8: Commit**

```bash
git add lib/core/media test/core/media test/support/fake_media_engine.dart
git commit -m "feat(media): add MediaEngine interface with media_kit adapter"
```

---

### Task 3: Accès système (ffprobe, Bureau, arguments)

**Files:**
- Create: `lib/core/files/media_files.dart`, `lib/core/system/process_runner.dart`, `lib/core/system/ffmpeg_locator.dart`, `lib/core/system/probe_service.dart`, `lib/core/system/known_folders.dart`, `lib/core/system/launch_args.dart`
- Test: `test/core/files/media_files_test.dart`, `test/core/system/system_test.dart`

**Interfaces:**
- Consumes: `ProbeResult.parse` (plan 1).
- Produces:
  - `const List<String> videoExtensions`, `audioExtensions`, `subtitleExtensions` (sans point) ; `List<String> get mediaExtensions` ; `bool isSubtitleFile(String path)` ; `bool isMediaFile(String path)` ; `String screenshotFileName(DateTime t)`.
  - `typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);` et `Future<ProcessResult> defaultProcessRunner(String, List<String>)` (UTF-8).
  - `class FfmpegLocator { FfmpegLocator({required String executableDir, required String pathVariable, bool Function(String path)? fileExists}); factory FfmpegLocator.forCurrentProcess(); String? locate(String tool); }` (`tool` = `'ffmpeg'` ou `'ffprobe'`).
  - `class ProbeService { ProbeService(String? ffprobePath, {ProcessRunner? run}); bool get available; Future<ProbeResult?> probe(String path); }` — `null` si ffprobe est absent, échoue ou renvoie un JSON invalide.
  - `class KnownFolders { KnownFolders({ProcessRunner? run, Map<String, String>? environment}); Future<String> desktop(); }` et `Future<void> revealInExplorer(String path)`.
  - `String? firstExistingFile(List<String> args, {bool Function(String path)? exists})` — ignore les arguments commençant par `-`.

- [ ] **Step 1: Écrire les tests**

`test/core/files/media_files_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/files/media_files.dart';

void main() {
  test('subtitle files are recognised by extension, any case', () {
    expect(isSubtitleFile(r'C:\v\film.SRT'), isTrue);
    expect(isSubtitleFile(r'C:\v\film.ass'), isTrue);
    expect(isSubtitleFile(r'C:\v\film.vtt'), isTrue);
    expect(isSubtitleFile(r'C:\v\film.mkv'), isFalse);
  });

  test('media files cover video and audio', () {
    expect(isMediaFile(r'C:\v\clip.MKV'), isTrue);
    expect(isMediaFile(r'C:\m\song.flac'), isTrue);
    expect(isMediaFile(r'C:\v\notes.txt'), isFalse);
    expect(mediaExtensions, containsAll(['mp4', 'webm', 'mp3', 'opus']));
  });

  test('screenshot names are timestamped', () {
    expect(screenshotFileName(DateTime(2026, 10, 1, 9, 5, 7)), 'UHF_20261001_090507.png');
  });
}
```

`test/core/system/system_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/system/ffmpeg_locator.dart';
import 'package:uhf_media/core/system/known_folders.dart';
import 'package:uhf_media/core/system/launch_args.dart';
import 'package:uhf_media/core/system/probe_service.dart';

void main() {
  group('FfmpegLocator', () {
    test('prefers the executable folder', () {
      final locator = FfmpegLocator(
        executableDir: r'C:\App',
        pathVariable: r'C:\Tools',
        fileExists: (p) => p == r'C:\App\ffprobe.exe' || p == r'C:\Tools\ffprobe.exe',
      );
      expect(locator.locate('ffprobe'), r'C:\App\ffprobe.exe');
    });

    test('falls back to PATH, ignoring quotes and empty entries', () {
      final locator = FfmpegLocator(
        executableDir: r'C:\App',
        pathVariable: r';"C:\Program Files\ff\bin";C:\Tools',
        fileExists: (p) => p == r'C:\Program Files\ff\bin\ffmpeg.exe',
      );
      expect(locator.locate('ffmpeg'), r'C:\Program Files\ff\bin\ffmpeg.exe');
    });

    test('returns null when missing', () {
      final locator = FfmpegLocator(executableDir: r'C:\App', pathVariable: '', fileExists: (_) => false);
      expect(locator.locate('ffmpeg'), isNull);
    });
  });

  group('ProbeService', () {
    test('runs ffprobe with JSON output and parses it', () async {
      late List<String> seenArgs;
      final probe = ProbeService(r'C:\App\ffprobe.exe', run: (exe, args) async {
        seenArgs = args;
        return ProcessResult(1, 0, '{"streams":[{"index":0,"codec_type":"video","field_order":"tt"}],"format":{}}', '');
      });
      final result = await probe.probe(r'C:\v\a b.ts');
      expect(seenArgs, ['-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', r'C:\v\a b.ts']);
      expect(result!.isInterlaced, isTrue);
    });

    test('missing ffprobe, failure or bad JSON give null', () async {
      expect(await ProbeService(null).probe('x'), isNull);
      expect(ProbeService(null).available, isFalse);
      final failing = ProbeService('ffprobe', run: (_, __) async => ProcessResult(1, 1, '', 'boom'));
      expect(await failing.probe('x'), isNull);
      final garbage = ProbeService('ffprobe', run: (_, __) async => ProcessResult(1, 0, 'garbage', ''));
      expect(await garbage.probe('x'), isNull);
      final missing = ProbeService('ffprobe', run: (_, __) async => throw const ProcessException('ffprobe', []));
      expect(await missing.probe('x'), isNull);
    });
  });

  group('KnownFolders', () {
    test('desktop comes from PowerShell and is cached', () async {
      var calls = 0;
      final folders = KnownFolders(run: (exe, args) async {
        calls++;
        return ProcessResult(1, 0, 'D:\\OneDrive\\Bureau\r\n', '');
      });
      expect(await folders.desktop(), r'D:\OneDrive\Bureau');
      expect(await folders.desktop(), r'D:\OneDrive\Bureau');
      expect(calls, 1);
    });

    test('falls back to USERPROFILE\\Desktop', () async {
      final folders = KnownFolders(
        run: (_, __) async => throw const ProcessException('powershell', []),
        environment: {'USERPROFILE': r'C:\Users\me'},
      );
      expect(await folders.desktop(), r'C:\Users\me\Desktop');
    });
  });

  test('firstExistingFile skips flags and missing paths', () {
    final existing = {r'C:\v\b.mkv'};
    expect(
      firstExistingFile(['--flag', r'C:\v\a.mkv', r'C:\v\b.mkv'], exists: existing.contains),
      r'C:\v\b.mkv',
    );
    expect(firstExistingFile(['--flag'], exists: existing.contains), isNull);
    expect(firstExistingFile(const [], exists: existing.contains), isNull);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/core/files/media_files_test.dart test/core/system`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/core/files/media_files.dart`**

```dart
import 'package:path/path.dart' as p;

const videoExtensions = ['mp4', 'mkv', 'mov', 'avi', 'm4v', 'webm', 'ts', 'mts', 'm2ts', 'wmv', 'flv'];
const audioExtensions = ['mp3', 'flac', 'm4a', 'wav', 'ogg', 'opus'];
const subtitleExtensions = ['srt', 'ass', 'ssa', 'vtt'];

List<String> get mediaExtensions => const [...videoExtensions, ...audioExtensions];

String _ext(String path) {
  final e = p.windows.extension(path).toLowerCase();
  return e.isEmpty ? '' : e.substring(1);
}

bool isSubtitleFile(String path) => subtitleExtensions.contains(_ext(path));

bool isMediaFile(String path) => mediaExtensions.contains(_ext(path));

String screenshotFileName(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'UHF_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}.png';
}
```

- [ ] **Step 4: Écrire `lib/core/system/process_runner.dart`**

```dart
import 'dart:convert';
import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

Future<ProcessResult> defaultProcessRunner(String executable, List<String> arguments) =>
    Process.run(executable, arguments, stdoutEncoding: utf8, stderrEncoding: utf8);
```

- [ ] **Step 5: Écrire `lib/core/system/ffmpeg_locator.dart`**

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

class FfmpegLocator {
  FfmpegLocator({
    required this.executableDir,
    required this.pathVariable,
    bool Function(String path)? fileExists,
  }) : _exists = fileExists ?? ((path) => File(path).existsSync());

  factory FfmpegLocator.forCurrentProcess() => FfmpegLocator(
        executableDir: p.dirname(Platform.resolvedExecutable),
        pathVariable: Platform.environment['PATH'] ?? '',
      );

  final String executableDir;
  final String pathVariable;
  final bool Function(String path) _exists;

  /// `tool` is "ffmpeg" or "ffprobe". Looks next to the app first, then in PATH.
  String? locate(String tool) {
    final exe = '$tool.exe';
    final local = p.windows.join(executableDir, exe);
    if (_exists(local)) return local;
    for (final raw in pathVariable.split(';')) {
      final dir = raw.replaceAll('"', '').trim();
      if (dir.isEmpty) continue;
      final candidate = p.windows.join(dir, exe);
      if (_exists(candidate)) return candidate;
    }
    return null;
  }
}
```

- [ ] **Step 6: Écrire `lib/core/system/probe_service.dart`**

```dart
import 'dart:io';

import '../ffmpeg/probe_result.dart';
import 'process_runner.dart';

class ProbeService {
  ProbeService(this._ffprobe, {ProcessRunner? run}) : _run = run ?? defaultProcessRunner;

  final String? _ffprobe;
  final ProcessRunner _run;

  bool get available => _ffprobe != null;

  Future<ProbeResult?> probe(String path) async {
    final exe = _ffprobe;
    if (exe == null) return null;
    try {
      final result = await _run(exe, ['-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', path]);
      if (result.exitCode != 0) return null;
      return ProbeResult.parse(result.stdout as String);
    } on ProcessException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
```

- [ ] **Step 7: Écrire `lib/core/system/known_folders.dart` et `launch_args.dart`**

`known_folders.dart` :

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'process_runner.dart';

class KnownFolders {
  KnownFolders({ProcessRunner? run, Map<String, String>? environment})
      : _run = run ?? defaultProcessRunner,
        _env = environment ?? Platform.environment;

  final ProcessRunner _run;
  final Map<String, String> _env;
  String? _desktop;

  /// The real Desktop folder (follows OneDrive redirection), cached.
  Future<String> desktop() async {
    final cached = _desktop;
    if (cached != null) return cached;
    try {
      final r = await _run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "[Environment]::GetFolderPath('Desktop')",
      ]);
      final out = (r.stdout as String).trim();
      if (r.exitCode == 0 && out.isNotEmpty) return _desktop = out;
    } on ProcessException {
      // Fall back below.
    }
    return _desktop = p.windows.join(_env['USERPROFILE'] ?? '', 'Desktop');
  }
}

/// Opens Explorer with [path] selected.
Future<void> revealInExplorer(String path) async {
  await Process.start('explorer.exe', ['/select,$path']);
}
```

`launch_args.dart` :

```dart
import 'dart:io';

/// First command-line argument that names an existing file; flags are skipped.
String? firstExistingFile(List<String> args, {bool Function(String path)? exists}) {
  final test = exists ?? ((path) => File(path).existsSync());
  for (final arg in args) {
    if (arg.startsWith('-')) continue;
    if (test(arg)) return arg;
  }
  return null;
}
```

- [ ] **Step 8: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/core/files/media_files.dart lib/core/system test/core/files/media_files_test.dart test/core/system
git commit -m "feat(system): locate ffmpeg, probe media, resolve the desktop and launch args"
```

---

### Task 4: Textes du lecteur (tr, fr, en)

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_tr.arb`
- Test: `test/l10n/player_strings_test.dart`

**Interfaces:**
- Produces (getters de `AppLocalizations`) : `tooltipOpen`, `tooltipPin`, `tooltipMinimize`, `tooltipMaximize`, `tooltipRestore`, `tooltipClose`, `tooltipPlay`, `tooltipPause`, `tooltipMute`, `tooltipUnmute`, `tooltipAudioTrack`, `tooltipSubtitles`, `tooltipMore`, `tooltipFullscreen`, `tooltipExitFullscreen`, `subtitlesOff`, `trackNumber(int number)`, `menuScreenshot`, `menuMonoLeft`, `menuMonoRight`, `menuSubtitleSettings`, `menuLanguage`, `languageSystem`, `subtitleSize`, `subtitlePosition`, `actionCancel`, `actionApply`, `actionRestart`, `actionShow`, `toastResumed(String time)`, `toastScreenshotSaved`, `toastOpenFailed`, `dialogOpenTitle`.

- [ ] **Step 1: Écrire le test**

`test/l10n/player_strings_test.dart` :

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
      Text(l.tooltipPlay),
      Text(l.trackNumber(3)),
      Text(l.toastResumed('00:41:12')),
      Text(l.menuMonoLeft),
    ]);
  }
}

void main() {
  const expected = {
    'en': ['Play (Space)', 'Track 3', 'Resumed at 00:41:12', 'Mono from left channel'],
    'fr': ['Lecture (Espace)', 'Piste 3', 'Reprise à 00:41:12', 'Mono depuis le canal gauche'],
    'tr': ['Oynat (Boşluk)', 'Parça 3', '00:41:12 konumundan devam ediliyor', 'Sol kanaldan mono'],
  };

  for (final entry in expected.entries) {
    testWidgets('player strings in ${entry.key}', (tester) async {
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

Run: `flutter test test/l10n/player_strings_test.dart`
Expected: FAIL, getters `tooltipPlay`, `trackNumber`… inexistants.

- [ ] **Step 3: Remplacer `lib/l10n/app_en.arb`**

```json
{
  "@@locale": "en",
  "appTitle": "UHF Media",
  "idleHint": "Drop a video here · Ctrl+O",
  "@idleHint": { "description": "Hint under the UHF logo when no file is open." },
  "tooltipOpen": "Open (Ctrl+O)",
  "tooltipPin": "Always on top (Ctrl+T)",
  "tooltipMinimize": "Minimize",
  "tooltipMaximize": "Maximize",
  "tooltipRestore": "Restore",
  "tooltipClose": "Close",
  "tooltipPlay": "Play (Space)",
  "tooltipPause": "Pause (Space)",
  "tooltipMute": "Mute (M)",
  "tooltipUnmute": "Unmute (M)",
  "tooltipAudioTrack": "Audio track",
  "tooltipSubtitles": "Subtitles",
  "tooltipMore": "More",
  "tooltipFullscreen": "Fullscreen (F)",
  "tooltipExitFullscreen": "Exit fullscreen (Esc)",
  "subtitlesOff": "Off",
  "trackNumber": "Track {number}",
  "@trackNumber": { "placeholders": { "number": { "type": "int" } } },
  "menuScreenshot": "Screenshot",
  "menuMonoLeft": "Mono from left channel",
  "menuMonoRight": "Mono from right channel",
  "menuSubtitleSettings": "Subtitle settings…",
  "menuLanguage": "Language",
  "languageSystem": "System",
  "subtitleSize": "Size",
  "subtitlePosition": "Position",
  "actionCancel": "Cancel",
  "actionApply": "Apply",
  "actionRestart": "Restart",
  "actionShow": "Show",
  "toastResumed": "Resumed at {time}",
  "@toastResumed": { "placeholders": { "time": { "type": "String" } } },
  "toastScreenshotSaved": "Screenshot saved",
  "toastOpenFailed": "Couldn't open this file",
  "dialogOpenTitle": "Open a video"
}
```

- [ ] **Step 4: Remplacer `lib/l10n/app_fr.arb`**

```json
{
  "@@locale": "fr",
  "appTitle": "UHF Media",
  "idleHint": "Glisse une vidéo ici · Ctrl+O",
  "tooltipOpen": "Ouvrir (Ctrl+O)",
  "tooltipPin": "Toujours au premier plan (Ctrl+T)",
  "tooltipMinimize": "Réduire",
  "tooltipMaximize": "Agrandir",
  "tooltipRestore": "Restaurer",
  "tooltipClose": "Fermer",
  "tooltipPlay": "Lecture (Espace)",
  "tooltipPause": "Pause (Espace)",
  "tooltipMute": "Couper le son (M)",
  "tooltipUnmute": "Rétablir le son (M)",
  "tooltipAudioTrack": "Piste audio",
  "tooltipSubtitles": "Sous-titres",
  "tooltipMore": "Plus",
  "tooltipFullscreen": "Plein écran (F)",
  "tooltipExitFullscreen": "Quitter le plein écran (Échap)",
  "subtitlesOff": "Désactivés",
  "trackNumber": "Piste {number}",
  "menuScreenshot": "Capture d'écran",
  "menuMonoLeft": "Mono depuis le canal gauche",
  "menuMonoRight": "Mono depuis le canal droit",
  "menuSubtitleSettings": "Réglages des sous-titres…",
  "menuLanguage": "Langue",
  "languageSystem": "Système",
  "subtitleSize": "Taille",
  "subtitlePosition": "Position",
  "actionCancel": "Annuler",
  "actionApply": "Appliquer",
  "actionRestart": "Recommencer",
  "actionShow": "Afficher",
  "toastResumed": "Reprise à {time}",
  "toastScreenshotSaved": "Capture enregistrée",
  "toastOpenFailed": "Impossible d'ouvrir ce fichier",
  "dialogOpenTitle": "Ouvrir une vidéo"
}
```

- [ ] **Step 5: Remplacer `lib/l10n/app_tr.arb`**

```json
{
  "@@locale": "tr",
  "appTitle": "UHF Media",
  "idleHint": "Bir videoyu buraya sürükleyin · Ctrl+O",
  "tooltipOpen": "Aç (Ctrl+O)",
  "tooltipPin": "Her zaman üstte (Ctrl+T)",
  "tooltipMinimize": "Küçült",
  "tooltipMaximize": "Büyüt",
  "tooltipRestore": "Eski boyuta getir",
  "tooltipClose": "Kapat",
  "tooltipPlay": "Oynat (Boşluk)",
  "tooltipPause": "Duraklat (Boşluk)",
  "tooltipMute": "Sesi kapat (M)",
  "tooltipUnmute": "Sesi aç (M)",
  "tooltipAudioTrack": "Ses kanalı",
  "tooltipSubtitles": "Altyazı",
  "tooltipMore": "Diğer",
  "tooltipFullscreen": "Tam ekran (F)",
  "tooltipExitFullscreen": "Tam ekrandan çık (Esc)",
  "subtitlesOff": "Kapalı",
  "trackNumber": "Parça {number}",
  "menuScreenshot": "Ekran görüntüsü",
  "menuMonoLeft": "Sol kanaldan mono",
  "menuMonoRight": "Sağ kanaldan mono",
  "menuSubtitleSettings": "Altyazı ayarları…",
  "menuLanguage": "Dil",
  "languageSystem": "Sistem",
  "subtitleSize": "Boyut",
  "subtitlePosition": "Konum",
  "actionCancel": "İptal",
  "actionApply": "Uygula",
  "actionRestart": "Baştan başlat",
  "actionShow": "Göster",
  "toastResumed": "{time} konumundan devam ediliyor",
  "toastScreenshotSaved": "Ekran görüntüsü kaydedildi",
  "toastOpenFailed": "Bu dosya açılamadı",
  "dialogOpenTitle": "Video aç"
}
```

- [ ] **Step 6: Générer et lancer les tests**

Run: `flutter gen-l10n` puis `flutter test`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/l10n test/l10n
git commit -m "feat(l10n): add player strings in Turkish, French and English"
```

---

### Task 5: Composants d'interface (bouton icône, menu, messages)

**Files:**
- Modify: `lib/ui/theme.dart`
- Create: `lib/ui/uhf_icon_button.dart`, `lib/ui/uhf_menu.dart`, `lib/ui/toast.dart`, `test/support/harness.dart`
- Test: `test/ui/components_test.dart`

**Interfaces:**
- Consumes: `UhfColors`, `UhfText`, `UhfRadii`, `UhfDurations`, `buildUhfTheme`, `UhfApp`.
- Produces:
  - `class UhfIconButton extends StatefulWidget { const UhfIconButton({super.key, required IconData icon, required String tooltip, required VoidCallback? onPressed, bool active = false, double size = 32, double iconSize = 18}); }` — ne prend jamais le focus.
  - `class UhfMenuEntry { const UhfMenuEntry({required String label, VoidCallback? onSelected, bool? checked, String? shortcut, List<UhfMenuEntry>? children}); }` ; `class UhfMenuButton extends StatelessWidget { const UhfMenuButton({super.key, required IconData icon, required String tooltip, required List<UhfMenuEntry> entries, ValueChanged<bool>? onOpenChanged, bool active = false}); }`.
  - `class ToastMessage { final String text; final String? actionLabel; final VoidCallback? onAction; }` ; `class ToastController extends ChangeNotifier { ToastMessage? get current; void show(String text, {String? actionLabel, VoidCallback? onAction}); void dismiss(); }` ; `class ToastHost extends StatelessWidget { const ToastHost({super.key, required ToastController controller, double bottom = 96}); }` (à placer dans un `Stack`).
  - Test : `Widget harness(Widget child, {Locale locale = const Locale('en')})`.

- [ ] **Step 1: Écrire l'aide de test `test/support/harness.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:uhf_media/app/uhf_app.dart';

/// Wraps [child] in the real app shell (theme, localizations, overlay).
Widget harness(Widget child, {Locale locale = const Locale('en')}) => UhfApp(locale: locale, home: child);
```

- [ ] **Step 2: Écrire le test**

`test/ui/components_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uhf_media/ui/theme.dart';
import 'package:uhf_media/ui/toast.dart';
import 'package:uhf_media/ui/tokens.dart';
import 'package:uhf_media/ui/uhf_icon_button.dart';
import 'package:uhf_media/ui/uhf_menu.dart';

import '../support/harness.dart';

void main() {
  testWidgets('icon button taps, shows its tooltip and never takes focus', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(Center(
      child: UhfIconButton(icon: Symbols.play_arrow_sharp, tooltip: 'Play', onPressed: () => taps++),
    )));
    await tester.tap(find.byType(UhfIconButton));
    expect(taps, 1);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<UhfIconButton>()));
  });

  testWidgets('active icon button uses the signal colour', (tester) async {
    await tester.pumpWidget(harness(Center(
      child: UhfIconButton(icon: Symbols.push_pin_sharp, tooltip: 'Pin', onPressed: () {}, active: true),
    )));
    expect(tester.widget<Icon>(find.byType(Icon)).color, UhfColors.signal);
  });

  testWidgets('menu opens, shows a check mark and runs the selected entry', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(Center(
      child: UhfMenuButton(
        icon: Symbols.subtitles_sharp,
        tooltip: 'Subtitles',
        entries: [
          UhfMenuEntry(label: 'Off', checked: true, onSelected: () => picked = 'off'),
          UhfMenuEntry(label: 'ENG', checked: false, onSelected: () => picked = 'eng'),
        ],
      ),
    )));
    await tester.tap(find.byType(UhfIconButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Symbols.check_sharp), findsOneWidget);
    await tester.tap(find.text('ENG'));
    await tester.pumpAndSettle();
    expect(picked, 'eng');
    expect(find.text('Off'), findsNothing);
  });

  testWidgets('toast shows, runs its action and hides after its delay', (tester) async {
    final toasts = ToastController();
    var restarted = false;
    await tester.pumpWidget(harness(Stack(children: [ToastHost(controller: toasts)])));

    toasts.show('Resumed at 00:41:12', actionLabel: 'Restart', onAction: () => restarted = true);
    await tester.pump();
    expect(find.text('Resumed at 00:41:12'), findsOneWidget);
    await tester.tap(find.text('Restart'));
    await tester.pump(UhfDurations.base);
    expect(restarted, isTrue);
    expect(toasts.current, isNull);

    toasts.show('Screenshot saved');
    await tester.pump();
    await tester.pump(UhfDurations.toast);
    await tester.pumpAndSettle();
    expect(find.text('Screenshot saved'), findsNothing);
  });

  test('theme styles menus and sliders flat', () {
    final theme = buildUhfTheme();
    expect(theme.menuTheme.style!.backgroundColor!.resolve({}), UhfColors.raised);
    expect(theme.menuTheme.style!.elevation!.resolve({}), 0);
    expect(theme.sliderTheme.trackHeight, 2);
  });
}
```

- [ ] **Step 3: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/ui/components_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 4: Compléter `lib/ui/theme.dart`**

Dans `ThemeData(...)` de `buildUhfTheme`, ajouter après `dividerColor: UhfColors.line,` :

```dart
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(UhfColors.raised),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UhfRadii.md),
          side: const BorderSide(color: UhfColors.line),
        )),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(UhfText.body),
        foregroundColor: const WidgetStatePropertyAll(UhfColors.text),
        overlayColor: WidgetStatePropertyAll(UhfColors.text.withValues(alpha: 0.06)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
        iconColor: const WidgetStatePropertyAll(UhfColors.text),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 2,
      activeTrackColor: UhfColors.text,
      inactiveTrackColor: UhfColors.line,
      thumbColor: UhfColors.text,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5, elevation: 0, pressedElevation: 0),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: UhfColors.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UhfRadii.md),
        side: const BorderSide(color: UhfColors.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: UhfColors.text,
        textStyle: UhfText.label,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UhfRadii.sm)),
      ),
    ),
```

- [ ] **Step 5: Écrire `lib/ui/uhf_icon_button.dart`**

```dart
import 'package:flutter/material.dart';

import 'tokens.dart';

class UhfIconButton extends StatefulWidget {
  const UhfIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.size = 32,
    this.iconSize = 18,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final double iconSize;

  @override
  State<UhfIconButton> createState() => _UhfIconButtonState();
}

class _UhfIconButtonState extends State<UhfIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = widget.active
        ? UhfColors.signal
        : enabled
            ? UhfColors.text
            : UhfColors.textMuted;
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: UhfDurations.fast,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _hover && enabled ? UhfColors.text.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(UhfRadii.sm),
              ),
              child: Icon(widget.icon, size: widget.iconSize, weight: 300, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Écrire `lib/ui/uhf_menu.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'tokens.dart';
import 'typography.dart';
import 'uhf_icon_button.dart';

class UhfMenuEntry {
  const UhfMenuEntry({required this.label, this.onSelected, this.checked, this.shortcut, this.children});

  final String label;
  final VoidCallback? onSelected;

  /// null: no check column; true / false: checked or empty column.
  final bool? checked;
  final String? shortcut;
  final List<UhfMenuEntry>? children;
}

class UhfMenuButton extends StatelessWidget {
  const UhfMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.entries,
    this.onOpenChanged,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final List<UhfMenuEntry> entries;
  final ValueChanged<bool>? onOpenChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      onOpen: () => onOpenChanged?.call(true),
      onClose: () => onOpenChanged?.call(false),
      menuChildren: [for (final e in entries) _item(e)],
      builder: (context, controller, _) => UhfIconButton(
        icon: icon,
        tooltip: tooltip,
        active: active,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _item(UhfMenuEntry e) {
    final children = e.children;
    if (children != null) {
      return SubmenuButton(menuChildren: [for (final c in children) _item(c)], child: Text(e.label));
    }
    final checked = e.checked;
    return MenuItemButton(
      onPressed: e.onSelected,
      leadingIcon: checked == null
          ? null
          : SizedBox(
              width: 18,
              child: checked ? const Icon(Symbols.check_sharp, size: 16, weight: 300) : null,
            ),
      trailingIcon: e.shortcut == null
          ? null
          : Text(e.shortcut!, style: UhfText.mono(size: 11, color: UhfColors.textMuted)),
      child: Text(e.label),
    );
  }
}
```

- [ ] **Step 7: Écrire `lib/ui/toast.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

class ToastMessage {
  const ToastMessage(this.text, {this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// One message at a time, bottom-left; a new message replaces the old one.
class ToastController extends ChangeNotifier {
  ToastMessage? _current;
  Timer? _timer;

  ToastMessage? get current => _current;

  void show(String text, {String? actionLabel, VoidCallback? onAction}) {
    _timer?.cancel();
    _current = ToastMessage(text, actionLabel: actionLabel, onAction: onAction);
    _timer = Timer(actionLabel == null ? UhfDurations.toast : UhfDurations.toastWithAction, dismiss);
    notifyListeners();
  }

  void dismiss() {
    _timer?.cancel();
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.controller, this.bottom = 96});

  final ToastController controller;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: bottom,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final message = controller.current;
          return AnimatedSwitcher(
            duration: UhfDurations.base,
            child: message == null
                ? const SizedBox.shrink(key: ValueKey('no-toast'))
                : Container(
                    key: ObjectKey(message),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: UhfColors.raised,
                      borderRadius: BorderRadius.circular(UhfRadii.md),
                      border: Border.all(color: UhfColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message.text, style: UhfText.body),
                        if (message.actionLabel != null) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              message.onAction?.call();
                              controller.dismiss();
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                message.actionLabel!,
                                style: UhfText.sans(weight: 500, color: UhfColors.signal),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 8: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/ui test/ui test/support/harness.dart
git commit -m "feat(ui): add icon button, menu button and toast components"
```

---

### Task 6: Contrôleur des réglages

**Files:**
- Create: `lib/features/settings/settings_controller.dart`
- Test: `test/features/settings/settings_controller_test.dart`

**Interfaces:**
- Consumes: `AppSettings`, `SettingsStore` (plan 1).
- Produces: `class SettingsController extends ChangeNotifier { SettingsController(SettingsStore store, AppSettings initial, {Duration debounce = const Duration(milliseconds: 500)}); AppSettings get value; void update(AppSettings Function(AppSettings current) change); Future<void> flush(); Locale? get locale; }`. `update` ne notifie et ne sauvegarde que si la valeur change ; `locale` vaut `null` pour `'system'`.

- [ ] **Step 1: Écrire le test**

```dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('uhf_settings_ctrl_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('update notifies, then saves after the debounce', () async {
    final store = SettingsStore(dir);
    final ctrl = SettingsController(store, AppSettings.defaults(), debounce: const Duration(milliseconds: 20));
    var notified = 0;
    ctrl.addListener(() => notified++);

    ctrl.update((s) => s.copyWith(volume: 42));
    expect(ctrl.value.volume, 42);
    expect(notified, 1);
    expect((await store.load()).volume, 80);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect((await store.load()).volume, 42);
  });

  test('an identical value neither notifies nor saves', () async {
    final ctrl = SettingsController(SettingsStore(dir), AppSettings.defaults());
    var notified = 0;
    ctrl.addListener(() => notified++);
    ctrl.update((s) => s.copyWith(volume: 80));
    expect(notified, 0);
    await ctrl.flush();
    expect(File('${dir.path}/settings.json').existsSync(), isFalse);
  });

  test('flush saves immediately', () async {
    final store = SettingsStore(dir);
    final ctrl = SettingsController(store, AppSettings.defaults());
    ctrl.update((s) => s.copyWith(language: 'tr'));
    await ctrl.flush();
    expect((await store.load()).language, 'tr');
  });

  test('locale follows the language setting', () {
    final ctrl = SettingsController(SettingsStore(dir), AppSettings.defaults());
    expect(ctrl.locale, isNull);
    ctrl.update((s) => s.copyWith(language: 'fr'));
    expect(ctrl.locale, const Locale('fr'));
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/settings`
Expected: FAIL, fichier introuvable.

- [ ] **Step 3: Écrire `lib/features/settings/settings_controller.dart`**

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_store.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._store, AppSettings initial, {this.debounce = const Duration(milliseconds: 500)})
      : _value = initial;

  final SettingsStore _store;
  final Duration debounce;
  AppSettings _value;
  Timer? _timer;
  bool _dirty = false;

  AppSettings get value => _value;

  Locale? get locale => _value.language == 'system' ? null : Locale(_value.language);

  void update(AppSettings Function(AppSettings current) change) {
    final next = change(_value);
    if (jsonEncode(next.toJson()) == jsonEncode(_value.toJson())) return;
    _value = next;
    _dirty = true;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (!_dirty) return;
    _dirty = false;
    await _store.save(_value);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings test/features/settings
git commit -m "feat(settings): add debounced settings controller with locale"
```

---

### Task 7: Contrôleur du lecteur

**Files:**
- Create: `lib/features/player/player_controller.dart`, `lib/features/player/player_settings_binding.dart`
- Test: `test/features/player/player_controller_test.dart`

**Interfaces:**
- Consumes: `MediaEngine`, `TrackInfo`, `TrackType`, `PanMode`, `IntSize`, `ResumeStore`, `ProbeService`, `screenshotFileName`, `SettingsController`, `FakeMediaEngine`.
- Produces:
  - `sealed class PlayerEvent` ; `ResumedEvent(Duration position)`, `ScreenshotSavedEvent(String path)`, `OpenFailedEvent(String path)`.
  - `class PlayerController extends ChangeNotifier { PlayerController({required MediaEngine engine, required ResumeStore resume, ProbeService? probe, Future<String> Function()? desktopDirectory, DateTime Function()? now, bool Function(String path)? fileExists, double initialVolume = 80, bool initialMuted = false, int initialSubtitleScale = 100, int initialSubtitlePos = 100}); }`
  - Lecture : `String? path`, `String? fileName`, `bool hasMedia`, `Duration position`, `Duration duration`, `bool playing`, `double volume`, `bool muted`, `List<TrackInfo> audioTracks`, `List<TrackInfo> subtitleTracks`, `int? selectedSubtitleId`, `int subtitleScale`, `int subtitlePos`, `PanMode pan`, `IntSize? videoSize`, `Stream<PlayerEvent> events`.
  - Actions : `Future<void> open(String path)`, `togglePlay()`, `seekTo(Duration)`, `seekRelative(Duration)`, `frameStep({required bool forward})`, `setVolume(double)`, `adjustVolume(double delta)`, `toggleMute()`, `selectAudio(int id)`, `selectSubtitle(int? id)`, `addSubtitle(String path)`, `previewSubtitleStyle(int scale, int pos)`, `commitSubtitleStyle(int scale, int pos)`, `togglePan(PanMode mode)`, `screenshot()`, `restartFromBeginning()`, `saveResume()`, `close()`.
  - `void bindPlayerSettings(PlayerController player, SettingsController settings)` : recopie volume, muet, taille et position des sous-titres dans les réglages à chaque changement.

- [ ] **Step 1: Écrire le test**

`test/features/player/player_controller_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/player/player_settings_binding.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';

import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late ResumeStore resume;
  late List<PlayerEvent> events;

  PlayerController make({ProbeService? probe, bool Function(String)? exists}) {
    final c = PlayerController(
      engine: engine,
      resume: resume,
      probe: probe,
      desktopDirectory: () async => r'D:\Desk',
      now: () => DateTime(2026, 10, 1, 9, 5, 7),
      fileExists: exists ?? (_) => true,
    );
    c.events.listen(events.add);
    return c;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_player_');
    engine = FakeMediaEngine();
    resume = ResumeStore(dir);
    events = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('open resets pan, turns subtitles off via the engine and applies subtitle style', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    expect(c.hasMedia, isTrue);
    expect(c.fileName, 'a.mkv');
    expect(c.pan, PanMode.stereo);
    expect(engine.calls, containsAllInOrder(['af ', r'open C:\v\a.mkv', 'sub-scale 100', 'sub-pos 100', 'deinterlace no']));
  });

  test('a missing file emits OpenFailedEvent without touching the engine', () async {
    final c = make(exists: (_) => false);
    await c.open(r'C:\v\gone.mkv');
    await settle();
    expect(events.single, isA<OpenFailedEvent>());
    expect(engine.calls.where((x) => x.startsWith('open')), isEmpty);
    expect(c.hasMedia, isFalse);
  });

  test('an engine error before the duration is known closes the file', () async {
    final c = make();
    await c.open(r'C:\v\broken.mkv');
    engine.emitError('Failed to open');
    await settle();
    expect(events.single, isA<OpenFailedEvent>());
    expect(c.hasMedia, isFalse);
  });

  test('resume applies once when the duration first arrives (review focus 1)', () async {
    resume.record(r'C:\v\b.mkv', const Duration(minutes: 41));
    final c = make();
    await c.open(r'C:\v\b.mkv');
    engine.emitDuration(const Duration(hours: 2));
    await settle();
    engine.emitDuration(const Duration(hours: 2));
    await settle();
    expect(engine.calls.where((x) => x == 'seek ${const Duration(minutes: 41).inMilliseconds}').length, 1);
    expect(events.whereType<ResumedEvent>().single.position, const Duration(minutes: 41));
    expect(c.duration, const Duration(hours: 2));
  });

  test('opening a second file saves the first position and resets pan (review focus 1)', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(hours: 1));
    engine.emitPosition(const Duration(minutes: 20));
    await settle();
    await c.togglePan(PanMode.left);
    await c.open(r'C:\v\b.mkv');
    expect(resume.resumePositionFor(r'C:\v\a.mkv', const Duration(hours: 1)), const Duration(minutes: 20));
    expect(c.pan, PanMode.stereo);
    expect(c.position, Duration.zero);
  });

  test('positions are recorded every 5 seconds', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    for (final s in [1, 3, 6, 8, 12]) {
      engine.emitPosition(Duration(seconds: s));
    }
    await settle();
    expect(resume.resumePositionFor(r'C:\v\a.mkv', const Duration(hours: 1)), const Duration(seconds: 12));
    expect(c.position, const Duration(seconds: 12));
  });

  test('end of file seeks to the start, pauses and forgets the position', () async {
    resume.record(r'C:\v\a.mkv', const Duration(minutes: 5));
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.calls.clear();
    engine.emitCompleted(true);
    await settle();
    expect(engine.calls, ['seek 0', 'pause']);
    expect(resume.resumePositionFor(r'C:\v\a.mkv', const Duration(hours: 1)), isNull);
  });

  test('seekRelative stays within [0, duration], including unknown duration (review focus 4)', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.emitPosition(const Duration(seconds: 2));
    await settle();
    engine.calls.clear();
    await c.seekRelative(const Duration(seconds: -3));
    await c.seekRelative(const Duration(seconds: 3));
    expect(engine.calls, ['seek 0', 'seek 0']);
    engine.emitDuration(const Duration(seconds: 4));
    await settle();
    engine.calls.clear();
    await c.seekRelative(const Duration(seconds: 3));
    expect(engine.calls, ['seek 4000']);
  });

  test('volume is clamped and mute toggles', () async {
    final c = make();
    await c.setVolume(140);
    expect(c.volume, 100);
    await c.adjustVolume(-5);
    expect(c.volume, 95);
    await c.adjustVolume(-200);
    expect(c.volume, 0);
    await c.toggleMute();
    expect(c.muted, isTrue);
    expect(engine.calls, containsAllInOrder(['volume 100', 'volume 95', 'volume 0', 'mute yes']));
  });

  test('tracks are read when the engine reports a change', () async {
    engine.tracks = const [
      TrackInfo(type: TrackType.audio, id: 1, selected: true),
      TrackInfo(type: TrackType.audio, id: 2),
      TrackInfo(type: TrackType.subtitle, id: 1, selected: true),
    ];
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.emitTracksChanged();
    await settle();
    expect(c.audioTracks.map((t) => t.id), [1, 2]);
    expect(c.subtitleTracks.length, 1);
    expect(c.selectedSubtitleId, 1);
    await c.selectSubtitle(null);
    await c.selectAudio(2);
    expect(engine.calls, containsAllInOrder(['sid no', 'aid 2']));
  });

  test('pan toggles between a channel and stereo', () async {
    final c = make();
    await c.togglePan(PanMode.left);
    expect(c.pan, PanMode.left);
    await c.togglePan(PanMode.right);
    expect(c.pan, PanMode.right);
    await c.togglePan(PanMode.right);
    expect(c.pan, PanMode.stereo);
  });

  test('interlaced sources enable deinterlacing', () async {
    final probe = ProbeService('ffprobe', run: (_, __) async => ProcessResult(
          1,
          0,
          '{"streams":[{"index":0,"codec_type":"video","field_order":"tt"}],"format":{}}',
          '',
        ));
    final c = make(probe: probe);
    await c.open(r'C:\v\a.ts');
    expect(engine.calls.last, 'deinterlace yes');
  });

  test('screenshot writes to the desktop with a timestamped name', () async {
    final c = make();
    await c.screenshot();
    expect(engine.calls, isEmpty);
    await c.open(r'C:\v\a.mkv');
    await c.screenshot();
    await settle();
    expect(engine.calls.last, r'screenshot D:\Desk\UHF_20261001_090507.png');
    expect((events.last as ScreenshotSavedEvent).path, r'D:\Desk\UHF_20261001_090507.png');
  });

  test('subtitle preview does not persist; commit does', () async {
    final c = make();
    await c.previewSubtitleStyle(150, 80);
    expect(c.subtitleScale, 100);
    expect(engine.calls, ['sub-scale 150', 'sub-pos 80']);
    await c.commitSubtitleStyle(150, 80);
    expect(c.subtitleScale, 150);
    expect(c.subtitlePos, 80);
  });

  test('bindPlayerSettings copies volume and subtitle style into settings', () async {
    final settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    final c = make();
    bindPlayerSettings(c, settings);
    await c.setVolume(33);
    await c.toggleMute();
    await c.commitSubtitleStyle(120, 90);
    expect(settings.value.volume, 33);
    expect(settings.value.muted, isTrue);
    expect(settings.value.subtitleScale, 120);
    expect(settings.value.subtitlePos, 90);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/player/player_controller_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/features/player/player_controller.dart`**

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/files/media_files.dart';
import '../../core/geometry/geometry.dart';
import '../../core/media/media_engine.dart';
import '../../core/media/pan_mode.dart';
import '../../core/media/track_info.dart';
import '../../core/settings/resume_store.dart';
import '../../core/system/probe_service.dart';

sealed class PlayerEvent {
  const PlayerEvent();
}

class ResumedEvent extends PlayerEvent {
  const ResumedEvent(this.position);
  final Duration position;
}

class ScreenshotSavedEvent extends PlayerEvent {
  const ScreenshotSavedEvent(this.path);
  final String path;
}

class OpenFailedEvent extends PlayerEvent {
  const OpenFailedEvent(this.path);
  final String path;
}

class PlayerController extends ChangeNotifier {
  PlayerController({
    required MediaEngine engine,
    required ResumeStore resume,
    ProbeService? probe,
    Future<String> Function()? desktopDirectory,
    DateTime Function()? now,
    bool Function(String path)? fileExists,
    double initialVolume = 80,
    bool initialMuted = false,
    int initialSubtitleScale = 100,
    int initialSubtitlePos = 100,
  })  : _engine = engine,
        _resume = resume,
        _probe = probe,
        _desktopDirectory = desktopDirectory ?? (() async => Directory.current.path),
        _now = now ?? DateTime.now,
        _fileExists = fileExists ?? ((path) => File(path).existsSync()),
        _volume = initialVolume,
        _muted = initialMuted,
        _subtitleScale = initialSubtitleScale,
        _subtitlePos = initialSubtitlePos {
    _subscriptions.addAll([
      engine.position.listen(_onPosition),
      engine.duration.listen(_onDuration),
      engine.playing.listen((v) {
        _playing = v;
        notifyListeners();
      }),
      engine.completed.listen(_onCompleted),
      engine.videoSize.listen((s) {
        _videoSize = s;
        notifyListeners();
      }),
      engine.tracksChanged.listen((_) => unawaited(refreshTracks())),
      engine.errors.listen(_onError),
    ]);
    unawaited(engine.setVolume(initialVolume));
    unawaited(engine.setMuted(initialMuted));
  }

  static const _recordEvery = Duration(seconds: 5);

  final MediaEngine _engine;
  final ResumeStore _resume;
  final ProbeService? _probe;
  final Future<String> Function() _desktopDirectory;
  final DateTime Function() _now;
  final bool Function(String path) _fileExists;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final _events = StreamController<PlayerEvent>.broadcast();

  String? _path;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _lastRecorded = Duration.zero;
  bool _pendingResume = false;
  bool _playing = false;
  double _volume;
  bool _muted;
  List<TrackInfo> _tracks = const [];
  int _subtitleScale;
  int _subtitlePos;
  PanMode _pan = PanMode.stereo;
  IntSize? _videoSize;

  String? get path => _path;
  String? get fileName => _path == null ? null : p.windows.basename(_path!);
  bool get hasMedia => _path != null;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get playing => _playing;
  double get volume => _volume;
  bool get muted => _muted;
  List<TrackInfo> get audioTracks => _tracks.where((t) => t.type == TrackType.audio).toList();
  List<TrackInfo> get subtitleTracks => _tracks.where((t) => t.type == TrackType.subtitle).toList();
  int? get selectedSubtitleId => subtitleTracks.where((t) => t.selected).firstOrNull?.id;
  int get subtitleScale => _subtitleScale;
  int get subtitlePos => _subtitlePos;
  PanMode get pan => _pan;
  IntSize? get videoSize => _videoSize;
  Stream<PlayerEvent> get events => _events.stream;

  Future<void> open(String path) async {
    if (!_fileExists(path)) {
      _events.add(OpenFailedEvent(path));
      return;
    }
    await saveResume();
    _path = path;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lastRecorded = Duration.zero;
    _pendingResume = true;
    _tracks = const [];
    _pan = PanMode.stereo;
    _videoSize = null;
    notifyListeners();
    try {
      await _engine.setPan(PanMode.stereo);
      await _engine.open(path);
      await _engine.setSubtitleScale(_subtitleScale);
      await _engine.setSubtitlePosition(_subtitlePos);
      final probe = await _probe?.probe(path);
      await _engine.setDeinterlace(probe?.isInterlaced ?? false);
    } on Exception {
      _failOpen(path);
    }
  }

  void _failOpen(String path) {
    _path = null;
    _pendingResume = false;
    notifyListeners();
    _events.add(OpenFailedEvent(path));
  }

  void _onError(String _) {
    final path = _path;
    if (path != null && _duration == Duration.zero) _failOpen(path);
  }

  void _onDuration(Duration d) {
    _duration = d;
    final path = _path;
    if (_pendingResume && path != null && d > Duration.zero) {
      _pendingResume = false;
      final resumeAt = _resume.resumePositionFor(path, d);
      if (resumeAt != null) {
        unawaited(_engine.seek(resumeAt));
        _events.add(ResumedEvent(resumeAt));
      }
    }
    notifyListeners();
  }

  void _onPosition(Duration position) {
    _position = position;
    final path = _path;
    if (path != null && (position - _lastRecorded).abs() >= _recordEvery) {
      _lastRecorded = position;
      _resume.record(path, position);
    }
    notifyListeners();
  }

  void _onCompleted(bool done) {
    final path = _path;
    if (!done || path == null) return;
    _resume.clear(path);
    unawaited(_engine.seek(Duration.zero));
    unawaited(_engine.pause());
  }

  Future<void> togglePlay() => _playing ? _engine.pause() : _engine.play();

  Future<void> seekTo(Duration target) {
    var t = target < Duration.zero ? Duration.zero : target;
    if (t > _duration) t = _duration;
    return _engine.seek(t);
  }

  Future<void> seekRelative(Duration delta) => seekTo(_position + delta);

  Future<void> frameStep({required bool forward}) => _engine.frameStep(forward: forward);

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 100).toDouble();
    notifyListeners();
    await _engine.setVolume(_volume);
  }

  Future<void> adjustVolume(double delta) => setVolume(_volume + delta);

  Future<void> toggleMute() async {
    _muted = !_muted;
    notifyListeners();
    await _engine.setMuted(_muted);
  }

  Future<void> refreshTracks() async {
    _tracks = await _engine.readTracks();
    notifyListeners();
  }

  Future<void> selectAudio(int id) async {
    await _engine.selectAudio(id);
    await refreshTracks();
  }

  Future<void> selectSubtitle(int? id) async {
    await _engine.selectSubtitle(id);
    await refreshTracks();
  }

  Future<void> addSubtitle(String path) async {
    if (!hasMedia) return;
    await _engine.addSubtitle(path);
    await refreshTracks();
  }

  Future<void> previewSubtitleStyle(int scale, int pos) async {
    await _engine.setSubtitleScale(scale);
    await _engine.setSubtitlePosition(pos);
  }

  Future<void> commitSubtitleStyle(int scale, int pos) async {
    _subtitleScale = scale;
    _subtitlePos = pos;
    notifyListeners();
    await previewSubtitleStyle(scale, pos);
  }

  Future<void> togglePan(PanMode mode) async {
    _pan = _pan == mode ? PanMode.stereo : mode;
    notifyListeners();
    await _engine.setPan(_pan);
  }

  Future<void> screenshot() async {
    if (!hasMedia) return;
    final dir = await _desktopDirectory();
    final file = p.windows.join(dir, screenshotFileName(_now()));
    await _engine.screenshotTo(file);
    _events.add(ScreenshotSavedEvent(file));
  }

  Future<void> restartFromBeginning() => _engine.seek(Duration.zero);

  Future<void> saveResume() async {
    final path = _path;
    if (path != null && _position > Duration.zero) _resume.record(path, _position);
    await _resume.flush();
  }

  Future<void> close() async {
    await saveResume();
    await _engine.close();
    _path = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_events.close());
    super.dispose();
  }
}
```

- [ ] **Step 4: Écrire `lib/features/player/player_settings_binding.dart`**

```dart
import '../settings/settings_controller.dart';
import 'player_controller.dart';

void bindPlayerSettings(PlayerController player, SettingsController settings) {
  player.addListener(() {
    settings.update((s) => s.copyWith(
          volume: player.volume,
          muted: player.muted,
          subtitleScale: player.subtitleScale,
          subtitlePos: player.subtitlePos,
        ));
  });
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/player test/features/player
git commit -m "feat(player): add player controller with resume, tracks, pan and screenshots"
```

---

### Task 8: Fenêtre (hôte et contrôleur)

**Files:**
- Create: `lib/features/shell/window_host.dart`, `lib/features/shell/window_manager_host.dart`, `lib/features/shell/shell_controller.dart`, `test/support/fake_window_host.dart`
- Test: `test/features/shell/shell_controller_test.dart`

**Interfaces:**
- Consumes: `SettingsController`, `AppSettings`, `UhfColors`.
- Produces:
  - `enum WindowEvent { maximized, unmaximized, enteredFullScreen, leftFullScreen, boundsChanged }`
  - `abstract interface class WindowHost { Stream<WindowEvent> get events; Future<void> maximize(); Future<void> unmaximize(); Future<void> minimize(); Future<void> close(); Future<void> setFullScreen(bool value); Future<void> setAlwaysOnTop(bool value); Future<void> setTitle(String title); Future<void> startDragging(); Future<void> bringToFront(); Future<Rect> getBounds(); }`
  - `class WindowManagerHost with WindowListener implements WindowHost { WindowManagerHost(); Future<void> Function()? onCloseRequested; static Future<void> configure(AppSettings settings); }`
  - `class ShellController extends ChangeNotifier { ShellController(WindowHost host, SettingsController settings); bool fullscreen, maximized, alwaysOnTop; toggleFullscreen(), exitFullscreen(), toggleMaximize(), toggleAlwaysOnTop(), minimize(), close(), startDragging(), bringToFront(), setFileName(String? name); }`
  - Test : `class FakeWindowHost implements WindowHost` avec `calls`, `bounds`, `emit(WindowEvent)`.

- [ ] **Step 1: Écrire la doublure `test/support/fake_window_host.dart`**

```dart
import 'dart:async';
import 'dart:ui';

import 'package:uhf_media/features/shell/window_host.dart';

class FakeWindowHost implements WindowHost {
  final calls = <String>[];
  Rect bounds = const Rect.fromLTWH(100, 50, 1100, 780);
  final _events = StreamController<WindowEvent>.broadcast();

  void emit(WindowEvent e) => _events.add(e);

  @override
  Stream<WindowEvent> get events => _events.stream;
  @override
  Future<void> maximize() async => calls.add('maximize');
  @override
  Future<void> unmaximize() async => calls.add('unmaximize');
  @override
  Future<void> minimize() async => calls.add('minimize');
  @override
  Future<void> close() async => calls.add('close');
  @override
  Future<void> setFullScreen(bool value) async => calls.add('fullscreen $value');
  @override
  Future<void> setAlwaysOnTop(bool value) async => calls.add('top $value');
  @override
  Future<void> setTitle(String title) async => calls.add('title $title');
  @override
  Future<void> startDragging() async => calls.add('drag');
  @override
  Future<void> bringToFront() async => calls.add('front');
  @override
  Future<Rect> getBounds() async => bounds;
}
```

- [ ] **Step 2: Écrire le test**

`test/features/shell/shell_controller_test.dart` :

```dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/features/shell/window_host.dart';

import '../../support/fake_window_host.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory dir;
  late FakeWindowHost host;
  late SettingsController settings;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_shell_');
    host = FakeWindowHost();
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults().copyWith(alwaysOnTop: true));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('initial state comes from the settings', () {
    final shell = ShellController(host, settings);
    expect(shell.alwaysOnTop, isTrue);
    expect(shell.maximized, isFalse);
    expect(shell.fullscreen, isFalse);
  });

  test('fullscreen toggles and exits', () async {
    final shell = ShellController(host, settings);
    await shell.toggleFullscreen();
    expect(shell.fullscreen, isTrue);
    await shell.exitFullscreen();
    expect(shell.fullscreen, isFalse);
    await shell.exitFullscreen();
    expect(host.calls, ['fullscreen true', 'fullscreen false']);
  });

  test('always on top toggles and is saved', () async {
    final shell = ShellController(host, settings);
    await shell.toggleAlwaysOnTop();
    expect(shell.alwaysOnTop, isFalse);
    expect(settings.value.alwaysOnTop, isFalse);
    expect(host.calls, ['top false']);
  });

  test('maximize follows window events and is saved', () async {
    final shell = ShellController(host, settings);
    await shell.toggleMaximize();
    expect(host.calls, ['maximize']);
    host.emit(WindowEvent.maximized);
    await settle();
    expect(shell.maximized, isTrue);
    expect(settings.value.maximized, isTrue);
    await shell.toggleMaximize();
    expect(host.calls.last, 'unmaximize');
  });

  test('bounds are saved only for a normal window', () async {
    final shell = ShellController(host, settings);
    host.bounds = const Rect.fromLTWH(10, 20, 900, 600);
    host.emit(WindowEvent.boundsChanged);
    await settle();
    expect(settings.value.windowX, 10);
    expect(settings.value.windowWidth, 900);

    host.emit(WindowEvent.maximized);
    await settle();
    host.bounds = const Rect.fromLTWH(0, 0, 1920, 1080);
    host.emit(WindowEvent.boundsChanged);
    await settle();
    expect(settings.value.windowWidth, 900);
    expect(shell.maximized, isTrue);
  });

  test('title shows the file name', () async {
    final shell = ShellController(host, settings);
    await shell.setFileName('clip.mkv');
    await shell.setFileName(null);
    expect(host.calls, ['title clip.mkv — UHF Media', 'title UHF Media']);
  });
}
```

- [ ] **Step 3: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/shell/shell_controller_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 4: Écrire `lib/features/shell/window_host.dart`**

```dart
import 'dart:ui';

enum WindowEvent { maximized, unmaximized, enteredFullScreen, leftFullScreen, boundsChanged }

abstract interface class WindowHost {
  Stream<WindowEvent> get events;
  Future<void> maximize();
  Future<void> unmaximize();
  Future<void> minimize();
  Future<void> close();
  Future<void> setFullScreen(bool value);
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setTitle(String title);
  Future<void> startDragging();
  Future<void> bringToFront();
  Future<Rect> getBounds();
}
```

- [ ] **Step 5: Écrire `lib/features/shell/shell_controller.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../settings/settings_controller.dart';
import 'window_host.dart';

class ShellController extends ChangeNotifier {
  ShellController(this._host, this._settings)
      : _alwaysOnTop = _settings.value.alwaysOnTop,
        _maximized = _settings.value.maximized {
    _subscription = _host.events.listen(_onEvent);
  }

  final WindowHost _host;
  final SettingsController _settings;
  late final StreamSubscription<WindowEvent> _subscription;
  bool _fullscreen = false;
  bool _maximized;
  bool _alwaysOnTop;

  bool get fullscreen => _fullscreen;
  bool get maximized => _maximized;
  bool get alwaysOnTop => _alwaysOnTop;

  Future<void> toggleFullscreen() async {
    final next = !_fullscreen;
    await _host.setFullScreen(next);
    _fullscreen = next;
    notifyListeners();
  }

  Future<void> exitFullscreen() async {
    if (_fullscreen) await toggleFullscreen();
  }

  Future<void> toggleMaximize() => _maximized ? _host.unmaximize() : _host.maximize();

  Future<void> toggleAlwaysOnTop() async {
    final next = !_alwaysOnTop;
    await _host.setAlwaysOnTop(next);
    _alwaysOnTop = next;
    _settings.update((s) => s.copyWith(alwaysOnTop: next));
    notifyListeners();
  }

  Future<void> minimize() => _host.minimize();
  Future<void> close() => _host.close();
  Future<void> startDragging() => _host.startDragging();
  Future<void> bringToFront() => _host.bringToFront();

  Future<void> setFileName(String? name) => _host.setTitle(name == null ? 'UHF Media' : '$name — UHF Media');

  Future<void> _onEvent(WindowEvent e) async {
    switch (e) {
      case WindowEvent.maximized:
      case WindowEvent.unmaximized:
        _maximized = e == WindowEvent.maximized;
        _settings.update((s) => s.copyWith(maximized: _maximized));
      case WindowEvent.enteredFullScreen:
        _fullscreen = true;
      case WindowEvent.leftFullScreen:
        _fullscreen = false;
      case WindowEvent.boundsChanged:
        if (_maximized || _fullscreen) return;
        final b = await _host.getBounds();
        _settings.update((s) => s.copyWith(
              windowX: b.left,
              windowY: b.top,
              windowWidth: b.width,
              windowHeight: b.height,
            ));
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
```

- [ ] **Step 6: Écrire `lib/features/shell/window_manager_host.dart`**

```dart
import 'dart:async';
import 'dart:ui';

import 'package:window_manager/window_manager.dart';

import '../../core/settings/app_settings.dart';
import '../../ui/tokens.dart';
import 'window_host.dart';

class WindowManagerHost with WindowListener implements WindowHost {
  WindowManagerHost() {
    windowManager.addListener(this);
  }

  final _events = StreamController<WindowEvent>.broadcast();

  /// Runs before the window is destroyed (save settings, resume positions).
  Future<void> Function()? onCloseRequested;

  /// Shows the window with the saved size and position, without the native
  /// title bar (Windows keeps its resize border and rounded corners).
  static Future<void> configure(AppSettings settings) async {
    final options = WindowOptions(
      size: Size(settings.windowWidth, settings.windowHeight),
      center: settings.windowX == null,
      minimumSize: const Size(640, 400),
      backgroundColor: UhfColors.ink,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'UHF Media',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      final x = settings.windowX;
      final y = settings.windowY;
      if (x != null && y != null) {
        await windowManager.setBounds(Rect.fromLTWH(x, y, settings.windowWidth, settings.windowHeight));
      }
      if (settings.maximized) await windowManager.maximize();
      if (settings.alwaysOnTop) await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setPreventClose(true);
  }

  @override
  Stream<WindowEvent> get events => _events.stream;

  @override
  void onWindowMaximize() => _events.add(WindowEvent.maximized);
  @override
  void onWindowUnmaximize() => _events.add(WindowEvent.unmaximized);
  @override
  void onWindowEnterFullScreen() => _events.add(WindowEvent.enteredFullScreen);
  @override
  void onWindowLeaveFullScreen() => _events.add(WindowEvent.leftFullScreen);
  @override
  void onWindowResized() => _events.add(WindowEvent.boundsChanged);
  @override
  void onWindowMoved() => _events.add(WindowEvent.boundsChanged);

  @override
  Future<void> onWindowClose() async {
    try {
      await onCloseRequested?.call();
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  Future<void> maximize() => windowManager.maximize();
  @override
  Future<void> unmaximize() => windowManager.unmaximize();
  @override
  Future<void> minimize() => windowManager.minimize();
  @override
  Future<void> close() => windowManager.close();
  @override
  Future<void> setFullScreen(bool value) => windowManager.setFullScreen(value);
  @override
  Future<void> setAlwaysOnTop(bool value) => windowManager.setAlwaysOnTop(value);
  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);
  @override
  Future<void> startDragging() => windowManager.startDragging();
  @override
  Future<Rect> getBounds() => windowManager.getBounds();

  @override
  Future<void> bringToFront() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }
}
```

- [ ] **Step 7: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/shell test/features/shell test/support/fake_window_host.dart
git commit -m "feat(shell): add window host abstraction and shell controller"
```

---

### Task 9: Barre de titre

**Files:**
- Create: `lib/features/shell/title_bar.dart`
- Test: `test/features/shell/title_bar_test.dart`

**Interfaces:**
- Consumes: `ShellController`, `UhfIconButton`, `AppLocalizations`, `FakeWindowHost`, `harness`.
- Produces: `class TitleBar extends StatelessWidget { const TitleBar({super.key, required ShellController shell, required String? fileName, required VoidCallback onOpen}); static const double height = 30; }`. Les boutons de fenêtre sont des `_WindowButton` dessinés (traits 1 px) ; la zone centrale déplace la fenêtre et agrandit au double-clic.

- [ ] **Step 1: Écrire le test**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/features/shell/title_bar.dart';

import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeWindowHost host;
  late ShellController shell;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_title_');
    host = FakeWindowHost();
    shell = ShellController(host, SettingsController(SettingsStore(dir), AppSettings.defaults()));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('shows the file name and runs the window buttons', (tester) async {
    var opened = false;
    await tester.pumpWidget(harness(TitleBar(shell: shell, fileName: 'clip.mkv', onOpen: () => opened = true)));
    expect(find.text('clip.mkv'), findsOneWidget);

    await tester.tap(find.byTooltip('Open (Ctrl+O)'));
    await tester.tap(find.byTooltip('Minimize'));
    await tester.tap(find.byTooltip('Maximize'));
    await tester.tap(find.byTooltip('Always on top (Ctrl+T)'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(opened, isTrue);
    expect(host.calls, ['minimize', 'maximize', 'top true', 'close']);
  });

  testWidgets('dragging the middle moves the window, double-click maximizes', (tester) async {
    await tester.pumpWidget(harness(TitleBar(shell: shell, fileName: 'clip.mkv', onOpen: () {})));
    await tester.drag(find.text('clip.mkv'), const Offset(40, 0));
    expect(host.calls, contains('drag'));
    host.calls.clear();
    await tester.tap(find.text('clip.mkv'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('clip.mkv'));
    await tester.pumpAndSettle();
    expect(host.calls, ['maximize']);
  });

  testWidgets('bar is 30 px high', (tester) async {
    await tester.pumpWidget(harness(Align(
      alignment: Alignment.topCenter,
      child: TitleBar(shell: shell, fileName: null, onOpen: () {}),
    )));
    expect(tester.getSize(find.byType(TitleBar)).height, TitleBar.height);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/shell/title_bar_test.dart`
Expected: FAIL, `title_bar.dart` introuvable.

- [ ] **Step 3: Écrire `lib/features/shell/title_bar.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_icon_button.dart';
import 'shell_controller.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key, required this.shell, required this.fileName, required this.onOpen});

  static const double height = 30;

  final ShellController shell;
  final String? fileName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: shell,
      builder: (context, _) => Container(
        height: height,
        decoration: const BoxDecoration(
          color: UhfColors.ink,
          border: Border(bottom: BorderSide(color: UhfColors.surface)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            UhfIconButton(
              icon: Symbols.folder_open_sharp,
              tooltip: l.tooltipOpen,
              onPressed: onOpen,
              size: 28,
              iconSize: 17,
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => shell.startDragging(),
                onDoubleTap: shell.toggleMaximize,
                child: Center(
                  child: Text(
                    fileName ?? '',
                    style: UhfText.caption.copyWith(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            UhfIconButton(
              icon: Symbols.push_pin_sharp,
              tooltip: l.tooltipPin,
              onPressed: shell.toggleAlwaysOnTop,
              active: shell.alwaysOnTop,
              size: 28,
              iconSize: 15,
            ),
            const SizedBox(width: 4),
            _WindowButton(glyph: _Glyph.minimize, tooltip: l.tooltipMinimize, onPressed: shell.minimize),
            _WindowButton(
              glyph: shell.maximized ? _Glyph.restore : _Glyph.maximize,
              tooltip: shell.maximized ? l.tooltipRestore : l.tooltipMaximize,
              onPressed: shell.toggleMaximize,
            ),
            _WindowButton(glyph: _Glyph.close, tooltip: l.tooltipClose, onPressed: shell.close, danger: true),
          ],
        ),
      ),
    );
  }
}

enum _Glyph { minimize, maximize, restore, close }

class _WindowButton extends StatefulWidget {
  const _WindowButton({required this.glyph, required this.tooltip, required this.onPressed, this.danger = false});

  final _Glyph glyph;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final background = !_hover
        ? Colors.transparent
        : widget.danger
            ? UhfColors.signal
            : UhfColors.text.withValues(alpha: 0.08);
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: UhfDurations.fast,
              width: 44,
              height: TitleBar.height,
              color: background,
              child: CustomPaint(
                painter: _GlyphPainter(
                  widget.glyph,
                  _hover && widget.danger ? UhfColors.ink : UhfColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final c = size.center(Offset.zero);
    const h = 5.0;
    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(Offset(c.dx - h, c.dy + 0.5), Offset(c.dx + h, c.dy + 0.5), paint);
      case _Glyph.maximize:
        canvas.drawRect(Rect.fromCenter(center: c + const Offset(0.5, 0.5), width: 2 * h, height: 2 * h), paint);
      case _Glyph.restore:
        canvas.drawRect(Rect.fromLTWH(c.dx - h + 0.5, c.dy - h + 2.5, 2 * h - 2, 2 * h - 2), paint);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - h + 2.5, c.dy - h + 2.5)
            ..lineTo(c.dx - h + 2.5, c.dy - h + 0.5)
            ..lineTo(c.dx + h + 0.5, c.dy - h + 0.5)
            ..lineTo(c.dx + h + 0.5, c.dy + h - 1.5)
            ..lineTo(c.dx + h - 1.5, c.dy + h - 1.5),
          paint,
        );
      case _Glyph.close:
        canvas.drawLine(c + const Offset(-h, -h), c + const Offset(h, h), paint);
        canvas.drawLine(c + const Offset(h, -h), c + const Offset(-h, h), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/shell/title_bar.dart test/features/shell/title_bar_test.dart
git commit -m "feat(shell): add title bar with drawn window buttons"
```

---

### Task 10: Timeline et volume

**Files:**
- Create: `lib/features/player/timeline.dart`, `lib/features/player/volume_control.dart`
- Test: `test/features/player/timeline_test.dart`

**Interfaces:**
- Consumes: `UhfColors`, `UhfText`, `formatTimecode`, `UhfIconButton`, `PlayerController`, `AppLocalizations`.
- Produces:
  - `class Timeline extends StatefulWidget { const Timeline({super.key, required Duration position, required Duration duration, required ValueChanged<Duration> onSeek}); }` — clic : saut immédiat ; glissement : aperçu local, saut au relâchement ; survol : timecode au-dessus du curseur ; durée nulle : rien n'est appelé.
  - `class VolumeControl extends StatelessWidget { const VolumeControl({super.key, required PlayerController player}); }`.

- [ ] **Step 1: Écrire le test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/features/player/timeline.dart';

import '../../support/harness.dart';

Widget _timeline({required Duration duration, required ValueChanged<Duration> onSeek}) => harness(
      Center(
        child: SizedBox(
          width: 400,
          child: Timeline(position: Duration.zero, duration: duration, onSeek: onSeek),
        ),
      ),
    );

void main() {
  testWidgets('tapping seeks to the matching time', (tester) async {
    Duration? seeked;
    await tester.pumpWidget(_timeline(duration: const Duration(minutes: 100), onSeek: (d) => seeked = d));
    final box = tester.getRect(find.byType(Timeline));
    await tester.tapAt(Offset(box.left + box.width * 0.25, box.center.dy));
    expect(seeked!.inSeconds, closeTo(const Duration(minutes: 25).inSeconds, 2));
  });

  testWidgets('dragging seeks once, on release', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_timeline(duration: const Duration(minutes: 10), onSeek: seeks.add));
    final box = tester.getRect(find.byType(Timeline));
    final gesture = await tester.startGesture(Offset(box.left + 40, box.center.dy));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.moveBy(const Offset(60, 0));
    expect(seeks, isEmpty);
    await gesture.up();
    expect(seeks.length, 1);
    expect(seeks.single.inSeconds, closeTo(const Duration(minutes: 5).inSeconds, 3));
  });

  testWidgets('unknown duration never seeks (review focus 4)', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_timeline(duration: Duration.zero, onSeek: seeks.add));
    await tester.tap(find.byType(Timeline));
    expect(seeks, isEmpty);
  });

  testWidgets('hovering shows the time under the pointer', (tester) async {
    await tester.pumpWidget(_timeline(duration: const Duration(hours: 1), onSeek: (_) {}));
    final box = tester.getRect(find.byType(Timeline));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(box.left + box.width / 2, box.center.dy));
    await tester.pump();
    expect(find.text('00:30:00'), findsOneWidget);
    await mouse.removePointer();
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/player/timeline_test.dart`
Expected: FAIL, `timeline.dart` introuvable.

- [ ] **Step 3: Écrire `lib/features/player/timeline.dart`**

```dart
import 'package:flutter/material.dart';

import '../../core/util/time_format.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';

class Timeline extends StatefulWidget {
  const Timeline({super.key, required this.position, required this.duration, required this.onSeek});

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  double? _dragFraction;
  double? _hoverX;

  bool get _known => widget.duration > Duration.zero;

  Duration _at(double fraction) =>
      Duration(milliseconds: (widget.duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      double fractionOf(double x) => width <= 0 ? 0 : (x / width).clamp(0.0, 1.0);
      final played = _dragFraction ??
          (_known ? widget.position.inMilliseconds / widget.duration.inMilliseconds : 0.0);
      final hoverX = _hoverX;

      return MouseRegion(
        cursor: _known ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
        onExit: (_) => setState(() => _hoverX = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            if (_known) widget.onSeek(_at(fractionOf(d.localPosition.dx)));
          },
          onHorizontalDragStart: (d) {
            if (_known) setState(() => _dragFraction = fractionOf(d.localPosition.dx));
          },
          onHorizontalDragUpdate: (d) {
            if (_known) setState(() => _dragFraction = fractionOf(d.localPosition.dx));
          },
          onHorizontalDragEnd: (_) {
            final f = _dragFraction;
            setState(() => _dragFraction = null);
            if (f != null) widget.onSeek(_at(f));
          },
          child: SizedBox(
            height: 16,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TimelinePainter(
                      played: played.clamp(0.0, 1.0),
                      thick: hoverX != null || _dragFraction != null,
                    ),
                  ),
                ),
                if (hoverX != null && _known)
                  Positioned(
                    left: (hoverX - 32).clamp(0.0, (width - 64).clamp(0.0, double.infinity)),
                    bottom: 18,
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: UhfColors.raised,
                        borderRadius: BorderRadius.circular(UhfRadii.sm),
                        border: Border.all(color: UhfColors.line),
                      ),
                      child: Text(
                        formatTimecode(_at(fractionOf(hoverX))),
                        textAlign: TextAlign.center,
                        style: UhfText.mono(size: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.played, required this.thick});

  final double played;
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    final h = thick ? 4.0 : 2.0;
    final top = (size.height - h) / 2;
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, h), Paint()..color = UhfColors.line);
    final x = size.width * played;
    canvas.drawRect(Rect.fromLTWH(0, top, x, h), Paint()..color = UhfColors.signal);
    canvas.drawRect(Rect.fromLTWH(x - 1, (size.height - 11) / 2, 2, 11), Paint()..color = UhfColors.text);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.played != played || old.thick != thick;
}
```

- [ ] **Step 4: Écrire `lib/features/player/volume_control.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/uhf_icon_button.dart';
import 'player_controller.dart';

class VolumeControl extends StatelessWidget {
  const VolumeControl({super.key, required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final silent = player.muted || player.volume == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UhfIconButton(
          icon: silent ? Symbols.volume_off_sharp : Symbols.volume_up_sharp,
          tooltip: player.muted ? l.tooltipUnmute : l.tooltipMute,
          onPressed: player.toggleMute,
        ),
        SizedBox(
          width: 80,
          child: ExcludeFocus(
            child: Slider(
              value: player.volume / 100,
              onChanged: (v) => player.setVolume(v * 100),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/timeline.dart lib/features/player/volume_control.dart test/features/player/timeline_test.dart
git commit -m "feat(player): add timeline and volume control"
```

---

### Task 11: Menus du lecteur et réglages des sous-titres

**Files:**
- Create: `lib/features/player/player_menus.dart`, `lib/features/player/subtitle_settings_dialog.dart`
- Test: `test/features/player/player_menus_test.dart`

**Interfaces:**
- Consumes: `PlayerController`, `ShellController`, `SettingsController`, `TrackInfo`, `PanMode`, `UhfMenuEntry`, `AppLocalizations`, `FakeMediaEngine`.
- Produces:
  - `List<UhfMenuEntry> audioMenuEntries(PlayerController player, AppLocalizations l)` ;
  - `List<UhfMenuEntry> subtitleMenuEntries(PlayerController player, AppLocalizations l)` (première entrée : `subtitlesOff`) ;
  - `List<UhfMenuEntry> moreMenuEntries({required PlayerController player, required ShellController shell, required SettingsController settings, required AppLocalizations l, required VoidCallback onSubtitleSettings})` : capture (`S`), mono gauche, mono droite, réglages des sous-titres, toujours au premier plan (`Ctrl+T`), langue (sous-menu : Système, English, Français, Türkçe) ;
  - `Future<void> showSubtitleSettings(BuildContext context, PlayerController player)` : curseurs taille 50–300 et position 0–100 appliqués en direct ; *Annuler* rétablit les valeurs d'origine, *Appliquer* les garde.

- [ ] **Step 1: Écrire le test**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/player/player_menus.dart';
import 'package:uhf_media/features/player/subtitle_settings_dialog.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/l10n/app_localizations_en.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late SettingsController settings;
  late ShellController shell;
  final l = AppLocalizationsEn();

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('uhf_menus_');
    engine = FakeMediaEngine()
      ..tracks = const [
        TrackInfo(type: TrackType.audio, id: 1, language: 'fre', selected: true),
        TrackInfo(type: TrackType.audio, id: 2),
        TrackInfo(type: TrackType.subtitle, id: 4, language: 'eng'),
      ];
    player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => true);
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    shell = ShellController(FakeWindowHost(), settings);
    await player.open(r'C:\v\a.mkv');
    await player.refreshTracks();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('audio entries show labels, numbered fallback and selection', () async {
    final entries = audioMenuEntries(player, l);
    expect(entries.map((e) => e.label), ['FRE', 'Track 2']);
    expect(entries.map((e) => e.checked), [true, false]);
    entries[1].onSelected!();
    await Future<void>.delayed(Duration.zero);
    expect(engine.calls, contains('aid 2'));
  });

  test('subtitle entries start with Off, checked when nothing is selected', () async {
    final entries = subtitleMenuEntries(player, l);
    expect(entries.map((e) => e.label), ['Off', 'ENG']);
    expect(entries.first.checked, isTrue);
    entries[1].onSelected!();
    await Future<void>.delayed(Duration.zero);
    expect(engine.calls, contains('sid 4'));
  });

  test('more menu toggles mono, always on top and language', () async {
    var opened = false;
    final entries = moreMenuEntries(
      player: player,
      shell: shell,
      settings: settings,
      l: l,
      onSubtitleSettings: () => opened = true,
    );
    expect(entries.map((e) => e.label), [
      'Screenshot',
      'Mono from left channel',
      'Mono from right channel',
      'Subtitle settings…',
      'Always on top (Ctrl+T)',
      'Language',
    ]);
    entries[1].onSelected!();
    await Future<void>.delayed(Duration.zero);
    expect(player.pan, PanMode.left);
    entries[3].onSelected!();
    expect(opened, isTrue);
    final languages = entries.last.children!;
    expect(languages.map((e) => e.label), ['System', 'English', 'Français', 'Türkçe']);
    languages[3].onSelected!();
    expect(settings.value.language, 'tr');
  });

  testWidgets('subtitle dialog previews live, cancel restores, apply keeps', (tester) async {
    await tester.pumpWidget(harness(Builder(
      builder: (context) => TextButton(
        onPressed: () => showSubtitleSettings(context, player),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Size'), findsOneWidget);

    engine.calls.clear();
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();
    expect(engine.calls.any((c) => c.startsWith('sub-scale ')), isTrue);
    expect(player.subtitleScale, 100);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(engine.calls.reversed.take(2), containsAll(['sub-scale 100', 'sub-pos 100']));
    expect(player.subtitleScale, 100);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(player.subtitleScale, greaterThan(100));
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/player/player_menus_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/features/player/player_menus.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../core/media/pan_mode.dart';
import '../../core/media/track_info.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/uhf_menu.dart';
import '../settings/settings_controller.dart';
import '../shell/shell_controller.dart';
import 'player_controller.dart';

String _trackLabel(TrackInfo t, AppLocalizations l) => t.label ?? l.trackNumber(t.id);

List<UhfMenuEntry> audioMenuEntries(PlayerController player, AppLocalizations l) => [
      for (final t in player.audioTracks)
        UhfMenuEntry(label: _trackLabel(t, l), checked: t.selected, onSelected: () => player.selectAudio(t.id)),
    ];

List<UhfMenuEntry> subtitleMenuEntries(PlayerController player, AppLocalizations l) => [
      UhfMenuEntry(
        label: l.subtitlesOff,
        checked: player.selectedSubtitleId == null,
        onSelected: () => player.selectSubtitle(null),
      ),
      for (final t in player.subtitleTracks)
        UhfMenuEntry(label: _trackLabel(t, l), checked: t.selected, onSelected: () => player.selectSubtitle(t.id)),
    ];

List<UhfMenuEntry> moreMenuEntries({
  required PlayerController player,
  required ShellController shell,
  required SettingsController settings,
  required AppLocalizations l,
  required VoidCallback onSubtitleSettings,
}) {
  final language = settings.value.language;
  UhfMenuEntry lang(String code, String label) => UhfMenuEntry(
        label: label,
        checked: language == code,
        onSelected: () => settings.update((s) => s.copyWith(language: code)),
      );
  return [
    UhfMenuEntry(label: l.menuScreenshot, shortcut: 'S', onSelected: player.screenshot),
    UhfMenuEntry(
      label: l.menuMonoLeft,
      checked: player.pan == PanMode.left,
      onSelected: () => player.togglePan(PanMode.left),
    ),
    UhfMenuEntry(
      label: l.menuMonoRight,
      checked: player.pan == PanMode.right,
      onSelected: () => player.togglePan(PanMode.right),
    ),
    UhfMenuEntry(label: l.menuSubtitleSettings, onSelected: onSubtitleSettings),
    UhfMenuEntry(label: l.tooltipPin, checked: shell.alwaysOnTop, onSelected: shell.toggleAlwaysOnTop),
    UhfMenuEntry(label: l.menuLanguage, children: [
      lang('system', l.languageSystem),
      lang('en', 'English'),
      lang('fr', 'Français'),
      lang('tr', 'Türkçe'),
    ]),
  ];
}
```

- [ ] **Step 4: Écrire `lib/features/player/subtitle_settings_dialog.dart`**

```dart
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/typography.dart';
import 'player_controller.dart';

Future<void> showSubtitleSettings(BuildContext context, PlayerController player) async {
  final originalScale = player.subtitleScale;
  final originalPos = player.subtitlePos;
  final applied = await showDialog<bool>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (_) => _SubtitleSettingsDialog(player: player),
  );
  if (applied != true) await player.previewSubtitleStyle(originalScale, originalPos);
}

class _SubtitleSettingsDialog extends StatefulWidget {
  const _SubtitleSettingsDialog({required this.player});

  final PlayerController player;

  @override
  State<_SubtitleSettingsDialog> createState() => _SubtitleSettingsDialogState();
}

class _SubtitleSettingsDialogState extends State<_SubtitleSettingsDialog> {
  late int _scale = widget.player.subtitleScale;
  late int _pos = widget.player.subtitlePos;

  void _preview() => widget.player.previewSubtitleStyle(_scale, _pos);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget row(String label, int value, int min, int max, ValueChanged<int> onChanged) => Row(
          children: [
            SizedBox(width: 72, child: Text(label, style: UhfText.body)),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.right, style: UhfText.mono())),
          ],
        );

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(l.subtitleSize, _scale, 50, 300, (v) {
              setState(() => _scale = v);
              _preview();
            }),
            row(l.subtitlePosition, _pos, 0, 100, (v) {
              setState(() => _pos = v);
              _preview();
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.actionCancel)),
        TextButton(
          onPressed: () async {
            await widget.player.commitSubtitleStyle(_scale, _pos);
            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: Text(l.actionApply),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/player_menus.dart lib/features/player/subtitle_settings_dialog.dart test/features/player/player_menus_test.dart
git commit -m "feat(player): add track menus, more menu and live subtitle settings"
```

---

### Task 12: Contrôles superposés et masquage automatique

**Files:**
- Create: `lib/features/player/controls_visibility.dart`, `lib/features/player/controls_overlay.dart`
- Test: `test/features/player/controls_overlay_test.dart`

**Interfaces:**
- Consumes: `PlayerController`, `ShellController`, `SettingsController`, `Timeline`, `VolumeControl`, `UhfIconButton`, `UhfMenuButton`, menus (tâche 11), `formatTimecode`.
- Produces:
  - `class ControlsVisibility extends ChangeNotifier { ControlsVisibility({Duration hideAfter = UhfDurations.controlsHide}); bool get visible; void poke(); set pinned(bool value); }` — `pinned` (pause ou menu ouvert) garde les contrôles visibles ; sinon `poke()` les affiche et relance le délai.
  - `class ControlsOverlay extends StatelessWidget { const ControlsOverlay({super.key, required PlayerController player, required ShellController shell, required SettingsController settings, required ControlsVisibility visibility, required ValueChanged<bool> onMenuOpenChanged}); }`.

- [ ] **Step 1: Écrire le test**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/controls_overlay.dart';
import 'package:uhf_media/features/player/controls_visibility.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  group('ControlsVisibility', () {
    testWidgets('hides after the delay unless pinned', (tester) async {
      final v = ControlsVisibility(hideAfter: const Duration(milliseconds: 2500));
      v.pinned = false;
      v.poke();
      expect(v.visible, isTrue);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(v.visible, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(v.visible, isFalse);
      v.poke();
      expect(v.visible, isTrue);
      v.pinned = true;
      await tester.pump(const Duration(seconds: 5));
      expect(v.visible, isTrue);
      v.dispose();
    });
  });

  group('ControlsOverlay', () {
    late Directory dir;
    late FakeMediaEngine engine;
    late PlayerController player;
    late SettingsController settings;
    late ShellController shell;
    late FakeWindowHost host;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('uhf_overlay_');
      engine = FakeMediaEngine();
      host = FakeWindowHost();
      player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => true);
      settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
      shell = ShellController(host, settings);
      await player.open(r'C:\v\a.mkv');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Widget overlay(ControlsVisibility v) => harness(Align(
          alignment: Alignment.bottomCenter,
          child: ControlsOverlay(
            player: player,
            shell: shell,
            settings: settings,
            visibility: v,
            onMenuOpenChanged: (_) {},
          ),
        ));

    testWidgets('shows the timecode and drives play and fullscreen', (tester) async {
      final v = ControlsVisibility();
      await tester.pumpWidget(overlay(v));
      engine.emitDuration(const Duration(hours: 1, minutes: 48, seconds: 30));
      engine.emitPosition(const Duration(minutes: 41, seconds: 12));
      await tester.pump();
      expect(find.text('00:41:12'), findsOneWidget);
      expect(find.text('/ 01:48:30'), findsOneWidget);

      engine.calls.clear();
      await tester.tap(find.byTooltip('Play (Space)'));
      await tester.tap(find.byTooltip('Fullscreen (F)'));
      await tester.pump();
      expect(engine.calls, ['play']);
      expect(host.calls, contains('fullscreen true'));
      v.dispose();
    });

    testWidgets('fades out and ignores pointers when hidden', (tester) async {
      final v = ControlsVisibility(hideAfter: const Duration(milliseconds: 100));
      v.pinned = false;
      await tester.pumpWidget(overlay(v));
      v.poke();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
      expect(opacity.opacity, 0);
      expect(tester.widget<IgnorePointer>(find.byKey(const Key('controls-ignore'))).ignoring, isTrue);
      v.dispose();
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/player/controls_overlay_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/features/player/controls_visibility.dart`**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../ui/tokens.dart';

class ControlsVisibility extends ChangeNotifier {
  ControlsVisibility({this.hideAfter = UhfDurations.controlsHide});

  final Duration hideAfter;
  bool _visible = true;
  bool _pinned = true;
  Timer? _timer;

  bool get visible => _visible;

  /// Paused playback or an open menu keeps the controls on screen.
  set pinned(bool value) {
    if (_pinned == value) return;
    _pinned = value;
    if (value) {
      _timer?.cancel();
      _show();
    } else {
      _restart();
    }
  }

  /// Pointer moved: show the controls and restart the hide delay.
  void poke() {
    _show();
    if (!_pinned) _restart();
  }

  void _show() {
    if (_visible) return;
    _visible = true;
    notifyListeners();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(hideAfter, () {
      if (_pinned || !_visible) return;
      _visible = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Écrire `lib/features/player/controls_overlay.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/util/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_icon_button.dart';
import '../../ui/uhf_menu.dart';
import '../settings/settings_controller.dart';
import '../shell/shell_controller.dart';
import 'controls_visibility.dart';
import 'player_controller.dart';
import 'player_menus.dart';
import 'subtitle_settings_dialog.dart';
import 'timeline.dart';
import 'volume_control.dart';

class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({
    super.key,
    required this.player,
    required this.shell,
    required this.settings,
    required this.visibility,
    required this.onMenuOpenChanged,
  });

  final PlayerController player;
  final ShellController shell;
  final SettingsController settings;
  final ControlsVisibility visibility;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, shell, settings, visibility]),
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        return IgnorePointer(
          key: const Key('controls-ignore'),
          ignoring: !visibility.visible,
          child: AnimatedOpacity(
            opacity: visibility.visible ? 1 : 0,
            duration: UhfDurations.base,
            curve: Curves.easeOut,
            child: Container(
              color: UhfColors.ink.withValues(alpha: 0.9),
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Timeline(position: player.position, duration: player.duration, onSeek: player.seekTo),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      UhfIconButton(
                        icon: player.playing ? Symbols.pause_sharp : Symbols.play_arrow_sharp,
                        tooltip: player.playing ? l.tooltipPause : l.tooltipPlay,
                        onPressed: player.togglePlay,
                      ),
                      const SizedBox(width: 10),
                      Text(formatTimecode(player.position), style: UhfText.mono()),
                      const SizedBox(width: 6),
                      Text('/ ${formatTimecode(player.duration)}', style: UhfText.mono(color: UhfColors.textMuted)),
                      const Spacer(),
                      VolumeControl(player: player),
                      const SizedBox(width: 6),
                      if (player.audioTracks.length > 1)
                        UhfMenuButton(
                          icon: Symbols.audiotrack_sharp,
                          tooltip: l.tooltipAudioTrack,
                          entries: audioMenuEntries(player, l),
                          onOpenChanged: onMenuOpenChanged,
                        ),
                      UhfMenuButton(
                        icon: Symbols.subtitles_sharp,
                        tooltip: l.tooltipSubtitles,
                        active: player.selectedSubtitleId != null,
                        entries: subtitleMenuEntries(player, l),
                        onOpenChanged: onMenuOpenChanged,
                      ),
                      UhfMenuButton(
                        icon: Symbols.more_horiz_sharp,
                        tooltip: l.tooltipMore,
                        entries: moreMenuEntries(
                          player: player,
                          shell: shell,
                          settings: settings,
                          l: l,
                          onSubtitleSettings: () => showSubtitleSettings(context, player),
                        ),
                        onOpenChanged: onMenuOpenChanged,
                      ),
                      UhfIconButton(
                        icon: shell.fullscreen ? Symbols.fullscreen_exit_sharp : Symbols.fullscreen_sharp,
                        tooltip: shell.fullscreen ? l.tooltipExitFullscreen : l.tooltipFullscreen,
                        onPressed: shell.toggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/controls_visibility.dart lib/features/player/controls_overlay.dart test/features/player/controls_overlay_test.dart
git commit -m "feat(player): add auto-hiding playback controls overlay"
```

---

### Task 13: Écran principal (scène, dépôt, raccourcis, messages)

**Files:**
- Create: `lib/features/shell/app_shell.dart`
- Test: `test/features/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: tout ce qui précède, `IdleScreen`, `isSubtitleFile`, `isMediaFile`, `formatTimecode`, `DropTarget` (`desktop_drop`).
- Produces: `class AppShell extends StatefulWidget { const AppShell({super.key, required PlayerController player, required ShellController shell, required SettingsController settings, required ToastController toasts, required WidgetBuilder videoBuilder, required Future<String?> Function(String? initialDirectory) pickFile, required void Function(String path) revealFile}); }` et la fonction publique `Future<void> handleDroppedPaths(List<String> paths, PlayerController player)` (testable sans glisser réel).

- [ ] **Step 1: Écrire le test**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/app_shell.dart';
import 'package:uhf_media/features/shell/idle_screen.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/ui/toast.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late FakeWindowHost host;
  late PlayerController player;
  late SettingsController settings;
  late ShellController shell;
  late ToastController toasts;
  late List<String> revealed;
  String? nextPick;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_app_shell_');
    engine = FakeMediaEngine();
    host = FakeWindowHost();
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      desktopDirectory: () async => r'D:\Desk',
      now: () => DateTime(2026, 10, 1, 9, 5, 7),
    );
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    shell = ShellController(host, settings);
    toasts = ToastController();
    revealed = [];
    nextPick = null;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Widget app() => harness(AppShell(
        player: player,
        shell: shell,
        settings: settings,
        toasts: toasts,
        videoBuilder: (_) => const ColoredBox(key: Key('video'), color: Colors.black),
        pickFile: (_) async => nextPick,
        revealFile: revealed.add,
      ));

  testWidgets('idle screen until a file opens, then the video stage', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byType(IdleScreen), findsOneWidget);
    await player.open(r'C:\v\a.mkv');
    await tester.pump();
    expect(find.byKey(const Key('video')), findsOneWidget);
    expect(find.text('a.mkv'), findsOneWidget);
    expect(host.calls, contains('title a.mkv — UHF Media'));
  });

  testWidgets('Ctrl+O opens the picked file and remembers its folder', (tester) async {
    await tester.pumpWidget(app());
    nextPick = r'C:\Films\b.mkv';
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(engine.calls, contains(r'open C:\Films\b.mkv'));
    expect(settings.value.lastOpenDir, r'C:\Films');
  });

  testWidgets('playback shortcuts still work after clicking a control (review focus 3)', (tester) async {
    await tester.pumpWidget(app());
    await player.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    await tester.pump();
    await tester.tap(find.byTooltip('Mute (M)'));
    await tester.pump();
    engine.calls.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(engine.calls, [
      'play',
      'seek ${const Duration(minutes: 1, seconds: 3).inMilliseconds}',
      'volume 85',
      'mute no',
      'frame-step',
    ]);
  });

  testWidgets('F and Esc drive fullscreen, Ctrl+T pins', (tester) async {
    await tester.pumpWidget(app());
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(host.calls, containsAllInOrder(['fullscreen true', 'fullscreen false', 'top true']));
  });

  testWidgets('screenshot shows a toast that reveals the file', (tester) async {
    await tester.pumpWidget(app());
    await player.open(r'C:\v\a.mkv');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(find.text('Screenshot saved'), findsOneWidget);
    await tester.tap(find.text('Show'));
    expect(revealed, [r'D:\Desk\UHF_20261001_090507.png']);
  });

  testWidgets('a failed open shows a toast and stays idle', (tester) async {
    player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => false);
    await tester.pumpWidget(app());
    await player.open(r'C:\v\gone.mkv');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open this file"), findsOneWidget);
    expect(find.byType(IdleScreen), findsOneWidget);
  });

  test('dropped paths: first media opens, subtitles need an open video (review focus 2)', () async {
    await handleDroppedPaths([r'C:\v\notes.txt', r'C:\v\film.srt', r'C:\v\a.mkv', r'C:\v\b.mkv'], player);
    expect(engine.calls.where((c) => c.startsWith('open')), [r'open C:\v\a.mkv']);
    expect(engine.calls.where((c) => c.startsWith('sub-add')), isEmpty);

    final idle = PlayerController(engine: FakeMediaEngine(), resume: ResumeStore(dir), fileExists: (_) => true);
    await handleDroppedPaths([r'C:\v\film.srt'], idle);
    expect(idle.hasMedia, isFalse);

    await handleDroppedPaths([r'C:\v\film.srt'], player);
    expect(engine.calls.last, r'sub-add C:\v\film.srt');
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/features/shell/app_shell_test.dart`
Expected: FAIL, `app_shell.dart` introuvable.

- [ ] **Step 3: Écrire `lib/features/shell/app_shell.dart`**

```dart
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/files/media_files.dart';
import '../../core/util/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/toast.dart';
import '../player/controls_overlay.dart';
import '../player/controls_visibility.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import 'idle_screen.dart';
import 'shell_controller.dart';
import 'title_bar.dart';

/// First media file opens; a subtitle file is added only to an open video.
Future<void> handleDroppedPaths(List<String> paths, PlayerController player) async {
  final media = paths.where(isMediaFile).firstOrNull;
  if (media != null) {
    await player.open(media);
    return;
  }
  final subtitle = paths.where(isSubtitleFile).firstOrNull;
  if (subtitle != null && player.hasMedia) await player.addSubtitle(subtitle);
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.player,
    required this.shell,
    required this.settings,
    required this.toasts,
    required this.videoBuilder,
    required this.pickFile,
    required this.revealFile,
  });

  final PlayerController player;
  final ShellController shell;
  final SettingsController settings;
  final ToastController toasts;
  final WidgetBuilder videoBuilder;
  final Future<String?> Function(String? initialDirectory) pickFile;
  final void Function(String path) revealFile;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _visibility = ControlsVisibility();
  final _focus = FocusNode(debugLabel: 'app-shell');
  late final StreamSubscription<PlayerEvent> _events;
  bool _menuOpen = false;
  String? _shownFile;

  PlayerController get _player => widget.player;
  ShellController get _shell => widget.shell;

  @override
  void initState() {
    super.initState();
    _events = _player.events.listen(_onEvent);
    _player.addListener(_onPlayerChanged);
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    _player.removeListener(_onPlayerChanged);
    _visibility.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onPlayerChanged() {
    _visibility.pinned = !_player.playing || _menuOpen;
    final name = _player.fileName;
    if (name != _shownFile) {
      _shownFile = name;
      unawaited(_shell.setFileName(name));
    }
  }

  void _onMenuOpenChanged(bool open) {
    _menuOpen = open;
    _visibility.pinned = !_player.playing || open;
    if (!open) _focus.requestFocus();
  }

  void _onEvent(PlayerEvent event) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    switch (event) {
      case ResumedEvent(:final position):
        widget.toasts.show(
          l.toastResumed(formatTimecode(position)),
          actionLabel: l.actionRestart,
          onAction: _player.restartFromBeginning,
        );
      case ScreenshotSavedEvent(:final path):
        widget.toasts.show(l.toastScreenshotSaved, actionLabel: l.actionShow, onAction: () => widget.revealFile(path));
      case OpenFailedEvent():
        widget.toasts.show(l.toastOpenFailed);
    }
  }

  Future<void> _open() async {
    final path = await widget.pickFile(widget.settings.value.lastOpenDir);
    if (path == null) return;
    widget.settings.update((s) => s.copyWith(lastOpenDir: p.windows.dirname(path)));
    await _player.open(path);
    _focus.requestFocus();
  }

  Map<ShortcutActivator, VoidCallback> get _bindings => {
        const SingleActivator(LogicalKeyboardKey.space): () => _player.togglePlay(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _player.seekRelative(const Duration(seconds: 3)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _player.seekRelative(const Duration(seconds: -3)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () => _player.frameStep(forward: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () => _player.frameStep(forward: false),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _player.adjustVolume(5),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _player.adjustVolume(-5),
        const SingleActivator(LogicalKeyboardKey.keyM): () => _player.toggleMute(),
        const SingleActivator(LogicalKeyboardKey.keyF): () => _shell.toggleFullscreen(),
        const SingleActivator(LogicalKeyboardKey.escape): () => _shell.exitFullscreen(),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () => _open(),
        const SingleActivator(LogicalKeyboardKey.keyS): () => _player.screenshot(),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () => _shell.toggleAlwaysOnTop(),
      };

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _bindings,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Listener(
          // Any click keeps keyboard focus on the window, never on a control.
          onPointerDown: (_) => _focus.requestFocus(),
          child: DropTarget(
            onDragDone: (details) => handleDroppedPaths([for (final f in details.files) f.path], _player),
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
          ),
        ),
      ),
    );
  }

  Widget _stage(BuildContext context) {
    final hidden = _player.hasMedia && !_visibility.visible;
    return MouseRegion(
      cursor: hidden ? SystemMouseCursors.none : MouseCursor.defer,
      onHover: (_) => _visibility.poke(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_player.hasMedia)
            Listener(
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  _player.adjustVolume(signal.scrollDelta.dy < 0 ? 5 : -5);
                }
              },
              child: GestureDetector(
                onDoubleTap: _shell.toggleFullscreen,
                child: widget.videoBuilder(context),
              ),
            )
          else
            const IdleScreen(),
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
          ToastHost(controller: widget.toasts),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test` puis `flutter analyze`
Expected: `All tests passed!` et `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/shell/app_shell.dart test/features/shell/app_shell_test.dart
git commit -m "feat(shell): add main app shell with stage, drop target, shortcuts and toasts"
```

---

### Task 14: Démarrage (instance unique, fenêtre, assemblage)

**Files:**
- Create: `lib/features/shell/second_instance.dart`, `lib/app/uhf_root.dart`
- Modify: `lib/main.dart`, `windows/runner/flutter_window.cpp`
- Test: `test/features/shell/second_instance_test.dart`, `test/app/uhf_root_test.dart`

**Interfaces:**
- Consumes: tout ce qui précède, `MediaKitEngine`, `WindowManagerHost`, `FfmpegLocator`, `ProbeService`, `KnownFolders`, `revealInExplorer`, `firstExistingFile`, `SettingsStore`, `ResumeStore`, `bindPlayerSettings`, `videoExtensions`, `audioExtensions`.
- Produces:
  - `class SecondInstance { static void deliver(List<String> args); static set listener(void Function(List<String> args)? value); }` — les arguments reçus avant l'enregistrement de l'écouteur sont mis en attente puis rejoués.
  - `void Function(List<String>) secondInstanceHandler({required ShellController shell, required PlayerController player, bool Function(String path)? exists})` — ramène la fenêtre au premier plan puis ouvre le premier fichier existant.
  - `class UhfRoot extends StatelessWidget { const UhfRoot({super.key, required SettingsController settings, required Widget home}); }` — `UhfApp(locale: settings.locale, home: home)`, reconstruit quand la langue change.

- [ ] **Step 1: Écrire les tests**

`test/features/shell/second_instance_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/second_instance.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';

void main() {
  tearDown(() => SecondInstance.listener = null);

  test('arguments received before the listener are replayed', () {
    final seen = <List<String>>[];
    SecondInstance.deliver([r'C:\v\a.mkv']);
    SecondInstance.listener = seen.add;
    SecondInstance.deliver([r'C:\v\b.mkv']);
    expect(seen, [
      [r'C:\v\a.mkv'],
      [r'C:\v\b.mkv'],
    ]);
  });

  test('handler brings the window to front and opens the first existing file (review focus 5)', () async {
    final dir = Directory.systemTemp.createTempSync('uhf_second_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final host = FakeWindowHost();
    final engine = FakeMediaEngine();
    final shell = ShellController(host, SettingsController(SettingsStore(dir), AppSettings.defaults()));
    final player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => true);
    final handle = secondInstanceHandler(shell: shell, player: player, exists: {r'C:\v\b.mkv'}.contains);

    handle(['--flag', r'C:\v\missing.mkv']);
    await Future<void>.delayed(Duration.zero);
    expect(host.calls, ['front']);
    expect(engine.calls.where((c) => c.startsWith('open')), isEmpty);

    handle([r'C:\v\b.mkv']);
    await Future<void>.delayed(Duration.zero);
    expect(engine.calls, contains(r'open C:\v\b.mkv'));
  });
}
```

`test/app/uhf_root_test.dart` :

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_root.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/l10n/app_localizations.dart';

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Text(AppLocalizations.of(context).tooltipClose);
}

void main() {
  testWidgets('language follows the settings live', (tester) async {
    final dir = Directory.systemTemp.createTempSync('uhf_root_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final settings = SettingsController(SettingsStore(dir), AppSettings.defaults().copyWith(language: 'en'));
    await tester.pumpWidget(UhfRoot(settings: settings, home: const _Hint()));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);

    settings.update((s) => s.copyWith(language: 'tr'));
    await tester.pumpAndSettle();
    expect(find.text('Kapat'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `flutter test test/features/shell/second_instance_test.dart test/app/uhf_root_test.dart`
Expected: FAIL, fichiers introuvables.

- [ ] **Step 3: Écrire `lib/features/shell/second_instance.dart`**

```dart
import 'dart:async';

import '../../core/system/launch_args.dart';
import '../player/player_controller.dart';
import 'shell_controller.dart';

/// Bridges windows_single_instance (called before the UI exists) and the app.
abstract final class SecondInstance {
  static void Function(List<String> args)? _listener;
  static final List<List<String>> _pending = [];

  static void deliver(List<String> args) {
    final listener = _listener;
    if (listener == null) {
      _pending.add(args);
    } else {
      listener(args);
    }
  }

  static set listener(void Function(List<String> args)? value) {
    _listener = value;
    if (value == null) return;
    final queued = List.of(_pending);
    _pending.clear();
    for (final args in queued) {
      value(args);
    }
  }
}

void Function(List<String>) secondInstanceHandler({
  required ShellController shell,
  required PlayerController player,
  bool Function(String path)? exists,
}) {
  return (args) {
    unawaited(shell.bringToFront());
    final file = firstExistingFile(args, exists: exists);
    if (file != null) unawaited(player.open(file));
  };
}
```

- [ ] **Step 4: Écrire `lib/app/uhf_root.dart`**

```dart
import 'package:flutter/widgets.dart';

import '../features/settings/settings_controller.dart';
import 'uhf_app.dart';

class UhfRoot extends StatelessWidget {
  const UhfRoot({super.key, required this.settings, required this.home});

  final SettingsController settings;
  final Widget home;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => UhfApp(locale: settings.locale, home: home),
      );
}
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 6: Écrire `lib/main.dart`**

```dart
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app/uhf_root.dart';
import 'core/files/media_files.dart';
import 'core/media/media_kit_engine.dart';
import 'core/settings/resume_store.dart';
import 'core/settings/settings_store.dart';
import 'core/system/ffmpeg_locator.dart';
import 'core/system/known_folders.dart';
import 'core/system/launch_args.dart';
import 'core/system/probe_service.dart';
import 'features/player/player_controller.dart';
import 'features/player/player_settings_binding.dart';
import 'features/settings/settings_controller.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/second_instance.dart';
import 'features/shell/shell_controller.dart';
import 'features/shell/window_manager_host.dart';
import 'ui/toast.dart';
import 'ui/tokens.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // A second launch (double-click on another video) hands its arguments to
  // this instance and exits.
  await WindowsSingleInstance.ensureSingleInstance(
    args,
    'uhf_media_single_instance',
    onSecondWindow: SecondInstance.deliver,
  );
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  final dataDir = Directory(p.join(Platform.environment['APPDATA'] ?? Directory.systemTemp.path, 'UHF Media'));
  final settingsStore = SettingsStore(dataDir);
  final initial = await settingsStore.load();
  final resume = ResumeStore(dataDir);
  await resume.load();

  final settings = SettingsController(settingsStore, initial);
  await WindowManagerHost.configure(initial);
  final host = WindowManagerHost();

  final engine = MediaKitEngine();
  final locator = FfmpegLocator.forCurrentProcess();
  final folders = KnownFolders();
  final player = PlayerController(
    engine: engine,
    resume: resume,
    probe: ProbeService(locator.locate('ffprobe')),
    desktopDirectory: folders.desktop,
    initialVolume: initial.volume,
    initialMuted: initial.muted,
    initialSubtitleScale: initial.subtitleScale,
    initialSubtitlePos: initial.subtitlePos,
  );
  final shell = ShellController(host, settings);
  final toasts = ToastController();
  bindPlayerSettings(player, settings);

  host.onCloseRequested = () async {
    await player.saveResume();
    await settings.flush();
  };

  runApp(UhfRoot(
    settings: settings,
    home: AppShell(
      player: player,
      shell: shell,
      settings: settings,
      toasts: toasts,
      videoBuilder: (_) => Video(
        controller: engine.controller,
        controls: null,
        fill: UhfColors.ink,
        subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
      ),
      pickFile: (initialDirectory) async {
        final files = await FilePicker.pickFiles(
          initialDirectory: initialDirectory,
          type: FileType.custom,
          allowedExtensions: mediaExtensions,
        );
        return files.firstOrNull?.path;
      },
      revealFile: (path) => unawaited(revealInExplorer(path)),
    ),
  ));

  SecondInstance.listener = secondInstanceHandler(shell: shell, player: player);
  final initialFile = firstExistingFile(args);
  if (initialFile != null) unawaited(player.open(initialFile));
}
```

- [ ] **Step 7: Laisser `window_manager` afficher la fenêtre**

Dans `windows/runner/flutter_window.cpp`, dans `FlutterWindow::OnCreate()`, remplacer le bloc :

```cpp
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });
```

par :

```cpp
  // The window is shown by window_manager once its saved size and position
  // are applied (WindowManagerHost.configure), to avoid a flash at the
  // default size.
  flutter_controller_->engine()->SetNextFrameCallback([&]() {});
```

- [ ] **Step 8: Analyse et build**

Run: `flutter analyze` puis `flutter build windows --debug`
Expected: `No issues found!` puis `√ Built build\windows\x64\runner\Debug\uhf_media.exe`

- [ ] **Step 9: Commit**

```bash
git add lib/main.dart lib/app/uhf_root.dart lib/features/shell/second_instance.dart windows/runner/flutter_window.cpp test/features/shell/second_instance_test.dart test/app/uhf_root_test.dart
git commit -m "feat(app): wire single instance, window, media engine and settings at startup"
```

---

### Task 15: Recette manuelle avec de vrais fichiers

**Files:**
- Create: `tool/make_sample_media.ps1`

**Interfaces:**
- Consumes: l'application complète.
- Produces: trois fichiers d'essai dans `%TEMP%\uhf_samples\` et un relevé de recette dans le ledger d'exécution.

- [ ] **Step 1: Écrire `tool/make_sample_media.ps1`**

```powershell
# Generates sample media for manual checks (requires ffmpeg on PATH).
$ErrorActionPreference = 'Stop'
$out = Join-Path $env:TEMP 'uhf_samples'
New-Item -ItemType Directory -Force $out | Out-Null

# 2 min, 1080p, two audio tracks (440 Hz left only, 880 Hz), one subtitle track.
@"
1
00:00:01,000 --> 00:00:30,000
Internal subtitle line

"@ | Set-Content -Encoding utf8 (Join-Path $out 'internal.srt')
ffmpeg -y -v error `
  -f lavfi -i "testsrc2=size=1920x1080:rate=25:duration=120" `
  -f lavfi -i "sine=frequency=440:duration=120" `
  -f lavfi -i "sine=frequency=880:duration=120" `
  -i (Join-Path $out 'internal.srt') `
  -filter_complex "[1:a]pan=stereo|c0=c0|c1=0*c0[left]" `
  -map 0:v -map "[left]" -map 2:a -map 3:s `
  -c:v libx264 -preset veryfast -c:a aac -c:s srt `
  -metadata:s:a:0 language=fre -metadata:s:a:1 language=eng -metadata:s:s:0 language=eng `
  (Join-Path $out 'multi_track.mkv')

# 30 s interlaced (TFF) MPEG-2 in TS.
ffmpeg -y -v error -f lavfi -i "testsrc=size=720x576:rate=25:duration=30" `
  -vf "tinterlace=mode=interleave_top,setfield=tff" -c:v mpeg2video -flags +ilme+ildct -top 1 `
  (Join-Path $out 'interlaced.ts')

# External subtitle to drop on the window.
@"
1
00:00:00,000 --> 00:01:00,000
External subtitle line

"@ | Set-Content -Encoding utf8 (Join-Path $out 'multi_track.fr.srt')

Get-ChildItem $out | Select-Object Name, Length
```

- [ ] **Step 2: Générer les fichiers**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tool/make_sample_media.ps1`
Expected: `multi_track.mkv`, `interlaced.ts`, `internal.srt`, `multi_track.fr.srt` listés, tailles non nulles.

- [ ] **Step 3: Recette (lancer `flutter run -d windows` et cocher chaque point)**

Lancer l'application, puis vérifier, en notant OK/KO pour chaque ligne dans le ledger :

1. Fenêtre sans barre native, à la taille enregistrée ; déplacement par la barre de titre ; double-clic : agrandir / restaurer ; boutons réduire, agrandir, fermer ; bord redimensionnable.
2. `Ctrl+O` ouvre le dialogue filtré ; `multi_track.mkv` s'ouvre et joue ; titre de la fenêtre et de la barre des tâches = `multi_track.mkv — UHF Media`.
3. Les contrôles disparaissent après 2,5 s de lecture sans bouger la souris (curseur masqué), réapparaissent au mouvement, restent visibles en pause et menu ouvert.
4. Timeline : clic, glissement, timecode au survol ; `←`/`→` ±3 s ; `Shift+→` image par image ; `Espace`.
5. Volume : curseur, molette sur la vidéo, `↑`/`↓`, `M`.
6. Menu audio : 2 pistes (FRE, ENG), changement audible (440 Hz → 880 Hz).
7. Sous-titres désactivés à l'ouverture ; menu sous-titres → ENG affiche « Internal subtitle line » ; glisser `multi_track.fr.srt` sur la fenêtre l'ajoute et l'affiche.
8. Réglages des sous-titres : taille et position changent en direct ; *Annuler* rétablit ; *Appliquer* garde, et la valeur est conservée après redémarrage.
9. Mono : la piste FRE n'a du son qu'à gauche ; « Mono depuis le canal gauche » le met dans les deux oreilles ; rouvrir le fichier remet en stéréo.
10. `S` : message « Capture enregistrée » ; *Afficher* ouvre l'Explorateur sur `UHF_…png` dans le Bureau (OneDrive compris), sous-titre visible dans l'image.
11. `F`, double-clic vidéo, `Échap` : plein écran sans barre de titre.
12. `Ctrl+T` et l'épingle : fenêtre au-dessus des autres ; réglage conservé après redémarrage.
13. Fin du fichier : retour au début, en pause.
14. Reprise : fermer à 1:00, relancer, rouvrir → message « Reprise à 00:01:00 » ; *Recommencer* revient à 0.
15. `interlaced.ts` : lecture sans effet de peigne (désentrelacement actif) ; avec ffprobe absent du `PATH`, l'application fonctionne quand même.
16. Instance unique : avec l'application ouverte, lancer `build\windows\x64\runner\Debug\uhf_media.exe "%TEMP%\uhf_samples\interlaced.ts"` → aucune 2ᵉ fenêtre, le fichier s'ouvre dans la 1ʳᵉ, qui passe au premier plan.
17. Langue : menu ⋯ → Langue → Türkçe : textes en turc immédiatement, conservé après redémarrage.
18. Aucune fenêtre de console ne clignote à l'ouverture d'un fichier (appel ffprobe) ni à la capture (appel PowerShell).

- [ ] **Step 4: Corriger chaque point KO**

Pour chaque KO : écrire d'abord un test qui reproduit le défaut quand c'est possible (contrôleurs, widgets), sinon décrire la reproduction manuelle dans le ledger ; corriger ; relancer `flutter test` ; refaire le point. Un KO non corrigé devient une ligne `Ruling:` du ledger avec son coût.

- [ ] **Step 5: Commit**

```bash
git add tool/make_sample_media.ps1
git commit -m "chore: add sample media generator for manual checks"
```

---

## Plans suivants

- **Plan 3 — Studio et musique** : mode Studio (`E`, panneau ancré, timeline de découpe avec `I`/`O` et ±1 s, rotation `R`, cadre de recadrage `C` et ratios, dimensions de sortie), `ExportRunner` (progression `-progress pipe:1`, annulation, repli CPU, fichier partiel supprimé, transcodage audio de secours pour mkv), extraction audio 16 kHz et `Recognizer`, carte de résultat (*Renommer le fichier*, *Copier*, *Annuler*), renommage pendant la lecture (fermer, renommer, rouvrir, migration de la reprise), `Ctrl+I`, `Ctrl+E`, et les mineurs reportés du plan 1 qui touchent ces modules.
- **Plan 4 — Distribution** : `tool/fetch_ffmpeg.ps1`, copie CMake dans le bundle, métadonnées et icône de l'exe, installeur Inno Setup, README définitif, `THIRD_PARTY_NOTICES.md`.
