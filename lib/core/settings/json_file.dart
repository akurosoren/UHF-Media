import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>?> readJsonObject(File file) async {
  if (!await file.exists()) return null;
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Fall through: keep the unreadable file aside and start fresh.
  }
  final backup = File('${file.path}.bak');
  if (await backup.exists()) await backup.delete();
  await file.rename(backup.path);
  return null;
}

Future<void> writeJsonAtomic(File file, Map<String, dynamic> json) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(json), flush: true);
  await tmp.rename(file.path);
}
