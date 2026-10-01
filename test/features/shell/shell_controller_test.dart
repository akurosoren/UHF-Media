import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/features/shell/window_host.dart';

import '../../support/fake_window_host.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory dir;
  late FakeWindowHost host;
  late SettingsController settings;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_shell_');
    host = FakeWindowHost();
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults().copyWith(alwaysOnTop: true));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('initial state comes from the settings', () {
    final shell = ShellController(host, settings);
    expect(shell.alwaysOnTop, isTrue);
    expect(shell.maximized, isFalse);
    expect(shell.fullscreen, isFalse);
  });

  test('fullscreen toggles and exits', () async {
    final shell = ShellController(host, settings);
    await shell.toggleFullscreen();
    expect(shell.fullscreen, isTrue);
    await shell.exitFullscreen();
    expect(shell.fullscreen, isFalse);
    await shell.exitFullscreen();
    expect(host.calls, ['fullscreen true', 'fullscreen false']);
  });

  test('always on top toggles and is saved', () async {
    final shell = ShellController(host, settings);
    await shell.toggleAlwaysOnTop();
    expect(shell.alwaysOnTop, isFalse);
    expect(settings.value.alwaysOnTop, isFalse);
    expect(host.calls, ['top false']);
  });

  test('maximize follows window events and is saved', () async {
    final shell = ShellController(host, settings);
    await shell.toggleMaximize();
    expect(host.calls, ['maximize']);
    host.emit(WindowEvent.maximized);
    await settle();
    expect(shell.maximized, isTrue);
    expect(settings.value.maximized, isTrue);
    await shell.toggleMaximize();
    expect(host.calls.last, 'unmaximize');
  });

  test('bounds are saved only for a normal window', () async {
    final shell = ShellController(host, settings);
    host.bounds = const Rect.fromLTWH(10, 20, 900, 600);
    host.emit(WindowEvent.boundsChanged);
    await settle();
    expect(settings.value.windowX, 10);
    expect(settings.value.windowWidth, 900);

    host.emit(WindowEvent.maximized);
    await settle();
    host.bounds = const Rect.fromLTWH(0, 0, 1920, 1080);
    host.emit(WindowEvent.boundsChanged);
    await settle();
    expect(settings.value.windowWidth, 900);
    expect(shell.maximized, isTrue);
  });

  test('title shows the file name', () async {
    final shell = ShellController(host, settings);
    await shell.setFileName('clip.mkv');
    await shell.setFileName(null);
    expect(host.calls, ['title clip.mkv — UHF Media', 'title UHF Media']);
  });
}
