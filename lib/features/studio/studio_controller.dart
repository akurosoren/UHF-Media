import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/ffmpeg/export_plan.dart';
import '../../core/geometry/aspect_preset.dart';
import '../../core/geometry/crop_math.dart';
import '../../core/geometry/geometry.dart';
import '../../core/geometry/rotation.dart';
import '../../core/system/export_runner.dart';
import '../../core/system/export_service.dart';
import '../player/player_controller.dart';
import 'trim_selection.dart';

sealed class StudioEvent {
  const StudioEvent();
}

class ExportFinishedEvent extends StudioEvent {
  const ExportFinishedEvent(this.path);
  final String path;
}

class ExportCancelledEvent extends StudioEvent {
  const ExportCancelledEvent();
}

class ExportFailedEvent extends StudioEvent {
  const ExportFailedEvent(this.log);
  final String log;
}

class ExportRetriedOnCpuEvent extends StudioEvent {
  const ExportRetriedOnCpuEvent();
}

class ExportRejectedEvent extends StudioEvent {
  const ExportRejectedEvent(this.error);
  final ExportPlanError error;
}

class FfmpegMissingEvent extends StudioEvent {
  const FfmpegMissingEvent(this.folder);
  final String folder;
}

class ExportProgress {
  const ExportProgress(this.fraction, this.remaining);
  final double fraction;
  final Duration? remaining;
}

class StudioController extends ChangeNotifier {
  StudioController({required PlayerController player, required Exporter exporter, DateTime Function()? now})
      : _player = player,
        _exporter = exporter,
        _now = now ?? DateTime.now {
    _path = player.path;
    player.addListener(_onPlayerChanged);
  }

  static const _window = Duration(seconds: 60);

  final PlayerController _player;
  final Exporter _exporter;
  final DateTime Function() _now;
  final _events = StreamController<StudioEvent>.broadcast();
  ExportProgress? _export;
  DateTime? _exportStarted;
  Future<void>? _exportFuture;

  String? _path;
  bool _open = false;
  TrimSelection? _trim;
  AspectPreset? _cropPreset;
  AspectPreset _lastPreset = AspectPreset.free;
  RatioRect _crop = CropMath.defaultCrop;

  Stream<StudioEvent> get events => _events.stream;

  /// ffmpeg was found; otherwise exporting shows where to put it.
  bool get ffmpegAvailable => _exporter.available;
  bool get isOpen => _open;
  Rotation get rotation => _player.rotation;
  bool get trimEnabled => _trim != null;
  TrimSelection? get trim => _trim;
  bool get cropEnabled => _cropPreset != null;
  AspectPreset? get cropPreset => _cropPreset;
  RatioRect get crop => _crop;
  double? get cropLockRatio => _cropPreset?.ratio;
  bool get exporting => _export != null;
  ExportProgress? get exportProgress => _export;

  /// Unrotated picture size: ffprobe's coded size, else the engine's.
  IntSize? get _sourceSize => _player.probe?.videoSize ?? _player.videoSize;

  /// A file with a picture is open (audio files have no studio).
  bool get available => _player.hasMedia && _sourceSize != null;

  /// The picture as drawn on screen, rotation included.
  IntSize? get pictureSize {
    final source = _sourceSize;
    return source == null ? null : CropMath.displayedPictureSize(_player.videoSize, source, rotation);
  }

  /// Size of the exported picture.
  IntSize? get outputSize {
    final source = _sourceSize;
    if (source == null) return null;
    if (!cropEnabled) return CropMath.displaySize(source, rotation);
    return CropMath.outputSize(CropMath.displayToSource(_crop, rotation, source), rotation);
  }

  void _onPlayerChanged() {
    final path = _player.path;
    if (path == _path) return;
    _path = path;
    _trim = null;
    _cropPreset = null;
    _crop = CropMath.defaultCrop;
    if (path == null) _open = false;
    notifyListeners();
  }

  void toggle() {
    if (!_open && !available) return;
    _open = !_open;
    notifyListeners();
  }

  Future<void> setRotation(Rotation r) async {
    if (r == rotation) return;
    await _player.setRotation(r);
    final preset = _cropPreset;
    if (preset != null) _crop = _fit(preset);
    notifyListeners();
  }

  Future<void> cycleRotation() => setRotation(rotation.next);

  // Trim ----------------------------------------------------------------

  void toggleTrim() {
    if (_trim != null) {
      _trim = null;
    } else {
      final duration = _player.duration;
      if (duration <= Duration.zero) return;
      _trim = TrimSelection.window(_player.position, duration);
    }
    notifyListeners();
  }

