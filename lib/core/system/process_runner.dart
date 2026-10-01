import 'dart:convert';
import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Runs a console tool without flashing a console window.
///
/// A GUI app has no console, so Process.run makes Windows allocate a new
/// (visible) one for every console child. Detached mode passes
/// DETACHED_PROCESS instead, which keeps the pipes but never shows a window.
/// The exit code is not available in that mode: it is reported as 0, and
/// callers treat empty or unparsable output as failure.
Future<ProcessResult> defaultProcessRunner(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments, mode: ProcessStartMode.detachedWithStdio);
  await process.stdin.close();
  final out = process.stdout.transform(utf8.decoder).join();
  final err = process.stderr.transform(utf8.decoder).join();
  return ProcessResult(process.pid, 0, await out, await err);
}
