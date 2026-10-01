import 'dart:async';
import 'dart:io';
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
      // Native teardown after the message loop ends takes ~6 s (window still
      // on screen, single-instance mutex still held). Everything is saved by
      // now, so end the process at once.
      exit(0);
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
