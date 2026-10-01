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
