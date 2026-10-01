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
  Future<bool> isMaximized();
}
