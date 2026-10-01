import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/system/music_recognizer.dart';
import 'package:uhf_media/features/music_id/music_id_controller.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/app_shell.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/ui/toast.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_music_identifier.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeMusicIdentifier identifier;
  late MusicIdController music;
  late ToastController toasts;
  late SettingsController settings;
  late List<String> renames;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_shell_music_');
    engine = FakeMediaEngine();
    renames = [];
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      renameFile: (from, to) async => renames.add('$from>$to'),
    );
    identifier = FakeMusicIdentifier();
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    music = MusicIdController(player: player, identifier: identifier, settings: settings, exists: (_) => false);
    toasts = ToastController();
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

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(AppShell(
      player: player,
      shell: ShellController(FakeWindowHost(), settings),
      settings: settings,
      toasts: toasts,
      music: music,
      videoBuilder: (_) => const ColoredBox(color: Colors.black),
      pickFile: (_) async => null,
      revealFile: (_) {},
    )));
    await player.open(r'C:\m\track01.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    await tester.pump();
  }

  Future<void> identify(WidgetTester tester, MusicOutcome outcome) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('Listening…'), findsOneWidget);
    identifier.pending!.complete(outcome);
    await tester.pump();
    await tester.pump();
    // Let the card finish springing in before the tests tap it.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Ctrl+I shows the card; Copy puts "Artist - Title" on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpShell(tester);
    await identify(tester, const MusicFound(RecognitionResult(title: 'Gülümse', artist: 'Sezen Aksu')));
    expect(find.text('Sezen Aksu'), findsOneWidget);
    expect(find.text('Gülümse'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, 'Sezen Aksu - Gülümse');
    await finish(tester);
  });

  testWidgets('Rename the file renames it and offers Undo', (tester) async {
    await pumpShell(tester);
    await identify(tester, const MusicFound(RecognitionResult(title: 'Gülümse', artist: 'Sezen Aksu')));
    await tester.tap(find.text('Rename the file'));
    await tester.pump();
    await tester.pump();
    expect(renames, [r'C:\m\track01.mp3>C:\m\Sezen Aksu - Gülümse.mp3']);
    expect(find.text('Renamed to Sezen Aksu - Gülümse.mp3'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('nothing recognized shows a message and no card', (tester) async {
    await pumpShell(tester);
    await identify(tester, const MusicNotFound());
    expect(find.text('No song recognized'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    await finish(tester);
  });

  testWidgets('the more menu identifies music and toggles automatic rename', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename automatically after identification'));
    await tester.pumpAndSettle();
    expect(settings.value.autoRename, isTrue);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Identify music'));
    // The equalizer animates while listening: pumpAndSettle would never end.
    await tester.pump(const Duration(milliseconds: 300));
    expect(identifier.calls, hasLength(1));
    identifier.pending!.complete(const MusicNotFound());
    await finish(tester);
  });
}
