import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/rotation.dart';
import 'package:uhf_media/core/system/export_runner.dart';
import 'package:uhf_media/core/system/export_service.dart';

import '../../support/fake_process.dart';

const _probe = ProbeResult(
  videoBitRate: 8000000,
  fieldOrder: FieldOrder.progressive,
  frameRate: '25/1',
  bitDepth: 8,
  duration: Duration(minutes: 10),
  subtitles: [],
);

const _input = ExportInput(inputPath: r'C:\v\a.mkv', probe: _probe, rotation: Rotation.cw90);

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late List<List<String>> started;
  late List<FakeProcess> processes;
  late int encoderQueries;

  setUp(() {
    started = [];
    processes = [];
    encoderQueries = 0;
  });

  ExportService service({String encoders = ' V....D h264_nvenc   NVIDIA NVENC', Set<String> existing = const {}}) =>
      ExportService(
        ffmpegPath: r'C:\App\ffmpeg.exe',
        expectedFolder: r'C:\App',
        run: (exe, args) async {
          encoderQueries++;
          expect(args, ['-hide_banner', '-encoders']);
          return ProcessResult(1, 0, encoders, '');
        },
        start: (exe, args) async {
          started.add(args);
          return processes.removeAt(0);
        },
        exists: existing.contains,
        deleteFile: (_) async {},
      );

  test('a GPU failure retries once on the CPU', () async {
    processes = [FakeProcess(stderrText: 'nvenc failed', exit: 1), FakeProcess(stdoutLines: ['progress=end'])];
    var retries = 0;
    final s = service();
    final outcome = await s.export(_input, onProgress: (_) {}, onCpuRetry: () => retries++);
    expect(outcome, isA<ExportSucceeded>().having((o) => o.outputPath, 'outputPath', r'C:\v\a_rot90.mkv'));
    expect(retries, 1);
    expect(started[0], contains('h264_nvenc'));
    expect(started[1], contains('libx264'));
    expect(started[1], isNot(contains('h264_nvenc')));
  });

  test('the encoder list is read once', () async {
    processes = [FakeProcess(stdoutLines: ['progress=end']), FakeProcess(stdoutLines: ['progress=end'])];
    final s = service();
    await s.export(_input, onProgress: (_) {});
    await s.export(_input, onProgress: (_) {});
    expect(encoderQueries, 1);
  });

  test('cancelling during the GPU attempt never retries on the CPU (review focus 2)', () async {
    processes = [FakeProcess(waitForKill: true)];
    var retries = 0;
    final s = service();
    final future = s.export(_input, onProgress: (_) {}, onCpuRetry: () => retries++);
    await _settle();
    s.cancel();
    expect(await future, isA<ExportCancelled>());
    expect(retries, 0);
    expect(started, hasLength(1));
  });

  test('progress is forwarded', () async {
    processes = [FakeProcess(stdoutLines: ['out_time_us=300000000', 'progress=end'])];
    final fractions = <double>[];
    await service(encoders: '').export(_input, onProgress: fractions.add);
    expect(fractions, [0.5, 1.0]);
  });

  test('the output name avoids existing files', () async {
    processes = [FakeProcess(stdoutLines: ['progress=end'])];
    final outcome = await service(encoders: '', existing: {r'C:\v\a_rot90.mkv'}).export(_input, onProgress: (_) {});
    expect((outcome as ExportSucceeded).outputPath, r'C:\v\a_rot90 (1).mkv');
  });

  test('nothing to do is rejected before ffmpeg runs', () async {
    await expectLater(
      service().export(const ExportInput(inputPath: r'C:\v\a.mkv', probe: _probe), onProgress: (_) {}),
      throwsA(isA<ExportPlanException>().having((e) => e.error, 'error', ExportPlanError.noChanges)),
    );
    expect(started, isEmpty);
  });

  test('without ffmpeg the service is unavailable', () async {
    final s = ExportService(ffmpegPath: null, expectedFolder: r'C:\App');
    expect(s.available, isFalse);
    expect(await s.export(_input, onProgress: (_) {}), isA<ExportFailed>());
  });
}
