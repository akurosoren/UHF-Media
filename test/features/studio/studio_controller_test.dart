import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/aspect_preset.dart';
import 'package:uhf_media/core/geometry/crop_math.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/studio/studio_controller.dart';
import 'package:uhf_media/features/studio/trim_selection.dart';

import '../../support/fake_exporter.dart';
import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProbeService probeOf(List<Map<String, Object>> streams) => ProbeService(
      'ffprobe',
      run: (_, _) async => ProcessResult(1, 0, jsonEncode({'streams': streams, 'format': {'duration': '600.0'}}), ''),
    );

final videoProbe = probeOf([
  {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
]);

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeExporter exporter;
  late StudioController studio;

  Future<void> openVideo(String path, {ProbeService? probe}) async {
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      probe: probe ?? videoProbe,
      fileExists: (_) => true,
    );
    studio = StudioController(player: player, exporter: exporter);
    await player.open(path);
    engine.emitDuration(const Duration(minutes: 10));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitVideoSize(const IntSize(1920, 1080));
    await settle();
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_studio_');
    engine = FakeMediaEngine();
    exporter = FakeExporter();
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

  test('the studio opens only on a file with a picture (review focus 4)', () async {
    // An audio file: no picture size from ffprobe, none from the engine.
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      probe: probeOf([
        {'index': 0, 'codec_type': 'audio', 'codec_name': 'mp3'},
      ]),
      fileExists: (_) => true,
    );
    final audioOnly = StudioController(player: player, exporter: exporter);
    await player.open(r'C:\m\song.mp3');
    engine.emitDuration(const Duration(minutes: 3));
    await settle();
    expect(audioOnly.available, isFalse);
    audioOnly.toggle();
    expect(audioOnly.isOpen, isFalse);

    await openVideo(r'C:\v\a.mkv');
    expect(studio.available, isTrue);
    studio.toggle();
    expect(studio.isOpen, isTrue);
  });

  test('an audio file with cover art has no studio, even when mpv reports its size (final review)', () async {
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      probe: probeOf([
        {'index': 0, 'codec_type': 'audio', 'codec_name': 'mp3'},
        {
          'index': 1,
          'codec_type': 'video',
          'codec_name': 'mjpeg',
          'width': 500,
          'height': 500,
          'disposition': {'attached_pic': 1},
        },
      ]),
      fileExists: (_) => true,
    );
    final withCover = StudioController(player: player, exporter: exporter);
    await player.open(r'C:\m\song.mp3');
    engine.emitDuration(const Duration(minutes: 3));
    engine.emitVideoSize(const IntSize(500, 500));
    await settle();
    expect(withCover.available, isFalse);
  });

  test('rotation goes through the player and cycles', () async {
    await openVideo(r'C:\v\a.mkv');
    await studio.cycleRotation();
    expect(studio.rotation, Rotation.cw90);
    expect(engine.calls, contains('video-rotate 90'));
    expect(studio.pictureSize, const IntSize(1080, 1920));
    expect(studio.outputSize, const IntSize(1080, 1920));
  });

  test('C turns the crop on with the last preset, centred at 70 %', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggleCrop();
    expect(studio.cropEnabled, isTrue);
    expect(studio.cropPreset, AspectPreset.free);
    expect(studio.crop, CropMath.defaultCrop);
    expect(studio.cropLockRatio, isNull);
    studio.setCropPreset(AspectPreset.r1x1);
    studio.toggleCrop();
    expect(studio.cropEnabled, isFalse);
    studio.toggleCrop();
    expect(studio.cropPreset, AspectPreset.r1x1);
    expect(studio.cropLockRatio, 1);
  });

  test('rotating with a crop refits it to the turned picture (review focus 3)', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.setCropPreset(AspectPreset.r9x16);
    studio.setCrop(const RatioRect(0.6, 0.6, 0.4, 0.4));
    await studio.setRotation(Rotation.cw90);
    expect(studio.crop, CropMath.fitPreset(AspectPreset.r9x16, const IntSize(1080, 1920)));
    final out = studio.outputSize!;
    expect(out.width / out.height, closeTo(9 / 16, 0.01));
  });

  test('the trim starts as 60 s from the position and follows I / O', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggleTrim();
    expect(studio.trim, const TrimSelection(start: Duration(minutes: 1), end: Duration(minutes: 2), duration: Duration(minutes: 10)));
    engine.emitPosition(const Duration(seconds: 90));
    await settle();
    studio.markOut();
    expect(studio.trim!.end, const Duration(seconds: 90));
    studio.toggleTrim();
    expect(studio.trimEnabled, isFalse);
    studio.markIn();
    expect(studio.trim!.start, const Duration(seconds: 90));
  });

  test('O first opens a range ending at the position', () async {
    await openVideo(r'C:\v\a.mkv');
    engine.emitPosition(const Duration(minutes: 5));
    await settle();
    studio.markOut();
    expect(studio.trim, const TrimSelection(start: Duration(minutes: 4), end: Duration(minutes: 5), duration: Duration(minutes: 10)));
  });

  test('nudges move a handle by one second and preview it', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggleTrim();
    engine.calls.clear();
    await studio.nudgeStart(-1);
    expect(studio.trim!.start, const Duration(seconds: 59));
    expect(engine.calls, ['pause', 'seek ${const Duration(seconds: 59).inMilliseconds}']);
    await studio.nudgeEnd(1);
    expect(studio.trim!.end, const Duration(seconds: 121));
  });

  test('opening another file resets the edits but keeps the panel', () async {
    await openVideo(r'C:\v\a.mkv');
    studio.toggle();
    studio.toggleTrim();
    studio.toggleCrop();
    await player.open(r'C:\v\b.mkv');
    await settle();
    expect(studio.isOpen, isTrue);
    expect(studio.trimEnabled, isFalse);
    expect(studio.cropEnabled, isFalse);
    expect(studio.rotation, Rotation.none);
  });
}
