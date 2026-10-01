import 'dart:io';

import '../ffmpeg/probe_result.dart';
import 'process_runner.dart';

class ProbeService {
  ProbeService(this._ffprobe, {ProcessRunner? run}) : _run = run ?? defaultProcessRunner;

  final String? _ffprobe;
  final ProcessRunner _run;

  bool get available => _ffprobe != null;

  Future<ProbeResult?> probe(String path) async {
    final exe = _ffprobe;
    if (exe == null) return null;
    try {
      final result = await _run(exe, ['-v', 'error', '-print_format', 'json', '-show_streams', '-show_format', path]);
      if (result.exitCode != 0) return null;
      return ProbeResult.parse(result.stdout as String);
    } on ProcessException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
