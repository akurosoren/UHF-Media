import '../geometry/geometry.dart';
import '../geometry/rotation.dart';

class TrimRange {
  const TrimRange(this.start, this.end);
  final Duration start;
  final Duration end;
  Duration get length => end - start;
}

enum HwEncoder {
  nvenc('h264_nvenc'),
  qsv('h264_qsv'),
  amf('h264_amf');

  const HwEncoder(this.ffmpegName);
  final String ffmpegName;
}

class ExportPlan {
  const ExportPlan({
    required this.inputPath,
    required this.outputPath,
    this.rotation = Rotation.none,
    this.crop,
    this.trim,
    this.videoFfIndex,
    this.audioFfIndex,
  });

  final String inputPath;
  final String outputPath;
  final Rotation rotation;

  /// Crop in unrotated source pixels (see CropMath.displayToSource).
  final IntRect? crop;
  final TrimRange? trim;

  /// mpv `ff-index` of the selected tracks, used as `-map 0:<index>`.
  final int? videoFfIndex;
  final int? audioFfIndex;
}

enum ExportPlanError { noChanges, trimTooShort, cropTooSmall }

class ExportPlanException implements Exception {
  const ExportPlanException(this.error);
  final ExportPlanError error;

  @override
  String toString() => 'ExportPlanException($error)';
}
