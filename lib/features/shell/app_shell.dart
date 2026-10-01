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
