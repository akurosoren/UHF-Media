import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Scripted process: writes its output on the next event-loop turn, then
/// exits with [exit] — or, with [waitForKill], only when killed (-1).
class FakeProcess implements Process {
  FakeProcess({List<String> stdoutLines = const [], String stderrText = '', int exit = 0, bool waitForKill = false}) {
    Future<void>(() {
      if (_exit.isCompleted) return;
      _stdout.add(utf8.encode(stdoutLines.map((l) => '$l\n').join()));
      _stderr.add(utf8.encode(stderrText));
      if (!waitForKill) _end(exit);
    });
  }

  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  void _end(int code) {
    if (_exit.isCompleted) return;
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    _exit.complete(code);
  }

  @override
  Stream<List<int>> get stdout => _stdout.stream;
  @override
  Stream<List<int>> get stderr => _stderr.stream;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;
  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    _end(-1);
    return true;
  }
}
