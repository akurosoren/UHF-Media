import 'dart:async';

import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/media/media_engine.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';

class FakeMediaEngine implements MediaEngine {
  final calls = <String>[];
  List<TrackInfo> tracks = const [];
  bool throwOnOpen = false;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _videoSize = StreamController<IntSize>.broadcast();
  final _tracksChanged = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();

  void emitPosition(Duration d) => _position.add(d);
  void emitDuration(Duration d) => _duration.add(d);
  void emitPlaying(bool v) => _playing.add(v);
  void emitCompleted(bool v) => _completed.add(v);
  void emitVideoSize(IntSize s) => _videoSize.add(s);
  void emitTracksChanged() => _tracksChanged.add(null);
  void emitError(String e) => _errors.add(e);

  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<IntSize> get videoSize => _videoSize.stream;
  @override
  Stream<void> get tracksChanged => _tracksChanged.stream;
  @override
  Stream<String> get errors => _errors.stream;

  @override
  Future<void> open(String path) async {
    calls.add('open $path');
    if (throwOnOpen) throw Exception('cannot open');
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration position) async => calls.add('seek ${position.inMilliseconds}');
  @override
  Future<void> frameStep({required bool forward}) async =>
      calls.add(forward ? 'frame-step' : 'frame-back-step');
  @override
  Future<void> setVolume(double volume) async => calls.add('volume ${volume.round()}');
  @override
  Future<void> setMuted(bool muted) async => calls.add('mute ${muted ? 'yes' : 'no'}');
  @override
  Future<List<TrackInfo>> readTracks() async => tracks;
  @override
  Future<void> selectAudio(int id) async => calls.add('aid $id');
  @override
  Future<void> selectSubtitle(int? id) async => calls.add('sid ${id ?? 'no'}');
  @override
  Future<void> addSubtitle(String path) async => calls.add('sub-add $path');
  @override
  Future<void> setSubtitleScale(int percent) async => calls.add('sub-scale $percent');
  @override
  Future<void> setSubtitlePosition(int position) async => calls.add('sub-pos $position');
  @override
  Future<void> setPan(PanMode mode) async => calls.add('af ${mode.audioFilter}');
  @override
  Future<void> setRotation(Rotation rotation) async => calls.add('video-rotate ${rotation.degrees}');
  @override
  Future<void> setDeinterlace(bool enabled) async => calls.add('deinterlace ${enabled ? 'yes' : 'no'}');
  @override
  Future<void> screenshotTo(String path) async => calls.add('screenshot $path');
  @override
  Future<void> close() async => calls.add('stop');
  @override
  Future<void> dispose() async => calls.add('dispose');
}
