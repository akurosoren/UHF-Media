import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/files/media_files.dart';
import '../../core/geometry/geometry.dart';
import '../../core/media/media_engine.dart';
import '../../core/media/pan_mode.dart';
import '../../core/media/track_info.dart';
import '../../core/settings/resume_store.dart';
import '../../core/system/probe_service.dart';

sealed class PlayerEvent {
  const PlayerEvent();
}

class ResumedEvent extends PlayerEvent {
  const ResumedEvent(this.position);
  final Duration position;
}

class ScreenshotSavedEvent extends PlayerEvent {
  const ScreenshotSavedEvent(this.path);
  final String path;
}

class OpenFailedEvent extends PlayerEvent {
  const OpenFailedEvent(this.path);
  final String path;
}

class PlayerController extends ChangeNotifier {
  PlayerController({
    required MediaEngine engine,
    required ResumeStore resume,
    ProbeService? probe,
    Future<String> Function()? desktopDirectory,
    DateTime Function()? now,
    bool Function(String path)? fileExists,
    double initialVolume = 80,
    bool initialMuted = false,
    int initialSubtitleScale = 100,
    int initialSubtitlePos = 100,
  })  : _engine = engine,
        _resume = resume,
        _probe = probe,
        _desktopDirectory = desktopDirectory ?? (() async => Directory.current.path),
        _now = now ?? DateTime.now,
        _fileExists = fileExists ?? ((path) => File(path).existsSync()),
        _volume = initialVolume,
        _muted = initialMuted,
        _subtitleScale = initialSubtitleScale,
        _subtitlePos = initialSubtitlePos {
    _subscriptions.addAll([
      engine.position.listen(_onPosition),
      engine.duration.listen(_onDuration),
      engine.playing.listen((v) {
        _playing = v;
        notifyListeners();
      }),
      engine.completed.listen(_onCompleted),
      engine.videoSize.listen((s) {
        _videoSize = s;
        notifyListeners();
      }),
      engine.tracksChanged.listen((_) => unawaited(refreshTracks())),
      engine.errors.listen(_onError),
    ]);
    unawaited(engine.setVolume(initialVolume));
    unawaited(engine.setMuted(initialMuted));
  }

  static const _recordEvery = Duration(seconds: 5);

  final MediaEngine _engine;
  final ResumeStore _resume;
  final ProbeService? _probe;
  final Future<String> Function() _desktopDirectory;
  final DateTime Function() _now;
  final bool Function(String path) _fileExists;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final _events = StreamController<PlayerEvent>.broadcast();

  String? _path;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _lastRecorded = Duration.zero;
  bool _pendingResume = false;
  bool _playing = false;
  double _volume;
  bool _muted;
  List<TrackInfo> _tracks = const [];
  int _subtitleScale;
  int _subtitlePos;
  PanMode _pan = PanMode.stereo;
  IntSize? _videoSize;

  String? get path => _path;
  String? get fileName => _path == null ? null : p.windows.basename(_path!);
  bool get hasMedia => _path != null;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get playing => _playing;
  double get volume => _volume;
  bool get muted => _muted;
  List<TrackInfo> get audioTracks => _tracks.where((t) => t.type == TrackType.audio).toList();
  List<TrackInfo> get subtitleTracks => _tracks.where((t) => t.type == TrackType.subtitle).toList();
  int? get selectedSubtitleId => subtitleTracks.where((t) => t.selected).firstOrNull?.id;
  int get subtitleScale => _subtitleScale;
  int get subtitlePos => _subtitlePos;
  PanMode get pan => _pan;
  IntSize? get videoSize => _videoSize;
  Stream<PlayerEvent> get events => _events.stream;

  Future<void> open(String path) async {
    if (!_fileExists(path)) {
      _events.add(OpenFailedEvent(path));
      return;
    }
    await saveResume();
    _path = path;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lastRecorded = Duration.zero;
    _pendingResume = true;
    _tracks = const [];
    _pan = PanMode.stereo;
    _videoSize = null;
    notifyListeners();
    try {
      await _engine.setPan(PanMode.stereo);
      await _engine.open(path);
      await _engine.setSubtitleScale(_subtitleScale);
      await _engine.setSubtitlePosition(_subtitlePos);
      final probe = await _probe?.probe(path);
      await _engine.setDeinterlace(probe?.isInterlaced ?? false);
    } on Exception {
      _failOpen(path);
    }
  }

