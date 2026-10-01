import 'dart:convert';
import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

/// Process.run from a GUI app gives console children no window at all
/// (checked 2026-10-01 with a GUI-subsystem parent), so the normal mode is
/// safe, keeps the exit code, and lets PowerShell start.
Future<ProcessResult> defaultProcessRunner(String executable, List<String> arguments) =>
    Process.run(executable, arguments, stdoutEncoding: utf8, stderrEncoding: utf8);
