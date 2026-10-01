import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/system/export_runner.dart';

import '../../support/fake_process.dart';

void main() {
  late List<String> deleted;
  setUp(() => deleted = []);

  ExportRunner runner(FakeProcess process, {List<String>? seenArgs}) => ExportRunner(
        r'C:\App\ffmpeg.exe',
        start: (exe, args) async {
          expect(exe, r'C:\App\ffmpeg.exe');
          seenArgs?.addAll(args);
          return process;
        },
        deleteFile: (path) async => deleted.add(path),
      );

  test('reports progress and succeeds', () async {
    final seen = <String>[];
    final job = runner(
      FakeProcess(stdoutLines: ['frame=1', 'out_time_us=5000000', 'progress=continue', 'progress=end']),
      seenArgs: seen,
    ).start(['-i', 'in.mkv', 'out.mkv'], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    final fractions = <double>[];
    job.progress.listen(fractions.add);
    final outcome = await job.done;
    expect(outcome, isA<ExportSucceeded>().having((o) => o.outputPath, 'outputPath', r'C:\v\out.mkv'));
    expect(fractions, [0.5, 1.0]);
    expect(seen, ['-i', 'in.mkv', 'out.mkv']);
    expect(deleted, isEmpty);
  });

  test('a failure keeps the end of stderr and deletes the partial file', () async {
    final job = runner(FakeProcess(stderrText: '${'x' * 3000}END', exit: 1))
        .start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    final outcome = await job.done;
    expect(outcome, isA<ExportFailed>());
    final log = (outcome as ExportFailed).log;
    expect(log.length, 2000);
    expect(log, endsWith('END'));
    expect(deleted, [r'C:\v\out.mkv']);
  });

  test('cancel kills ffmpeg and deletes the partial file', () async {
    final process = FakeProcess(waitForKill: true);
    final job = runner(process).start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    await Future<void>.delayed(Duration.zero);
    job.cancel();
    expect(await job.done, isA<ExportCancelled>());
    expect(process.killed, isTrue);
    expect(deleted, [r'C:\v\out.mkv']);
  });

  test('a cancel requested before ffmpeg starts kills it on start (review focus 2)', () async {
    final process = FakeProcess(waitForKill: true);
    final job = runner(process).start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    job.cancel();
    expect(await job.done, isA<ExportCancelled>());
    expect(process.killed, isTrue);
  });

  test('ffmpeg that cannot start is a failure, not a crash', () async {
    final job = ExportRunner(
      'ffmpeg.exe',
      start: (_, _) async => throw const ProcessException('ffmpeg.exe', [], 'not found'),
      deleteFile: (path) async => deleted.add(path),
    ).start(const [], outputPath: r'C:\v\out.mkv', total: const Duration(seconds: 10));
    expect(await job.done, isA<ExportFailed>().having((o) => o.log, 'log', 'not found'));
  });
}
