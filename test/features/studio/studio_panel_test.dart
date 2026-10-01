import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/aspect_preset.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';
import 'package:uhf_media/features/studio/studio_panel.dart';
import 'package:uhf_media/features/studio/trim_timeline.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeExporter exporter;
  late StudioController studio;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_studio_panel_');
    engine = FakeMediaEngine();
    exporter = FakeExporter();
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      probe: ProbeService(
        'ffprobe',
        run: (_, _) async => ProcessResult(
          1,
          0,
          jsonEncode({
            'streams': [
              {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
            ],
            'format': {'duration': '600.0'},
          }),
          '',
        ),
      ),
    );
    studio = StudioController(player: player, exporter: exporter);
  });
  // Resume positions are flushed in the background: retry while a write
  // still holds a file open.
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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await player.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitVideoSize(const IntSize(1920, 1080));
    await tester.pumpWidget(harness(Align(
      alignment: Alignment.bottomCenter,
      child: StudioPanel(studio: studio, player: player),
    )));
    await tester.pump();
  }

  testWidgets('rotation chips and output size', (tester) async {
    await pump(tester);
    expect(find.text('1920 × 1080 · 16:9'), findsOneWidget);
    await tester.tap(find.text('90°'));
    await tester.pump();
    expect(studio.rotation, Rotation.cw90);
    expect(find.text('1080 × 1920 · 9:16'), findsOneWidget);
  });

  testWidgets('the trim chip shows the trim timeline and its nudges', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Trim'));
    await tester.pump();
    expect(find.byType(TrimTimeline), findsOneWidget);
    expect(find.text('00:02:00'), findsOneWidget);
    await tester.tap(find.byTooltip('+1 s').first);
    await tester.pump();
    expect(studio.trim!.start, const Duration(seconds: 61));
  });

  testWidgets('the crop menu picks a ratio', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Crop (C)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
    expect(studio.cropPreset, AspectPreset.r1x1);
    expect(find.text('756 × 756 · 1:1'), findsOneWidget);
  });

  testWidgets('exporting replaces the row with progress and Cancel', (tester) async {
    await pump(tester);
    await tester.tap(find.text('90°'));
    await tester.pump();
    await tester.tap(find.text('Export'));
    await tester.pump();
    await tester.pump();
    expect(exporter.lastInput, isNotNull);
    expect(find.text('0 %'), findsOneWidget);
    expect(find.text('90°'), findsNothing);
    exporter.progress!(0.42);
    await tester.pump();
    expect(find.text('42 %'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump();
    expect(exporter.cancelled, isTrue);
    expect(find.text('Export'), findsOneWidget);
  });
}
