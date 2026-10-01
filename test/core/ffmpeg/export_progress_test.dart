import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_progress.dart';

void main() {
  final parser = ProgressParser(const Duration(seconds: 10));

  test('out_time_us gives the fraction done', () {
    expect(parser.feed('out_time_us=2500000'), 0.25);
  });

  test('progress=end means done', () {
    expect(parser.feed('progress=end'), 1.0);
  });

  test('other lines, N/A and overshoot', () {
    expect(parser.feed('frame=120'), isNull);
    expect(parser.feed('progress=continue'), isNull);
    expect(parser.feed('out_time_us=N/A'), isNull);
    expect(parser.feed('out_time_us=99000000'), 1.0);
  });

  test('unknown total duration gives no fraction', () {
    expect(ProgressParser(Duration.zero).feed('out_time_us=1000'), isNull);
  });
}
