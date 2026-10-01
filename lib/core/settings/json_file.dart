import 'dart:convert';
import 'dart:io';

/// Never throws: an unreadable or locked file reads as null, so startup always
/// reaches the window with defaults.
Future<Map<String, dynamic>?> readJsonObject(File file) async {
  try {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(utf8.decode(await file.readAsBytes()));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Not UTF-8 or not JSON: keep the unreadable file aside and start fresh.
    }
    final backup = File('${file.path}.bak');
    if (await backup.exists()) await backup.delete();
    await file.rename(backup.path);
  } on FileSystemException {
    // Locked, unreadable, or the .bak cannot be written: start fresh.
  }
  return null;
}

// Writes to the same file are chained: overlapping renames of the shared
// .tmp file fail on Windows with "file in use".
final Map<String, Future<void>> _pendingWrites = {};

Future<void> writeJsonAtomic(File file, Map<String, dynamic> json) {
  final key = file.absolute.path.toLowerCase();
  final previous = _pendingWrites[key] ?? Future<void>.value();
  final next = previous.catchError((Object _) {}).then((_) => _write(file, json));
  _pendingWrites[key] = next;
  next.whenComplete(() {
    if (identical(_pendingWrites[key], next)) _pendingWrites.remove(key);
  }).ignore();
  return next;
}

Future<void> _write(File file, Map<String, dynamic> json) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(json), flush: true);
  try {
    await tmp.rename(file.path);
  } on FileSystemException {
    // Virtualized AppData (packaged parent process) can refuse the rename
    // with ERROR_NOT_SAME_DEVICE; copying over the target still works.
    await tmp.copy(file.path);
    await tmp.delete();
  }
}
