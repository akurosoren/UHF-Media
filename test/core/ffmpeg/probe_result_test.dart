import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';

const _progressiveMkv = '''
{
  "streams": [
    {"index": 0, "codec_type": "video", "codec_name": "h264", "pix_fmt": "yuv420p",
     "bits_per_raw_sample": "8", "field_order": "progressive", "r_frame_rate": "30000/1001",
     "bit_rate": "8000000"},
    {"index": 1, "codec_type": "audio", "codec_name": "aac"},
    {"index": 2, "codec_type": "subtitle", "codec_name": "subrip"},
    {"index": 3, "codec_type": "subtitle", "codec_name": "hdmv_pgs_subtitle"}
  ],
  "format": {"duration": "5400.250000", "bit_rate": "9000000"}
}
''';

const _interlacedTs = '''
{
  "streams": [
    {"index": 0, "codec_type": "video", "codec_name": "mpeg2video", "pix_fmt": "yuv420p",
     "field_order": "tt", "r_frame_rate": "25/1"}
  ],
  "format": {"duration": "60.0", "bit_rate": "15000000"}
}
''';

const _hdrHevc = '''
{
  "streams": [
    {"index": 0, "codec_type": "video", "codec_name": "hevc", "pix_fmt": "yuv420p10le",
     "field_order": "bb", "r_frame_rate": "0/0"}
  ],
  "format": {}
}
''';

void main() {
  test('progressive mkv: stream bit rate, fps fraction, subtitles', () {
    final p = ProbeResult.parse(_progressiveMkv);
    expect(p.videoBitRate, 8000000);
    expect(p.fieldOrder, FieldOrder.progressive);
    expect(p.isInterlaced, isFalse);
    expect(p.frameRate, '30000/1001');
    expect(p.bitDepth, 8);
    expect(p.duration, const Duration(seconds: 5400, milliseconds: 250));
    expect(p.subtitles.map((s) => (s.index, s.isText)).toList(), [(2, true), (3, false)]);
  });

  test('interlaced ts: tff, format bit rate fallback', () {
    final p = ProbeResult.parse(_interlacedTs);
    expect(p.fieldOrder, FieldOrder.tff);
    expect(p.isInterlaced, isTrue);
    expect(p.videoBitRate, 15000000);
    expect(p.frameRate, '25/1');
  });

  test('10-bit from pix_fmt, bff, unknown fps and bit rate', () {
    final p = ProbeResult.parse(_hdrHevc);
    expect(p.bitDepth, 10);
    expect(p.fieldOrder, FieldOrder.bff);
    expect(p.frameRate, isNull);
    expect(p.videoBitRate, isNull);
    expect(p.duration, isNull);
  });

  test('no video stream yields defaults', () {
    final p = ProbeResult.parse('{"streams": [], "format": {}}');
    expect(p.bitDepth, 8);
    expect(p.fieldOrder, FieldOrder.progressive);
    expect(p.subtitles, isEmpty);
  });

  test('non-object JSON is a FormatException', () {
    expect(() => ProbeResult.parse('[]'), throwsFormatException);
  });
}
