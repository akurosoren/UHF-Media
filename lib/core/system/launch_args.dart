import 'dart:io';

/// First command-line argument that names an existing file; flags are skipped.
String? firstExistingFile(List<String> args, {bool Function(String path)? exists}) {
  final test = exists ?? ((path) => File(path).existsSync());
  for (final arg in args) {
    if (arg.startsWith('-')) continue;
    if (test(arg)) return arg;
  }
  return null;
}