  void _failOpen(String path) {
    _path = null;
    _pendingResume = false;
    notifyListeners();
    _events.add(OpenFailedEvent(path));
  }

  void _onError(String _) {
    final path = _path;
    if (path != null && _duration == Duration.zero) _failOpen(path);
  }

  void _onDuration(Duration d) {
    _duration = d;
    final path = _path;
    if (_pendingResume && path != null && d > Duration.zero) {
      _pendingResume = false;
      final resumeAt = _resume.resumePositionFor(path, d);
      if (resumeAt != null) {
        unawaited(_engine.seek(resumeAt));
        _events.add(ResumedEvent(resumeAt));
      }
    }
    notifyListeners();
  }

  void _onPosition(Duration position) {
    _position = position;
    final path = _path;
    if (path != null && (position - _lastRecorded).abs() >= _recordEvery) {
      _lastRecorded = position;
      _resume.record(path, position);
    }
    notifyListeners();
  }

  void _onCompleted(bool done) {
    final path = _path;
    if (!done || path == null) return;
    _resume.clear(path);
    unawaited(_engine.seek(Duration.zero));
    unawaited(_engine.pause());
  }

  Future<void> togglePlay() => _playing ? _engine.pause() : _engine.play();

  Future<void> seekTo(Duration target) {
    var t = target < Duration.zero ? Duration.zero : target;
    if (t > _duration) t = _duration;
    return _engine.seek(t);
  }

  Future<void> seekRelative(Duration delta) => seekTo(_position + delta);

  Future<void> frameStep({required bool forward}) => _engine.frameStep(forward: forward);

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 100).toDouble();
    notifyListeners();
    await _engine.setVolume(_volume);
  }

  Future<void> adjustVolume(double delta) => setVolume(_volume + delta);

  Future<void> toggleMute() async {
    _muted = !_muted;
    notifyListeners();
    await _engine.setMuted(_muted);
  }

  Future<void> refreshTracks() async {
    _tracks = await _engine.readTracks();
    notifyListeners();
  }

  Future<void> selectAudio(int id) async {
    await _engine.selectAudio(id);
    await refreshTracks();
  }

  Future<void> selectSubtitle(int? id) async {
    await _engine.selectSubtitle(id);
    await refreshTracks();
  }

  Future<void> addSubtitle(String path) async {
    if (!hasMedia) return;
    await _engine.addSubtitle(path);
    await refreshTracks();
  }

  Future<void> previewSubtitleStyle(int scale, int pos) async {
    await _engine.setSubtitleScale(scale);
    await _engine.setSubtitlePosition(pos);
  }

  Future<void> commitSubtitleStyle(int scale, int pos) async {
    _subtitleScale = scale;
    _subtitlePos = pos;
    notifyListeners();
    await previewSubtitleStyle(scale, pos);
  }

  Future<void> togglePan(PanMode mode) async {
    _pan = _pan == mode ? PanMode.stereo : mode;
    notifyListeners();
    await _engine.setPan(_pan);
  }

  Future<void> screenshot() async {
    if (!hasMedia) return;
    final dir = await _desktopDirectory();
    final file = p.windows.join(dir, screenshotFileName(_now()));
    await _engine.screenshotTo(file);
    _events.add(ScreenshotSavedEvent(file));
  }

  Future<void> restartFromBeginning() => _engine.seek(Duration.zero);

  /// Best effort: a resume file that cannot be written never blocks playback.
  Future<void> saveResume() async {
    final path = _path;
    if (path != null && _position > Duration.zero) _resume.record(path, _position);
    try {
      await _resume.flush();
    } on Exception {
      // Keep the entry in memory; the next flush retries.
    }
  }

  Future<void> close() async {
    await saveResume();
    await _engine.close();
    _path = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    unawaited(_events.close());
    super.dispose();
  }
}