  void markIn() {
    final duration = _player.duration;
    if (duration <= Duration.zero) return;
    final position = _player.position;
    _trim = (_trim ?? TrimSelection.window(position, duration)).withStart(position);
    notifyListeners();
  }

  void markOut() {
    final duration = _player.duration;
    if (duration <= Duration.zero) return;
    final position = _player.position;
    final current = _trim ??
        TrimSelection(
          start: position > _window ? position - _window : Duration.zero,
          end: duration,
          duration: duration,
        );
    _trim = current.withEnd(position);
    notifyListeners();
  }

  void setTrim(TrimSelection selection) {
    if (_trim == null) return;
    _trim = selection;
    notifyListeners();
  }

  Future<void> nudgeStart(int seconds) async {
    final t = _trim;
    if (t == null) return;
    _trim = t.withStart(t.start + Duration(seconds: seconds));
    notifyListeners();
    await preview(_trim!.start);
  }

  Future<void> nudgeEnd(int seconds) async {
    final t = _trim;
    if (t == null) return;
    _trim = t.withEnd(t.end + Duration(seconds: seconds));
    notifyListeners();
    await preview(_trim!.end);
  }

  /// Shows the frame at [at] while a trim handle moves.
  Future<void> preview(Duration at) async {
    await _player.pause();
    await _player.seekTo(at);
  }

  // Crop ----------------------------------------------------------------

  void toggleCrop() => setCropPreset(cropEnabled ? null : _lastPreset);

  /// Choosing a preset recentres the largest frame of that ratio in 70 % of
  /// the picture; null turns the crop off.
  void setCropPreset(AspectPreset? preset) {
    if (preset != null) {
      if (pictureSize == null) return;
      _lastPreset = preset;
      _crop = _fit(preset);
    }
    _cropPreset = preset;
    notifyListeners();
  }

  void setCrop(RatioRect crop) {
    if (!cropEnabled) return;
    _crop = crop;
    notifyListeners();
  }

  RatioRect _fit(AspectPreset preset) {
    final picture = pictureSize;
    return picture == null ? CropMath.defaultCrop : CropMath.fitPreset(preset, picture);
  }

  // Export --------------------------------------------------------------

  Future<void> export() {
    final running = _exportFuture;
    if (running != null) return running;
    final future = _runExport();
    _exportFuture = future;
    return future.whenComplete(() => _exportFuture = null);
  }

  Future<void> _runExport() async {
    final path = _player.path;
    if (path == null) return;
    if (rotation == Rotation.none && !cropEnabled && _trim == null) {
      _events.add(const ExportRejectedEvent(ExportPlanError.noChanges));
      return;
    }
    final probe = _player.probe;
    if (!_exporter.available || probe == null) {
      _events.add(FfmpegMissingEvent(_exporter.expectedFolder));
      return;
    }
    final source = probe.videoSize ?? _sourceSize;
    final input = ExportInput(
      inputPath: path,
      probe: probe,
      rotation: rotation,
      crop: cropEnabled && source != null ? CropMath.displayToSource(_crop, rotation, source) : null,
      trim: _trim?.range,
      videoFfIndex: _player.videoFfIndex,
      audioFfIndex: _player.audioFfIndex,
    );

    await _player.pause();
    _exportStarted = _now();
    _export = const ExportProgress(0, null);
    notifyListeners();
    try {
      final outcome = await _exporter.export(
        input,
        onProgress: _onProgress,
        onCpuRetry: () => _events.add(const ExportRetriedOnCpuEvent()),
      );
      _events.add(switch (outcome) {
        ExportSucceeded(:final outputPath) => ExportFinishedEvent(outputPath),
        ExportCancelled() => const ExportCancelledEvent(),
        ExportFailed(:final log) => ExportFailedEvent(log),
      });
    } on ExportPlanException catch (e) {
      _events.add(ExportRejectedEvent(e.error));
    } finally {
      _export = null;
      _exportStarted = null;
      notifyListeners();
    }
  }

  void _onProgress(double fraction) {
    final started = _exportStarted;
    if (started == null) return;
    final elapsed = _now().difference(started);
    final remaining = fraction > 0.01
        ? Duration(microseconds: (elapsed.inMicroseconds * (1 - fraction) / fraction).round())
        : null;
    _export = ExportProgress(fraction, remaining);
    notifyListeners();
  }

  void cancelExport() => _exporter.cancel();

  /// On app close: stops a running export and waits (3 s at most) for
  /// ffmpeg to quit and the partial file to be removed.
  Future<void> shutdown() async {
    final running = _exportFuture;
    if (running == null) return;
    _exporter.cancel();
    await running.timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  @override
  void dispose() {
    _player.removeListener(_onPlayerChanged);
    unawaited(_events.close());
    super.dispose();
  }
}
