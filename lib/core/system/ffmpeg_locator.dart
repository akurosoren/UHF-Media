import 'dart:io';

import 'package:path/path.dart' as p;

class FfmpegLocator {
  FfmpegLocator({
    required this.executableDir,
    required this.pathVariable,
    bool Function(String path)? fileExists,
  }) : _exists = fileExists ?? ((path) => File(path).existsSync());

  factory FfmpegLocator.forCurrentProcess() => FfmpegLocator(
        executableDir: p.dirname(Platform.resolvedExecutable),
        pathVariable: Platform.environment['PATH'] ?? '',
      );

  final String executableDir;
  final String pathVariable;
  final bool Function(String path) _exists;

  /// `tool` is "ffmpeg" or "ffprobe". Looks next to the app first, then in PATH.
  String? locate(String tool) {
    final exe = '$tool.exe';
    final local = p.windows.join(executableDir, exe);
    if (_exists(local)) return local;
    for (final raw in pathVariable.split(';')) {
      final dir = raw.replaceAll('"', '').trim();
      if (dir.isEmpty) continue;
      final candidate = p.windows.join(dir, exe);
      if (_exists(candidate)) return candidate;
    }
    return null;
  }
}
