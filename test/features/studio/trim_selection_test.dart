import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/features/studio/trim_selection.dart';

const _ten = Duration(minutes: 10);
Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  test('the window starts at the position and lasts 60 s', () {
    final t = TrimSelection.window(s(60), _ten);
    expect(t, TrimSelection(start: s(60), end: s(120), duration: _ten));
    expect(t.length, s(60));
    expect(t.range.start, s(60));
    expect(t.range.end, s(120));
  });

  test('near the end the window is shortened, and never empty', () {
    expect(TrimSelection.window(s(570), _ten), TrimSelection(start: s(570), end: _ten, duration: _ten));
    // minGap is 0.5 % of 10 min = 3 s.
    expect(TrimSelection.window(_ten, _ten), TrimSelection(start: s(597), end: _ten, duration: _ten));
  });

  test('handles keep the minimal gap and stay in the file', () {
    final t = TrimSelection(start: s(100), end: s(200), duration: _ten);
    expect(t.withStart(s(250)).start, s(197));
    expect(t.withStart(s(-5)).start, Duration.zero);
    expect(t.withEnd(s(50)).end, s(103));
    expect(t.withEnd(s(9999)).end, _ten);
  });

  test('moving the range keeps its length and stops at the edges', () {
    final t = TrimSelection(start: s(100), end: s(200), duration: _ten);
    expect(t.moveBy(s(30)), TrimSelection(start: s(130), end: s(230), duration: _ten));
    expect(t.moveBy(s(9999)), TrimSelection(start: s(500), end: _ten, duration: _ten));
    expect(t.moveBy(s(-9999)), TrimSelection(start: Duration.zero, end: s(100), duration: _ten));
  });

  test('the nearest handle wins, the start on a tie', () {
    final t = TrimSelection(start: s(100), end: s(200), duration: _ten);
    expect(t.nearestHandle(s(20)), TrimHandle.start);
    expect(t.nearestHandle(s(150)), TrimHandle.start);
    expect(t.nearestHandle(s(151)), TrimHandle.end);
  });

  test('a zero duration never throws (review focus: unknown duration)', () {
    final t = TrimSelection.window(s(5), Duration.zero);
    expect(t.start, Duration.zero);
    expect(t.end, Duration.zero);
    expect(t.withStart(s(3)).start, Duration.zero);
    expect(t.moveBy(s(3)).start, Duration.zero);
  });
}
