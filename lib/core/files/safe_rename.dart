import 'package:path/path.dart' as p;

import 'output_naming.dart';

final _win = p.windows;
final _forbidden = RegExp(r'[\\/*?:"<>|\x00-\x1F]');

String sanitizeFileStem(String raw) {
  var s = raw.replaceAll(_forbidden, '').trim();
  while (s.endsWith('.') || s.endsWith(' ')) {
    s = s.substring(0, s.length - 1);
  }
  return s.replaceAll(RegExp(r' {2,}'), ' ');
}

String? renameTarget(
  String oldPath,
  String artist,
  String title, {
  required bool Function(String path) exists,
}) {
  final stem = sanitizeFileStem('$artist - $title');
  final cleanedParts = stem.split(' - ').where((part) => part.trim().isNotEmpty);
  if (stem.isEmpty || cleanedParts.isEmpty || stem == '-') return null;
  final dir = _win.dirname(oldPath);
  final ext = _win.extension(oldPath);
  final direct = _win.join(dir, '$stem$ext');
  if (direct.toLowerCase() == oldPath.toLowerCase()) return null;
  return uniquePath(_win.join(dir, stem), ext, exists);
}
