import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/system/ffmpeg_locator.dart';
import 'package:uhf_media/core/system/known_folders.dart';
import 'package:uhf_media/core/system/launch_args.dart';
import 'package:uhf_media/core/system/probe_service.dart';

void main() {
  group('FfmpegLocator', () {
    test('prefers the executable folder', () {
      final locator = FfmpegLocator(
        executableDir: r'C:\App',
        pathVariable: r'C:\Tools',
        fileExists: (p) => p == r'C:\App\ffprobe.exe' || p == r'C:\Tools\ffprobe.exe',
      );
      expect(locator.locate('ffprobe'), r'C:\App\ffprobe.exe');
    });

    test('falls back to PATH, ignoring quotes and empty entries', () {
      final locator = FfmpegLocator(
        executableDir: r'C:\App',
        pathVariable: r';"C:\Program Files\ff\bin";C:\Tools',
        fileExists: (p) => p == r'C:\Program Files\ff\bin\ffmpeg.exe',
      );
      expect(locator.locate('ffmpeg'), r'C:\Program Files\ff\bin\ffmpeg.exe');
    });

    test('returns null when missing', () {
      final locator = FfmpegLocator(executableDir: r'C:\App', pathVariable: '', fileExists: (_) => false);
      expect(locator.locate('ffmpeg'), isNull);
    });
  });

  group('ProbeService', () {
    test('runs ffprobe with JSON output and parses it', () async {
      late List<String> seenArgs;
      final probe = ProbeService(r'C:\App\ffprobe.exe', run: (exe, args) async {
        seenArgs = args;
        return ProcessResult(1, 0, '{"streams":[{"index":0,"codec_type":"video","field_order":"tt"}],"format":{}}', '');
      });
      final result = await probe.probe(r'C:\v\a b.ts');
      expect(seenArgs, ['-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', r'C:\v\a b.ts']);
      expect(result!.isInterlaced, isTrue);
    });

    test('missing ffprobe, failure or bad JSON give null', () async {
      expect(await ProbeService(null).probe('x'), isNull);
      expect(ProbeService(null).available, isFalse);
      final failing = ProbeService('ffprobe', run: (_, _) async => ProcessResult(1, 1, '', 'boom'));
      expect(await failing.probe('x'), isNull);
      final garbage = ProbeService('ffprobe', run: (_, _) async => ProcessResult(1, 0, 'garbage', ''));
      expect(await garbage.probe('x'), isNull);
      final missing = ProbeService('ffprobe', run: (_, _) async => throw const ProcessException('ffprobe', []));
      expect(await missing.probe('x'), isNull);
    });
  });

  group('KnownFolders', () {
    test('desktop comes from PowerShell and is cached', () async {
      var calls = 0;
      final folders = KnownFolders(run: (exe, args) async {
        calls++;
        return ProcessResult(1, 0, 'D:\\OneDrive\\Bureau\r\n', '');
      });
      expect(await folders.desktop(), r'D:\OneDrive\Bureau');
      expect(await folders.desktop(), r'D:\OneDrive\Bureau');
      expect(calls, 1);
    });

    test('falls back to USERPROFILE\\Desktop', () async {
      final folders = KnownFolders(
        run: (_, _) async => throw const ProcessException('powershell', []),
        environment: {'USERPROFILE': r'C:\Users\me'},
      );
      expect(await folders.desktop(), r'C:\Users\me\Desktop');
    });
  });

  test('firstExistingFile skips flags and missing paths', () {
    final existing = {r'C:\v\b.mkv'};
    expect(
      firstExistingFile(['--flag', r'C:\v\a.mkv', r'C:\v\b.mkv'], exists: existing.contains),
      r'C:\v\b.mkv',
    );
    expect(firstExistingFile(['--flag'], exists: existing.contains), isNull);
    expect(firstExistingFile(const [], exists: existing.contains), isNull);
  });
}
