import 'dart:convert';
import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(String executable, List<String> arguments);

Future<ProcessResult> defaultProcessRunner(String executable, List<String> arguments) =>
    Process.run(executable, arguments, stdoutEncoding: utf8, stderrEncoding: utf8);
