import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/geometry.dart';

void main() {
  test('reads the picture size and the audio codecs', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080},
        {'index': 1, 'codec_type': 'audio', 'codec_name': 'pcm_bluray'},
        {'index': 2, 'codec_type': 'audio', 'codec_name': 'ac3'},
      ],
      'format': <String, dynamic>{},
    }));
    expect(r.videoSize, const IntSize(1920, 1080));
    expect(r.audioStreams.map((a) => '${a.index}:${a.codec}'), ['1:pcm_bluray', '2:ac3']);
  });

  test('an audio-only file has no picture size', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'audio', 'codec_name': 'mp3'},
      ],
      'format': {'duration': '200.0'},
    }));
    expect(r.videoSize, isNull);
  });

  test('zero or missing dimensions give no picture size', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'video', 'width': 0},
      ],
      'format': <String, dynamic>{},
    }));
    expect(r.videoSize, isNull);
  });
}
