import 'dart:convert';

import '../geometry/geometry.dart';

enum FieldOrder { progressive, tff, bff }

class SubtitleStreamInfo {
  const SubtitleStreamInfo({required this.index, required this.codec, required this.isText});

  /// Absolute stream index, usable as `-map 0:<index>`.
  final int index;
  final String codec;

  /// Text subtitles can be converted to mov_text; image ones cannot.
  final bool isText;
}

class AudioStreamInfo {
  const AudioStreamInfo({required this.index, required this.codec, this.channels});

  /// Absolute stream index, the same as mpv's `ff-index`.
  final int index;
  final String codec;
  final int? channels;
}

class ProbeResult {
  const ProbeResult({
    required this.videoBitRate,
    required this.fieldOrder,
    required this.frameRate,
    required this.bitDepth,
    required this.duration,
    required this.subtitles,
    this.videoSize,
    this.audioStreams = const [],
  });

  final int? videoBitRate;
  final FieldOrder fieldOrder;

  /// Fraction as ffprobe prints it ("30000/1001"), null when unknown.
  final String? frameRate;
  final int bitDepth;
  final Duration? duration;
  final List<SubtitleStreamInfo> subtitles;

  /// Coded size of the first video stream; null for audio-only files.
  final IntSize? videoSize;
  final List<AudioStreamInfo> audioStreams;

  bool get isInterlaced => fieldOrder != FieldOrder.progressive;

  static const _textSubtitleCodecs = {'subrip', 'srt', 'ass', 'ssa', 'webvtt', 'mov_text', 'text'};

  static ProbeResult parse(String json) {
    final root = jsonDecode(json);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('ffprobe output is not a JSON object');
    }
    final streams = (root['streams'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final format = root['format'] is Map<String, dynamic> ? root['format'] as Map<String, dynamic> : const {};
    // Cover art in audio files is a one-picture "video" stream: not a picture.
    final video = streams
        .where((s) => s['codec_type'] == 'video' && !_isAttachedPicture(s))
        .firstOrNull;

    return ProbeResult(
      videoBitRate: _positiveInt(video?['bit_rate']) ?? _positiveInt(format['bit_rate']),
      fieldOrder: _fieldOrder(video?['field_order']),
      frameRate: _frameRate(video?['r_frame_rate']),
      bitDepth: _bitDepth(video),
      duration: _duration(format['duration']),
      subtitles: [
        for (final s in streams)
          if (s['codec_type'] == 'subtitle' && s['index'] is int)
            SubtitleStreamInfo(
              index: s['index'] as int,
              codec: '${s['codec_name'] ?? ''}',
              isText: _textSubtitleCodecs.contains(s['codec_name']),
            ),
      ],
      videoSize: _size(video),
      audioStreams: [
        for (final s in streams)
          if (s['codec_type'] == 'audio' && s['index'] is int)
            AudioStreamInfo(
              index: s['index'] as int,
              codec: '${s['codec_name'] ?? ''}',
              channels: _positiveInt(s['channels']),
            ),
      ],
    );
  }

  static int? _positiveInt(Object? v) {
    final parsed = v is int ? v : int.tryParse('${v ?? ''}');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static bool _isAttachedPicture(Map<String, dynamic> stream) {
    final disposition = stream['disposition'];
    return disposition is Map && disposition['attached_pic'] == 1;
  }

  /// Upright picture size. Phones store landscape pixels plus a rotation;
  /// ffmpeg auto-rotates its input and mpv shows it upright, so a quarter
  /// turn swaps the stored width and height.
  static IntSize? _size(Map<String, dynamic>? video) {
    final w = _positiveInt(video?['width']);
    final h = _positiveInt(video?['height']);
    if (w == null || h == null) return null;
    return _rotation(video!) % 180 == 90 ? IntSize(h, w) : IntSize(w, h);
  }

  /// Display rotation in degrees, from the display matrix (ffmpeg 5+) or the
  /// old `rotate` tag; normalised to 0..359.
  static int _rotation(Map<String, dynamic> video) {
    num? degrees;
    final sideData = video['side_data_list'];
    if (sideData is List) {
      for (final item in sideData.whereType<Map<String, dynamic>>()) {
        final r = item['rotation'];
        if (r is num) degrees = r;
      }
    }
    final tags = video['tags'];
    if (degrees == null && tags is Map) degrees = num.tryParse('${tags['rotate'] ?? ''}');
    if (degrees == null) return 0;
    return degrees.round() % 360;
  }

  static FieldOrder _fieldOrder(Object? v) {
    final s = '${v ?? ''}'.toLowerCase();
    if (s.startsWith('t')) return FieldOrder.tff;
    if (s.startsWith('b')) return FieldOrder.bff;
    return FieldOrder.progressive;
  }

  static String? _frameRate(Object? v) {
    final s = '${v ?? ''}'.trim();
    if (s.isEmpty || s == '0/0' || s == 'N/A') return null;
    return s;
  }

  static int _bitDepth(Map<String, dynamic>? video) {
    if (video == null) return 8;
    final raw = _positiveInt(video['bits_per_raw_sample']);
    if (raw != null) return raw;
    final pix = '${video['pix_fmt'] ?? ''}';
    if (pix.contains('10le') || pix.contains('10be')) return 10;
    if (pix.contains('12le') || pix.contains('12be')) return 12;
    return 8;
  }

  static Duration? _duration(Object? v) {
    final seconds = double.tryParse('${v ?? ''}');
    if (seconds == null || seconds <= 0) return null;
    return Duration(microseconds: (seconds * 1e6).round());
  }
}
