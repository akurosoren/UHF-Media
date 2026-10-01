import 'dart:io';

import 'package:path/path.dart' as p;

import 'process_runner.dart';

class KnownFolders {
  KnownFolders({ProcessRunner? run, Map<String, String>? environment})
      : _run = run ?? defaultProcessRunner,
        _env = environment ?? Platform.environment;

  final ProcessRunner _run;
  final Map<String, String> _env;
  String? _desktop;

  /// The real Desktop folder (follows OneDrive redirection), cached.
  Future<String> desktop() async {
    final cached = _desktop;
    if (cached != null) return cached;
    try {
      final r = await _run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "[Environment]::GetFolderPath('Desktop')",
      ]);
      final out = (r.stdout as String).trim();
      if (r.exitCode == 0 && out.isNotEmpty) return _desktop = out;
    } on ProcessException {
      // Fall back below.
    }
    return _desktop = p.windows.join(_env['USERPROFILE'] ?? '', 'Desktop');
  }
}

/// Opens Explorer with [path] selected.
Future<void> revealInExplorer(String path) async {
  await Process.start('explorer.exe', ['/select,$path']);
}
