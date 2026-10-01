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
