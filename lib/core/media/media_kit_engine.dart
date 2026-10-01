import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../geometry/geometry.dart';
import '../geometry/rotation.dart';
import 'media_engine.dart';
import 'pan_mode.dart';
import 'track_info.dart';

class MediaKitEngine implements MediaEngine {
  MediaKitEngine()
      : player = Player(
          configuration: const PlayerConfiguration(
            title: 'UHF Media',
            // mpv renders subtitles itself: sub-scale, sub-pos and
            // screenshots with subtitles depend on it.
            libass: true,
          ),
        ) {
    controller = VideoController(player);
    unawaited(_native.setProperty('keep-open', 'yes'));
    _subscriptions
      ..add(player.stream.width.listen((_) => _emitSize()))
      ..add(player.stream.height.listen((_) => _emitSize()));
  }

  final Player player;
  late final VideoController controller;
  final _videoSize = StreamController<IntSize>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  NativePlayer get _native => player.platform! as NativePlayer;

  void _emitSize() {
    final w = player.state.width;
    final h = player.state.height;
    if (w != null && h != null && w > 0 && h > 0) _videoSize.add(IntSize(w, h));
  }

  @override
  Stream<Duration> get position => player.stream.position;
  @override
  Stream<Duration> get duration => player.stream.duration;
  @override
  Stream<bool> get playing => player.stream.playing;
  @override
  Stream<bool> get completed => player.stream.completed;
  @override
  Stream<IntSize> get videoSize => _videoSize.stream;
  @override
  Stream<void> get tracksChanged => player.stream.tracks.map((_) {});
  @override
  Stream<String> get errors => player.stream.error;

  @override
  Future<void> open(String path) async {
    await player.open(Media(path), play: true);
    await _native.setProperty('sid', 'no');
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> frameStep({required bool forward}) =>
      _native.command([forward ? 'frame-step' : 'frame-back-step']);
  @override
  Future<void> setVolume(double volume) => player.setVolume(volume);
  @override
  Future<void> setMuted(bool muted) => _native.setProperty('mute', muted ? 'yes' : 'no');
  @override
  Future<List<TrackInfo>> readTracks() async => parseTrackList(await _native.getProperty('track-list'));
  @override
  Future<void> selectAudio(int id) => _native.setProperty('aid', '$id');
  @override
  Future<void> selectSubtitle(int? id) => _native.setProperty('sid', id == null ? 'no' : '$id');
  @override
  Future<void> addSubtitle(String path) => _native.command(['sub-add', path, 'select']);
  @override
  Future<void> setSubtitleScale(int percent) => _native.setProperty('sub-scale', '${percent / 100}');
  @override
  Future<void> setSubtitlePosition(int position) => _native.setProperty('sub-pos', '$position');
  @override
  Future<void> setPan(PanMode mode) => _native.setProperty('af', mode.audioFilter);
  @override
  Future<void> setRotation(Rotation rotation) => _native.setProperty('video-rotate', '${rotation.degrees}');
  @override
  Future<void> setDeinterlace(bool enabled) => _native.setProperty('deinterlace', enabled ? 'yes' : 'no');
  @override
  Future<void> screenshotTo(String path) => _native.command(['screenshot-to-file', path, 'subtitles']);
  @override
  Future<void> close() => player.stop();

  @override
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _videoSize.close();
    await player.dispose();
  }
}
