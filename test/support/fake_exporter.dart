import 'dart:async';

import 'package:uhf_media/core/system/export_runner.dart';
import 'package:uhf_media/core/system/export_service.dart';

class FakeExporter implements Exporter {
  bool isAvailable = true;
  ExportInput? lastInput;
  Completer<ExportOutcome>? pending;
  void Function(double fraction)? progress;
  void Function()? cpuRetry;
  bool cancelled = false;
  Object? error;

  @override
  bool get available => isAvailable;

  @override
  String get expectedFolder => r'C:\App';

  @override
  Future<ExportOutcome> export(
    ExportInput input, {
    required void Function(double fraction) onProgress,
    void Function()? onCpuRetry,
  }) {
    lastInput = input;
    progress = onProgress;
    cpuRetry = onCpuRetry;
    final e = error;
    if (e != null) return Future.error(e);
    final completer = Completer<ExportOutcome>();
    pending = completer;
    return completer.future;
  }

  @override
  void cancel() {
    cancelled = true;
    final p = pending;
    if (p != null && !p.isCompleted) p.complete(const ExportCancelled());
  }
}
