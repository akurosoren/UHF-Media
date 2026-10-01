import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>?> readJsonObject(File file) async {
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
  await tmp.rename(file.path);
}
