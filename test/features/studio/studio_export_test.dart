import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/export_runner.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final _probe = ProbeService(
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
);

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeExporter exporter;
  late StudioController studio;
  late List<StudioEvent> events;
  var clock = DateTime(2026, 10, 1, 12);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('uhf_studio_export_');
    engine = FakeMediaEngine();
    exporter = FakeExporter();
    events = [];
    clock = DateTime(2026, 10, 1, 12);
    player = PlayerController(engine: engine, resume: ResumeStore(dir), probe: _probe, fileExists: (_) => true);
    studio = StudioController(player: player, exporter: exporter, now: () => clock);
    studio.events.listen(events.add);
    engine.tracks = const [
      TrackInfo(type: TrackType.video, id: 1, ffIndex: 0, selected: true),
      TrackInfo(type: TrackType.audio, id: 2, ffIndex: 2, selected: true),
    ];
    await player.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitVideoSize(const IntSize(1920, 1080));
    engine.emitTracksChanged();
    await settle();
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

  test('nothing to export is rejected without pausing', () async {
    engine.calls.clear();
    await studio.export();
    await settle();
    expect(events.single, isA<ExportRejectedEvent>().having((e) => e.error, 'error', ExportPlanError.noChanges));
    expect(exporter.lastInput, isNull);
    expect(engine.calls, isNot(contains('pause')));
  });

  test('without ffmpeg the event names the expected folder', () async {
    exporter.isAvailable = false;
    await studio.setRotation(Rotation.cw90);
    await studio.export();
    await settle();
    expect(events.single, isA<FfmpegMissingEvent>().having((e) => e.folder, 'folder', r'C:\App'));
  });

  test('export sends the edits in source pixels, pauses and reports progress', () async {
    await studio.setRotation(Rotation.cw90);
    studio.toggleCrop();
    studio.toggleTrim();
    engine.calls.clear();
    final done = studio.export();
    await settle();
    expect(studio.exporting, isTrue);
    expect(engine.calls, contains('pause'));
    final input = exporter.lastInput!;
    expect(input.inputPath, r'C:\v\a.mkv');
    expect(input.rotation, Rotation.cw90);
    expect(input.crop, CropMath.displayToSource(CropMath.defaultCrop, Rotation.cw90, const IntSize(1920, 1080)));
    expect(input.trim!.start, const Duration(minutes: 1));
    expect(input.trim!.end, const Duration(minutes: 2));
    expect(input.videoFfIndex, 0);
    expect(input.audioFfIndex, 2);

    clock = clock.add(const Duration(seconds: 10));
    exporter.progress!(0.25);
    expect(studio.exportProgress!.fraction, 0.25);
    expect(studio.exportProgress!.remaining, const Duration(seconds: 30));

    exporter.cpuRetry!();
    exporter.pending!.complete(const ExportSucceeded(r'C:\v\a_crop_rot90_trim.mkv'));
    await done;
    await settle();
    expect(studio.exporting, isFalse);
    expect(events[0], isA<ExportRetriedOnCpuEvent>());
    expect(events[1], isA<ExportFinishedEvent>().having((e) => e.path, 'path', r'C:\v\a_crop_rot90_trim.mkv'));
  });

  test('cancel stops the export and reports it', () async {
    await studio.setRotation(Rotation.half);
    final done = studio.export();
    await settle();
    studio.cancelExport();
    await done;
    await settle();
    expect(exporter.cancelled, isTrue);
    expect(events.last, isA<ExportCancelledEvent>());
    expect(studio.exporting, isFalse);
  });

  test('a failure carries the ffmpeg log', () async {
    await studio.setRotation(Rotation.half);
    final done = studio.export();
    await settle();
    exporter.pending!.complete(const ExportFailed('Unknown encoder'));
    await done;
    await settle();
    expect(events.last, isA<ExportFailedEvent>().having((e) => e.log, 'log', 'Unknown encoder'));
  });

  test('a plan rejected by the builder becomes an event', () async {
    exporter.error = const ExportPlanException(ExportPlanError.cropTooSmall);
    studio.toggleCrop();
    await studio.export();
    await settle();
    expect(events.last, isA<ExportRejectedEvent>().having((e) => e.error, 'error', ExportPlanError.cropTooSmall));
    expect(studio.exporting, isFalse);
  });

  test('opening another file during an export keeps it running (review focus 1)', () async {
    await studio.setRotation(Rotation.cw90);
    final done = studio.export();
    await settle();
    await player.open(r'C:\v\b.mkv');
    await settle();
    expect(studio.exporting, isTrue);
    expect(studio.rotation, Rotation.none);
    exporter.pending!.complete(const ExportSucceeded(r'C:\v\a_rot90.mkv'));
    await done;
    await settle();
    expect(events.last, isA<ExportFinishedEvent>().having((e) => e.path, 'path', r'C:\v\a_rot90.mkv'));
  });

  test('shutdown cancels a running export and waits for it', () async {
    await studio.setRotation(Rotation.cw90);
    unawaited(studio.export());
    await settle();
    await studio.shutdown();
    expect(exporter.cancelled, isTrue);
    expect(studio.exporting, isFalse);
  });
}
