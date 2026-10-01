import '../geometry/geometry.dart';
import '../geometry/rotation.dart';
import 'pan_mode.dart';
import 'track_info.dart';

/// Playback engine seen by the app. Implemented over libmpv by
/// MediaKitEngine; every call maps to one mpv property or command.
abstract interface class MediaEngine {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<bool> get completed;
  Stream<IntSize> get videoSize;
  Stream<void> get tracksChanged;
  Stream<String> get errors;

  Future<void> open(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> frameStep({required bool forward});
  Future<void> setVolume(double volume);
  Future<void> setMuted(bool muted);
  Future<List<TrackInfo>> readTracks();
  Future<void> selectAudio(int id);

  /// null turns subtitles off.
  Future<void> selectSubtitle(int? id);
  Future<void> addSubtitle(String path);
  Future<void> setSubtitleScale(int percent);
  Future<void> setSubtitlePosition(int position);
  Future<void> setPan(PanMode mode);
  Future<void> setRotation(Rotation rotation);
  Future<void> setDeinterlace(bool enabled);

  /// PNG with subtitles burnt in, written by mpv.
  Future<void> screenshotTo(String path);
  Future<void> close();
  Future<void> dispose();
}
