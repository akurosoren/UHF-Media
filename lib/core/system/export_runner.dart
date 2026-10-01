import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ffmpeg/export_progress.dart';

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

sealed class ExportOutcome {
  const ExportOutcome();
}

class ExportSucceeded extends ExportOutcome {
  const ExportSucceeded(this.outputPath);
  final String outputPath;
}

class ExportCancelled extends ExportOutcome {
  const ExportCancelled();
}

class ExportFailed extends ExportOutcome {
  const ExportFailed(this.log);

  /// End of ffmpeg's error output, for "Copy details".
  final String log;
}

class ExportJob {
  ExportJob._();

  final _progress = StreamController<double>.broadcast();
  final _done = Completer<ExportOutcome>();
  Process? _process;
  bool _cancelRequested = false;

  Stream<double> get progress => _progress.stream;
  Future<ExportOutcome> get done => _done.future;

  void cancel() {
    _cancelRequested = true;
    _process?.kill();
  }

  void _finish(ExportOutcome outcome) {
    if (!_done.isCompleted) _done.complete(outcome);
    unawaited(_progress.close());
  }
}

class ExportRunner {
  ExportRunner(this.ffmpegPath, {ProcessStarter? start, Future<void> Function(String path)? deleteFile})
      : _start = start ?? Process.start,
        _delete = deleteFile ?? _deleteIfExists;

  static const _logLimit = 2000;

  final String ffmpegPath;
  final ProcessStarter _start;
  final Future<void> Function(String path) _delete;

  ExportJob start(List<String> args, {required String outputPath, required Duration total}) {
    final job = ExportJob._();
    unawaited(_run(job, args, outputPath, total));
    return job;
  }

  Future<void> _run(ExportJob job, List<String> args, String outputPath, Duration total) async {
    final Process process;
    try {
      process = await _start(ffmpegPath, args);
    } on ProcessException catch (e) {
      job._finish(ExportFailed(e.message));
      return;
    }
    job._process = process;
    if (job._cancelRequested) process.kill();

    var log = '';
    final errors = process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((chunk) {
      log += chunk;
      if (log.length > 2 * _logLimit) log = log.substring(log.length - _logLimit);
    }).asFuture<void>();

    final parser = ProgressParser(total);
    await process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .forEach((line) {
      final fraction = parser.feed(line);
      if (fraction != null && !job._progress.isClosed) job._progress.add(fraction);
    });
    await errors;
    final code = await process.exitCode;

    if (job._cancelRequested) {
      await _delete(outputPath);
      job._finish(const ExportCancelled());
    } else if (code == 0) {
      job._finish(ExportSucceeded(outputPath));
    } else {
      await _delete(outputPath);
      job._finish(ExportFailed(log.length > _logLimit ? log.substring(log.length - _logLimit) : log));
    }
  }
}

Future<void> _deleteIfExists(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Locked or already gone: nothing more to do.
  }
}
