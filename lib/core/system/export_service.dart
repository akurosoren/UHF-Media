import 'dart:io';

import '../ffmpeg/export_command_builder.dart';
import '../ffmpeg/export_plan.dart';
import '../ffmpeg/probe_result.dart';
import '../files/output_naming.dart';
import '../geometry/geometry.dart';
import '../geometry/rotation.dart';
import 'export_runner.dart';
import 'process_runner.dart';

class ExportInput {
  const ExportInput({
    required this.inputPath,
    required this.probe,
    this.rotation = Rotation.none,
    this.crop,
    this.trim,
    this.videoFfIndex,
    this.audioFfIndex,
  });

  final String inputPath;
  final ProbeResult probe;
  final Rotation rotation;

  /// Crop in unrotated source pixels.
  final IntRect? crop;
  final TrimRange? trim;
  final int? videoFfIndex;
  final int? audioFfIndex;
}

abstract interface class Exporter {
  bool get available;

  /// Folder where ffmpeg.exe is expected, for the "missing" message.
  String get expectedFolder;

  /// Throws [ExportPlanException] when the edits cannot be exported.
  Future<ExportOutcome> export(
    ExportInput input, {
    required void Function(double fraction) onProgress,
    void Function()? onCpuRetry,
  });

  void cancel();
}

class ExportService implements Exporter {
  ExportService({
    required String? ffmpegPath,
    required this.expectedFolder,
    ProcessRunner? run,
    ProcessStarter? start,
    bool Function(String path)? exists,
    Future<void> Function(String path)? deleteFile,
  })  : _ffmpeg = ffmpegPath,
        _run = run ?? defaultProcessRunner,
        _start = start,
        _exists = exists ?? ((path) => File(path).existsSync()),
        _deleteFile = deleteFile;

  final String? _ffmpeg;
  final ProcessRunner _run;
  final ProcessStarter? _start;
  final bool Function(String path) _exists;
  final Future<void> Function(String path)? _deleteFile;
  Future<HwEncoder?>? _hw;
  ExportJob? _job;
  bool _cancelled = false;

  @override
  final String expectedFolder;

  @override
  bool get available => _ffmpeg != null;

  /// First hardware H.264 encoder that actually works here, detected once.
  /// Builds list NVENC, QSV and AMF whatever the GPU, so each listed one
  /// encodes a one-frame test picture (NVENC fails on an AMD machine).
  Future<HwEncoder?> hwEncoder() => _hw ??= _detectHwEncoder();

  Future<HwEncoder?> _detectHwEncoder() async {
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return null;
    try {
      final r = await _run(ffmpeg, ['-hide_banner', '-encoders']);
      if (r.exitCode != 0) return null;
      final listed = '${r.stdout}';
      for (final encoder in HwEncoder.values) {
        if (!listed.contains(encoder.ffmpegName)) continue;
        final test = await _run(ffmpeg, [
          '-hide_banner', '-v', 'error',
          '-f', 'lavfi', '-i', 'color=c=black:s=256x256:d=0.1',
          '-frames:v', '1', '-c:v', encoder.ffmpegName, '-f', 'null', '-',
        ]);
        if (test.exitCode == 0) return encoder;
      }
      return null;
    } on Exception {
      return null;
    }
  }

  @override
  Future<ExportOutcome> export(
    ExportInput input, {
    required void Function(double fraction) onProgress,
    void Function()? onCpuRetry,
  }) async {
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return const ExportFailed('ffmpeg.exe not found');
    _cancelled = false;
    final plan = ExportPlan(
      inputPath: input.inputPath,
      outputPath: exportOutputPath(
        input.inputPath,
        crop: input.crop != null,
        rotation: input.rotation,
        trim: input.trim != null,
        exists: _exists,
      ),
      rotation: input.rotation,
      crop: input.crop,
      trim: input.trim,
      videoFfIndex: input.videoFfIndex,
      audioFfIndex: input.audioFfIndex,
    );
    // Validates the edits first: nothing runs when the plan is rejected.
    ExportCommandBuilder.build(plan, input.probe);
    final total = input.trim?.length ?? input.probe.duration ?? Duration.zero;
    final runner = ExportRunner(ffmpeg, start: _start, deleteFile: _deleteFile);

    var command = ExportCommandBuilder.build(plan, input.probe, hwEncoder: await hwEncoder());
    var outcome = await _runOnce(runner, command, plan.outputPath, total, onProgress);
    if (outcome is ExportFailed && command.usesHardware && !_cancelled) {
      // A listed encoder can still fail (no GPU, old driver): retry on the CPU.
      onCpuRetry?.call();
      command = ExportCommandBuilder.build(plan, input.probe);
      outcome = await _runOnce(runner, command, plan.outputPath, total, onProgress);
    }
    return outcome;
  }

  Future<ExportOutcome> _runOnce(
    ExportRunner runner,
    ExportCommand command,
    String outputPath,
    Duration total,
    void Function(double fraction) onProgress,
  ) async {
    final job = runner.start(command.args, outputPath: outputPath, total: total);
    _job = job;
    if (_cancelled) job.cancel();
    final subscription = job.progress.listen(onProgress);
    try {
      return await job.done;
    } finally {
      await subscription.cancel();
      _job = null;
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    _job?.cancel();
  }
}
