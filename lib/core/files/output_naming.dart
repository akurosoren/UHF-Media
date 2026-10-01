import 'package:path/path.dart' as p;

import '../geometry/rotation.dart';

final _win = p.windows;

bool isMp4Family(String path) {
  final ext = _win.extension(path).toLowerCase();
  return ext == '.mp4' || ext == '.mov' || ext == '.m4v';
}

String exportOutputPath(
  String inputPath, {
  required bool crop,
  required Rotation rotation,
  required bool trim,
  required bool Function(String path) exists,
}) {
  final dir = _win.dirname(inputPath);
  final stem = _win.basenameWithoutExtension(inputPath);
  final ext = isMp4Family(inputPath) ? _win.extension(inputPath) : '.mkv';
  final suffix = '${crop ? '_crop' : ''}${rotation.suffix}${trim ? '_trim' : ''}';
  return uniquePath(_win.join(dir, '$stem$suffix'), ext, exists);
}

/// `<base><ext>`, or `<base> (n)<ext>` with the smallest free n.
String uniquePath(String base, String ext, bool Function(String path) exists) {
  var candidate = '$base$ext';
  var n = 1;
  while (exists(candidate)) {
    candidate = '$base ($n)$ext';
    n++;
  }
  return candidate;
}
