import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/util/time_format.dart';

void main() {
  group('formatTimecode', () {
    test('formats hours, minutes and seconds with two digits', () {
      expect(formatTimecode(const Duration(hours: 1, minutes: 48, seconds: 30)), '01:48:30');
      expect(formatTimecode(const Duration(minutes: 3, seconds: 7)), '00:03:07');
    });
    test('truncates milliseconds', () {
      expect(formatTimecode(const Duration(seconds: 59, milliseconds: 999)), '00:00:59');
    });
    test('null and negative become zero', () {
      expect(formatTimecode(null), '00:00:00');
      expect(formatTimecode(const Duration(seconds: -5)), '00:00:00');
    });
    test('keeps hours beyond 99', () {
      expect(formatTimecode(const Duration(hours: 120)), '120:00:00');
    });
  });

  test('formatSeconds3 prints seconds with three decimals', () {
    expect(formatSeconds3(const Duration(minutes: 1, seconds: 2, milliseconds: 345)), '62.345');
    expect(formatSeconds3(Duration.zero), '0.000');
  });

  group('reducedRatio', () {
    test('reduces by the greatest common divisor', () {
      expect(reducedRatio(1920, 1080), '16:9');
      expect(reducedRatio(1080, 1920), '9:16');
      expect(reducedRatio(1000, 1000), '1:1');
      expect(reducedRatio(1918, 1078), '137:77');
    });
    test('invalid sizes give an empty string', () {
      expect(reducedRatio(0, 1080), '');
      expect(reducedRatio(1920, -1), '');
    });
  });
}
