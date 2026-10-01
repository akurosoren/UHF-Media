import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/app_shell.dart';
import 'package:uhf_media/features/shell/idle_screen.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/ui/toast.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late FakeWindowHost host;
  late PlayerController player;
  late SettingsController settings;
  late ShellController shell;
  late ToastController toasts;
  late List<String> revealed;
  String? nextPick;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_app_shell_');
    engine = FakeMediaEngine();
    host = FakeWindowHost();
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      desktopDirectory: () async => r'D:\Desk',
      now: () => DateTime(2026, 10, 1, 9, 5, 7),
    );
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    shell = ShellController(host, settings);
    toasts = ToastController();
    revealed = [];
    nextPick = null;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  // IdleScreen, ToastController and the debounced settings save own timers:
  // let the debounce fire, then dispose the rest before the test ends.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    toasts.dispose();
  }

  Widget app() => harness(AppShell(
        player: player,
        shell: shell,
        settings: settings,
        toasts: toasts,
        videoBuilder: (_) => const ColoredBox(key: Key('video'), color: Colors.black),
        pickFile: (_) async => nextPick,
        revealFile: revealed.add,
      ));

  testWidgets('idle screen until a file opens, then the video stage', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byType(IdleScreen), findsOneWidget);
    await player.open(r'C:\v\a.mkv');
    await tester.pump();
    expect(find.byKey(const Key('video')), findsOneWidget);
    expect(find.text('a.mkv'), findsOneWidget);
    expect(host.calls, contains('title a.mkv — UHF Media'));
    await finish(tester);
  });

  testWidgets('Ctrl+O opens the picked file and remembers its folder', (tester) async {
    await tester.pumpWidget(app());
    nextPick = r'C:\Films\b.mkv';
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(engine.calls, contains(r'open C:\Films\b.mkv'));
    expect(settings.value.lastOpenDir, r'C:\Films');
    await finish(tester);
  });

  testWidgets('playback shortcuts still work after clicking a control (review focus 3)', (tester) async {
    await tester.pumpWidget(app());
    await player.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    await tester.pump();
    await tester.tap(find.byTooltip('Mute (M)'));
    await tester.pump();
    engine.calls.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(engine.calls, [
      'play',
      'seek ${const Duration(minutes: 1, seconds: 3).inMilliseconds}',
      'volume 85',
      'mute no',
      'frame-step',
    ]);
    await finish(tester);
  });

  testWidgets('F and Esc drive fullscreen, Ctrl+T pins', (tester) async {
    await tester.pumpWidget(app());
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(host.calls, containsAllInOrder(['fullscreen true', 'fullscreen false', 'top true']));
    await finish(tester);
  });

  testWidgets('screenshot shows a toast that reveals the file', (tester) async {
    await tester.pumpWidget(app());
    await player.open(r'C:\v\a.mkv');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(find.text('Screenshot saved'), findsOneWidget);
    await tester.tap(find.text('Show'));
    expect(revealed, [r'D:\Desk\UHF_20261001_090507.png']);
    await finish(tester);
  });

  testWidgets('a failed open shows a toast and stays idle', (tester) async {
    player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => false);
    await tester.pumpWidget(app());
    await player.open(r'C:\v\gone.mkv');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open this file"), findsOneWidget);
    expect(find.byType(IdleScreen), findsOneWidget);
    await finish(tester);
  });

  test('dropped paths: first media opens, subtitles need an open video (review focus 2)', () async {
    await handleDroppedPaths([r'C:\v\notes.txt', r'C:\v\film.srt', r'C:\v\a.mkv', r'C:\v\b.mkv'], player);
    expect(engine.calls.where((c) => c.startsWith('open')), [r'open C:\v\a.mkv']);
    expect(engine.calls.where((c) => c.startsWith('sub-add')), isEmpty);

    final idle = PlayerController(engine: FakeMediaEngine(), resume: ResumeStore(dir), fileExists: (_) => true);
    await handleDroppedPaths([r'C:\v\film.srt'], idle);
    expect(idle.hasMedia, isFalse);

    await handleDroppedPaths([r'C:\v\film.srt'], player);
    expect(engine.calls.last, r'sub-add C:\v\film.srt');
  });
}
