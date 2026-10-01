import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/ffmpeg/export_plan.dart';
import '../../core/geometry/crop_math.dart';
import '../../core/geometry/rotation.dart';
import '../../core/files/media_files.dart';
import '../../core/util/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/toast.dart';
import '../music_id/music_id_controller.dart';
import '../music_id/music_result_card.dart';
import '../player/controls_overlay.dart';
import '../player/controls_visibility.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';
import '../studio/crop_overlay.dart';
import '../studio/studio_controller.dart';
import '../studio/studio_panel.dart';
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
    this.studio,
    this.music,
  });

  final PlayerController player;
  final ShellController shell;
  final SettingsController settings;
  final ToastController toasts;
  final WidgetBuilder videoBuilder;
  final Future<String?> Function(String? initialDirectory) pickFile;
  final void Function(String path) revealFile;
  final StudioController? studio;
  final MusicIdController? music;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _visibility = ControlsVisibility();
  final _focus = FocusNode(debugLabel: 'app-shell');
  // Under the video in the studio: always shown.
  final _studioVisibility = ControlsVisibility();
  StreamSubscription<StudioEvent>? _studioEvents;
  StreamSubscription<MusicEvent>? _musicEvents;

  StudioController? get _studio => widget.studio;
  bool get _studioOpen => _studioShown;

  /// The panel stays open across files but shows only for a file with a
  /// picture (or while an export of a previous file is still running).
  bool get _studioShown {
    final studio = _studio;
    return studio != null && studio.isOpen && _player.hasMedia && (studio.available || studio.exporting);
  }

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
    _studioEvents = _studio?.events.listen(_onStudioEvent);
    _musicEvents = widget.music?.events.listen(_onMusicEvent);
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    unawaited(_studioEvents?.cancel());
    unawaited(_musicEvents?.cancel());
    _studioVisibility.dispose();
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

  void _inStudio(void Function(StudioController studio) action) {
    final studio = _studio;
    if (studio != null && _studioShown) action(studio);
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
    const SingleActivator(LogicalKeyboardKey.keyE, includeRepeats: false): () => _studio?.toggle(),
    const SingleActivator(LogicalKeyboardKey.keyI): () => _inStudio((s) => s.markIn()),
    const SingleActivator(LogicalKeyboardKey.keyO): () => _inStudio((s) => s.markOut()),
    const SingleActivator(LogicalKeyboardKey.keyR, includeRepeats: false): () => _inStudio((s) => s.cycleRotation()),
    const SingleActivator(LogicalKeyboardKey.keyC, includeRepeats: false): () => _inStudio((s) => s.toggleCrop()),
    const SingleActivator(LogicalKeyboardKey.keyE, control: true): () => _inStudio((s) => s.export()),
    const SingleActivator(LogicalKeyboardKey.keyI, control: true): () => widget.music?.identify(),
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
              listenable: Listenable.merge([_player, _shell, _visibility, ?_studio]),
              builder: (context, _) {
                final studio = _studio;
                final docked = studio != null && _studioShown && !_shell.fullscreen;
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
                          music: widget.music,
                        ),
                        StudioPanel(studio: studio, player: _player, onMenuOpenChanged: _onMenuOpenChanged),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage(BuildContext context) {
    final studio = _studio;
    final hidden = _player.hasMedia && !_studioOpen && !_visibility.visible;
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
              child: GestureDetector(onDoubleTap: _shell.toggleFullscreen, child: widget.videoBuilder(context)),
            )
          else
            const IdleScreen(),
          if (studio != null && _studioShown && studio.cropEnabled) _cropLayer(studio),
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
                music: widget.music,
              ),
            ),
          if (widget.music != null)
            Positioned(
              left: 14,
              bottom: 140,
              child: MusicResultCard(
                music: widget.music!,
                onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
              ),
            ),
          ToastHost(controller: widget.toasts),
        ],
      ),
    );
  }

  /// The crop frame sits exactly on the picture, letterboxed like the video.
  Widget _cropLayer(StudioController studio) => LayoutBuilder(
    builder: (context, constraints) {
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
    },
  );
}
