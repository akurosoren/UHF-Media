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
