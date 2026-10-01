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
