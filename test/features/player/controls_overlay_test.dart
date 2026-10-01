import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/controls_overlay.dart';
import 'package:uhf_media/features/player/controls_visibility.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  group('ControlsVisibility', () {
    testWidgets('hides after the delay unless pinned', (tester) async {
      final v = ControlsVisibility(hideAfter: const Duration(milliseconds: 2500));
      v.pinned = false;
      v.poke();
      expect(v.visible, isTrue);
      await tester.pump(const Duration(milliseconds: 2400));
      expect(v.visible, isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(v.visible, isFalse);
      v.poke();
      expect(v.visible, isTrue);
      v.pinned = true;
      await tester.pump(const Duration(seconds: 5));
      expect(v.visible, isTrue);
      v.dispose();
    });
  });

  group('ControlsOverlay', () {
    late Directory dir;
    late FakeMediaEngine engine;
    late PlayerController player;
    late SettingsController settings;
    late ShellController shell;
    late FakeWindowHost host;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('uhf_overlay_');
      engine = FakeMediaEngine();
      host = FakeWindowHost();
      player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => true);
      settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
      shell = ShellController(host, settings);
      await player.open(r'C:\v\a.mkv');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Widget overlay(ControlsVisibility v) => harness(Align(
          alignment: Alignment.bottomCenter,
          child: ControlsOverlay(
            player: player,
            shell: shell,
            settings: settings,
            visibility: v,
            onMenuOpenChanged: (_) {},
          ),
        ));

    testWidgets('shows the timecode and drives play and fullscreen', (tester) async {
      final v = ControlsVisibility();
      await tester.pumpWidget(overlay(v));
      engine.emitDuration(const Duration(hours: 1, minutes: 48, seconds: 30));
      engine.emitPosition(const Duration(minutes: 41, seconds: 12));
      await tester.pump();
      expect(find.text('00:41:12'), findsOneWidget);
      expect(find.text('/ 01:48:30'), findsOneWidget);

      engine.calls.clear();
      await tester.tap(find.byTooltip('Play (Space)'));
      await tester.tap(find.byTooltip('Fullscreen (F)'));
      await tester.pump();
      expect(engine.calls, ['play']);
      expect(host.calls, contains('fullscreen true'));
      v.dispose();
    });

    testWidgets('fades out and ignores pointers when hidden', (tester) async {
      final v = ControlsVisibility(hideAfter: const Duration(milliseconds: 100));
      v.pinned = false;
      await tester.pumpWidget(overlay(v));
      v.poke();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(of: find.byKey(const Key('controls-ignore')), matching: find.byType(AnimatedOpacity)).first,
      );
      expect(opacity.opacity, 0);
      expect(tester.widget<IgnorePointer>(find.byKey(const Key('controls-ignore'))).ignoring, isTrue);
      v.dispose();
    });
  });
}
