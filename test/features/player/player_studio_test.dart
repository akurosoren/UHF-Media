import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/system/probe_service.dart';
import 'package:uhf_media/features/player/player_controller.dart';

import '../../support/fake_media_engine.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProbeService _probe() => ProbeService(
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
  late ResumeStore resume;
  late List<PlayerEvent> events;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_player_studio_');
    engine = FakeMediaEngine();
    resume = ResumeStore(dir);
    events = [];
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

  PlayerController make({Future<void> Function(String from, String to)? renameFile}) {
    final c = PlayerController(
      engine: engine,
      resume: resume,
      probe: _probe(),
      fileExists: (_) => true,
      renameFile: renameFile,
    );
    c.events.listen(events.add);
    return c;
  }

  test('open resets the rotation, keeps the probe and exposes the selected ff-indexes', () async {
    final c = make();
    await c.setRotation(Rotation.cw90);
    expect(c.rotation, Rotation.cw90);
    engine.tracks = const [
      TrackInfo(type: TrackType.video, id: 1, ffIndex: 0, selected: true),
      TrackInfo(type: TrackType.audio, id: 1, ffIndex: 1),
      TrackInfo(type: TrackType.audio, id: 2, ffIndex: 2, selected: true),
    ];
    await c.open(r'C:\v\a.mkv');
    expect(c.rotation, Rotation.none);
    expect(engine.calls, containsAllInOrder(['video-rotate 90', 'video-rotate 0', r'open C:\v\a.mkv']));
    expect(c.probe!.videoSize, const IntSize(1920, 1080));
    engine.emitTracksChanged();
    await settle();
    expect(c.videoFfIndex, 0);
    expect(c.audioFfIndex, 2);
    await c.pause();
    expect(engine.calls.last, 'pause');
  });

  test('a direct rename moves the resume key without reopening', () async {
    final renamed = <String>[];
    final c = make(renameFile: (from, to) async => renamed.add('$from>$to'));
    await c.open(r'C:\m\track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(const Duration(minutes: 1));
    await settle();
    engine.calls.clear();
    expect(await c.renameOpenFile(r'C:\m\A - B.mp3'), isTrue);
    expect(renamed, [r'C:\m\track.mp3>C:\m\A - B.mp3']);
    expect(c.fileName, 'A - B.mp3');
    expect(engine.calls, isNot(contains('stop')));
    expect(resume.resumePositionFor(r'C:\m\A - B.mp3', const Duration(minutes: 4)), const Duration(minutes: 1));
  });

  test('a refused rename closes, renames and reopens at the same position, still paused', () async {
    var attempts = 0;
    final c = make(renameFile: (from, to) async {
      if (++attempts == 1) throw const FileSystemException('in use');
    });
    await c.open(r'C:\m\track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitPlaying(false);
    await settle();
    engine.calls.clear();
    expect(await c.renameOpenFile(r'C:\m\A - B.mp3'), isTrue);
    expect(engine.calls, containsAllInOrder(['stop', r'open C:\m\A - B.mp3', 'pause']));
    expect(c.fileName, 'A - B.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    await settle();
    expect(engine.calls, contains('seek ${const Duration(minutes: 1).inMilliseconds}'));
    expect(events.whereType<ResumedEvent>(), isEmpty);
  });

  test('a rename refused twice reopens the original file where it was', () async {
    final c = make(renameFile: (from, to) async => throw const FileSystemException('in use'));
    await c.open(r'C:\m\track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(const Duration(minutes: 1));
    engine.emitPlaying(true);
    await settle();
    engine.calls.clear();
    expect(await c.renameOpenFile(r'C:\m\A - B.mp3'), isFalse);
    expect(engine.calls, containsAllInOrder(['stop', r'open C:\m\track.mp3']));
    expect(engine.calls, isNot(contains('pause')));
    expect(c.fileName, 'track.mp3');
    engine.emitDuration(const Duration(minutes: 4));
    await settle();
    expect(engine.calls, contains('seek ${const Duration(minutes: 1).inMilliseconds}'));
  });
}
