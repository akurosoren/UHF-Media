import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/app_shell.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/features/studio/crop_overlay.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';
import 'package:uhf_media/features/studio/studio_panel.dart';
import 'package:uhf_media/features/studio/trim_timeline.dart';
import 'package:uhf_media/ui/toast.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late StudioController studio;
  late ToastController toasts;
  late SettingsController settings;
  late ShellController shell;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_shell_studio_');
    engine = FakeMediaEngine();
    player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => true);
    studio = StudioController(player: player, exporter: FakeExporter());
    toasts = ToastController();
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    shell = ShellController(FakeWindowHost(), settings);
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    toasts.dispose();
  }

  Future<void> pumpShell(WidgetTester tester, {bool withPicture = true}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(AppShell(
      player: player,
      shell: shell,
      settings: settings,
      toasts: toasts,
      studio: studio,
      videoBuilder: (_) => const ColoredBox(key: Key('video'), color: Colors.black),
      pickFile: (_) async => null,
      revealFile: (_) {},
    )));
    await player.open(withPicture ? r'C:\v\a.mkv' : r'C:\m\song.mp3');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    if (withPicture) engine.emitVideoSize(const IntSize(1920, 1080));
    await tester.pump();
  }

  testWidgets('E opens the studio; R, I and C act inside it', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byType(StudioPanel), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(engine.calls, contains('video-rotate 90'));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    expect(find.byType(TrimTimeline), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(find.byType(CropOverlay), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byType(StudioPanel), findsNothing);
    await finish(tester);
  });

  testWidgets('studio keys do nothing outside the studio', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(engine.calls, isNot(contains('video-rotate 90')));
    expect(find.byType(CropOverlay), findsNothing);
    await finish(tester);
  });

  testWidgets('Ctrl+E without edits explains what to choose', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump();
    expect(find.text('Choose a rotation, a crop or a trim first'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the studio button opens the panel', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('Studio (E)'));
    await tester.pump();
    expect(find.byType(StudioPanel), findsOneWidget);
    await finish(tester);
  });

  testWidgets('switching to an audio file hides the open studio (final review)', (tester) async {
    await pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byType(StudioPanel), findsOneWidget);
    // Opening saves the resume file for real: let that IO finish.
    await tester.runAsync(() => player.open(r'C:\m\song.mp3'));
    await tester.pump();
    expect(find.byType(StudioPanel), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(engine.calls, isNot(contains('video-rotate 90')));
    await finish(tester);
  });

  testWidgets('an audio file has no studio (review focus 4)', (tester) async {
    await pumpShell(tester, withPicture: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byType(StudioPanel), findsNothing);
    await finish(tester);
  });
}
