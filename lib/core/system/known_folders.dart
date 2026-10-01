import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

class KnownFolders {
  KnownFolders({String? Function()? shellDesktop, Map<String, String>? environment})
      : _shellDesktop = shellDesktop ?? shellDesktopPath,
        _env = environment ?? Platform.environment;

  final String? Function() _shellDesktop;
  final Map<String, String> _env;
  String? _desktop;

  /// The real Desktop folder (follows OneDrive redirection), cached.
  Future<String> desktop() async {
    final cached = _desktop;
    if (cached != null) return cached;
    try {
      final path = _shellDesktop();
      if (path != null && path.isNotEmpty) return _desktop = path;
    } on Object {
      // Fall back below.
    }
    return _desktop = p.windows.join(_env['USERPROFILE'] ?? '', 'Desktop');
  }
}

/// SHGetKnownFolderPath(FOLDERID_Desktop): UTF-16, no child process.
String? shellDesktopPath() {
  final rfid = FOLDERID_Desktop.toNative(allocator: calloc);
  try {
    final path = SHGetKnownFolderPath(rfid, KF_FLAG_DEFAULT, null);
    try {
      return path.toDartString();
    } finally {
      CoTaskMemFree(path);
    }
  } on WindowsException {
    return null;
  } finally {
    calloc.free(rfid);
  }
}

/// Opens Explorer with [path] selected.
Future<void> revealInExplorer(String path) async {
  await Process.start('explorer.exe', ['/select,$path']);
}
