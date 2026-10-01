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

    // Poll: under a loaded parallel test run the debounced write can land late.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    var saved = (await store.load()).volume;
    while (saved != 42 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      saved = (await store.load()).volume;
    }
    expect(saved, 42);
  });

  test('flush waits for a debounced save already in flight (final review)', () async {
    final store = SettingsStore(dir);
    final ctrl = SettingsController(store, AppSettings.defaults(), debounce: Duration.zero);
    ctrl.update((s) => s.copyWith(volume: 42));
    // Let the debounce timer fire and start writing.
    await Future<void>.delayed(Duration.zero);
    await ctrl.flush();
    // The app exits right after flush(): the file must already be complete.
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
