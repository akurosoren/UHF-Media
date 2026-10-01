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

  test('a rotation in the display matrix turns the picture size (final review: phone videos)', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {
          'index': 0,
          'codec_type': 'video',
          'width': 1920,
          'height': 1080,
          'side_data_list': [
            {'side_data_type': 'Display Matrix', 'rotation': -90},
          ],
        },
      ],
      'format': <String, dynamic>{},
    }));
    // ffmpeg auto-rotates its input and mpv shows it upright: 1080 x 1920.
    expect(r.videoSize, const IntSize(1080, 1920));
  });

  test('an old rotate tag of 270 turns it too, 180 does not', () {
    ProbeResult withTag(String rotate) => ProbeResult.parse(jsonEncode({
          'streams': [
            {'index': 0, 'codec_type': 'video', 'width': 1920, 'height': 1080, 'tags': {'rotate': rotate}},
          ],
          'format': <String, dynamic>{},
        }));
    expect(withTag('270').videoSize, const IntSize(1080, 1920));
    expect(withTag('180').videoSize, const IntSize(1920, 1080));
  });

  test('cover art is not the picture of an audio file (final review)', () {
    final r = ProbeResult.parse(jsonEncode({
      'streams': [
        {'index': 0, 'codec_type': 'audio', 'codec_name': 'mp3', 'channels': 2},
        {
          'index': 1,
          'codec_type': 'video',
          'codec_name': 'mjpeg',
          'width': 500,
          'height': 500,
          'disposition': {'attached_pic': 1},
        },
      ],
      'format': {'duration': '200.0'},
    }));
    expect(r.videoSize, isNull);
    expect(r.audioStreams.single.channels, 2);
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
