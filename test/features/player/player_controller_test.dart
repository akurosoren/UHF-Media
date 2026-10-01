import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/player/player_settings_binding.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';

import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late ResumeStore resume;
  late List<PlayerEvent> events;

  PlayerController make({ProbeService? probe, bool Function(String)? exists}) {
    final c = PlayerController(
      engine: engine,
      resume: resume,
      probe: probe,
      desktopDirectory: () async => r'D:\Desk',
      now: () => DateTime(2026, 10, 1, 9, 5, 7),
      fileExists: exists ?? (_) => true,
    );
    c.events.listen(events.add);
    return c;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_player_');
    engine = FakeMediaEngine();
    resume = ResumeStore(dir);
    events = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('open resets pan, turns subtitles off via the engine and applies subtitle style', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    expect(c.hasMedia, isTrue);
    expect(c.fileName, 'a.mkv');
    expect(c.pan, PanMode.stereo);
    expect(engine.calls, containsAllInOrder(['af ', r'open C:\v\a.mkv', 'sub-scale 100', 'sub-pos 100', 'deinterlace no']));
  });

  test('a missing file emits OpenFailedEvent without touching the engine', () async {
    final c = make(exists: (_) => false);
    await c.open(r'C:\v\gone.mkv');
    await settle();
    expect(events.single, isA<OpenFailedEvent>());
    expect(engine.calls.where((x) => x.startsWith('open')), isEmpty);
    expect(c.hasMedia, isFalse);
  });

  test('an engine error before the duration is known closes the file', () async {
    final c = make();
    await c.open(r'C:\v\broken.mkv');
    engine.emitError('Failed to open');
    await settle();
    expect(events.single, isA<OpenFailedEvent>());
    expect(c.hasMedia, isFalse);
  });

  test('resume applies once when the duration first arrives (review focus 1)', () async {
    resume.record(r'C:\v\b.mkv', const Duration(minutes: 41));
    final c = make();
    await c.open(r'C:\v\b.mkv');
    engine.emitDuration(const Duration(hours: 2));
    await settle();
    engine.emitDuration(const Duration(hours: 2));
    await settle();
    expect(engine.calls.where((x) => x == 'seek ${const Duration(minutes: 41).inMilliseconds}').length, 1);
    expect(events.whereType<ResumedEvent>().single.position, const Duration(minutes: 41));
    expect(c.duration, const Duration(hours: 2));
  });

  test('opening a second file saves the first position and resets pan (review focus 1)', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(hours: 1));
    engine.emitPosition(const Duration(minutes: 20));
    await settle();
    await c.togglePan(PanMode.left);
    await c.open(r'C:\v\b.mkv');
    expect(resume.resumePositionFor(r'C:\v\a.mkv', const Duration(hours: 1)), const Duration(minutes: 20));
    expect(c.pan, PanMode.stereo);
    expect(c.position, Duration.zero);
  });

  test('a failing resume save does not block opening the next file', () async {
    // resume.json cannot be written: its folder path goes through a file.
    final blocker = File('${dir.path}/blocker')..writeAsStringSync('');
    resume = ResumeStore(Directory('${blocker.path}/sub'));
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.emitDuration(const Duration(hours: 1));
    engine.emitPosition(const Duration(minutes: 20));
    await settle();
    await c.open(r'C:\v\b.mkv');
    expect(engine.calls, contains(r'open C:\v\b.mkv'));
    expect(c.fileName, 'b.mkv');
  });

  test('positions are recorded every 5 seconds', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    for (final s in [1, 3, 6, 8, 12]) {
      engine.emitPosition(Duration(seconds: s));
    }
    await settle();
    expect(resume.resumePositionFor(r'C:\v\a.mkv', const Duration(hours: 1)), const Duration(seconds: 12));
    expect(c.position, const Duration(seconds: 12));
  });

  test('end of file seeks to the start, pauses and forgets the position', () async {
    resume.record(r'C:\v\a.mkv', const Duration(minutes: 5));
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.calls.clear();
    engine.emitCompleted(true);
    await settle();
    expect(engine.calls, ['seek 0', 'pause']);
    expect(resume.resumePositionFor(r'C:\v\a.mkv', const Duration(hours: 1)), isNull);
  });

  test('seekRelative stays within [0, duration], including unknown duration (review focus 4)', () async {
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.emitPosition(const Duration(seconds: 2));
    await settle();
    engine.calls.clear();
    await c.seekRelative(const Duration(seconds: -3));
    await c.seekRelative(const Duration(seconds: 3));
    expect(engine.calls, ['seek 0', 'seek 0']);
    engine.emitDuration(const Duration(seconds: 4));
    await settle();
    engine.calls.clear();
    await c.seekRelative(const Duration(seconds: 3));
    expect(engine.calls, ['seek 4000']);
  });

  test('volume is clamped and mute toggles', () async {
    final c = make();
    await c.setVolume(140);
    expect(c.volume, 100);
    await c.adjustVolume(-5);
    expect(c.volume, 95);
    await c.adjustVolume(-200);
    expect(c.volume, 0);
    await c.toggleMute();
    expect(c.muted, isTrue);
    expect(engine.calls, containsAllInOrder(['volume 100', 'volume 95', 'volume 0', 'mute yes']));
  });

  test('tracks are read when the engine reports a change', () async {
    engine.tracks = const [
      TrackInfo(type: TrackType.audio, id: 1, selected: true),
      TrackInfo(type: TrackType.audio, id: 2),
      TrackInfo(type: TrackType.subtitle, id: 1, selected: true),
    ];
    final c = make();
    await c.open(r'C:\v\a.mkv');
    engine.emitTracksChanged();
    await settle();
    expect(c.audioTracks.map((t) => t.id), [1, 2]);
    expect(c.subtitleTracks.length, 1);
    expect(c.selectedSubtitleId, 1);
    await c.selectSubtitle(null);
    await c.selectAudio(2);
    expect(engine.calls, containsAllInOrder(['sid no', 'aid 2']));
  });

  test('pan toggles between a channel and stereo', () async {
    final c = make();
    await c.togglePan(PanMode.left);
    expect(c.pan, PanMode.left);
    await c.togglePan(PanMode.right);
    expect(c.pan, PanMode.right);
    await c.togglePan(PanMode.right);
    expect(c.pan, PanMode.stereo);
  });

  test('interlaced sources enable deinterlacing', () async {
    final probe = ProbeService('ffprobe', run: (_, _) async => ProcessResult(
          1,
          0,
          '{"streams":[{"index":0,"codec_type":"video","field_order":"tt"}],"format":{}}',
          '',
        ));
    final c = make(probe: probe);
    await c.open(r'C:\v\a.ts');
    expect(engine.calls.last, 'deinterlace yes');
  });

  test('screenshot writes to the desktop with a timestamped name', () async {
    final c = make();
    await c.screenshot();
    expect(engine.calls.where((x) => x.startsWith('screenshot')), isEmpty);
    await c.open(r'C:\v\a.mkv');
    await c.screenshot();
    await settle();
    expect(engine.calls.last, r'screenshot D:\Desk\UHF_20261001_090507.png');
    expect((events.last as ScreenshotSavedEvent).path, r'D:\Desk\UHF_20261001_090507.png');
  });

  test('subtitle preview does not persist; commit does', () async {
    final c = make();
    engine.calls.clear();
    await c.previewSubtitleStyle(150, 80);
    expect(c.subtitleScale, 100);
    expect(engine.calls, ['sub-scale 150', 'sub-pos 80']);
    await c.commitSubtitleStyle(150, 80);
    expect(c.subtitleScale, 150);
    expect(c.subtitlePos, 80);
  });

  test('bindPlayerSettings copies volume and subtitle style into settings', () async {
    final settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    final c = make();
    bindPlayerSettings(c, settings);
    await c.setVolume(33);
    await c.toggleMute();
    await c.commitSubtitleStyle(120, 90);
    expect(settings.value.volume, 33);
    expect(settings.value.muted, isTrue);
    expect(settings.value.subtitleScale, 120);
    expect(settings.value.subtitlePos, 90);
  });
}
