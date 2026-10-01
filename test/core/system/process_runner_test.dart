import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/system/process_runner.dart';

void main() {
  test('defaultProcessRunner reports the exit code', () async {
    final r = await defaultProcessRunner('cmd', ['/c', 'exit 3']);
    expect(r.exitCode, 3);
  });

  test('defaultProcessRunner captures stdout', () async {
    final r = await defaultProcessRunner('cmd', ['/c', 'echo hi']);
    expect((r.stdout as String).trim(), 'hi');
  });
}
