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

  test('a corrupted file that cannot be set aside still gives defaults (final review)', () async {
    File('${dir.path}/settings.json').writeAsStringSync('{ not json');
    // The .bak name is taken by a folder, so the rename fails.
    Directory('${dir.path}/settings.json.bak/keep').createSync(recursive: true);
    final s = await SettingsStore(dir).load();
    expect(s.volume, 80);
  });

  test('non UTF-8 file gives defaults and is kept as .bak', () async {
    File('${dir.path}/settings.json').writeAsBytesSync([0x7B, 0x22, 0xE9, 0x22, 0x3A, 0x31, 0x7D]);
    final s = await SettingsStore(dir).load();
    expect(s.volume, 80);
    expect(File('${dir.path}/settings.json.bak').existsSync(), isTrue);
  });

  test('overlapping saves all complete and the last one wins', () async {
    final store = SettingsStore(dir);
    await Future.wait([
      for (var i = 0; i <= 20; i++) store.save(AppSettings.defaults().copyWith(volume: i.toDouble())),
    ]);
    expect((await store.load()).volume, 20);
  });
}
