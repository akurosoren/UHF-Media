import 'dart:convert';

enum FieldOrder { progressive, tff, bff }

class SubtitleStreamInfo {
  const SubtitleStreamInfo({required this.index, required this.codec, required this.isText});

  /// Absolute stream index, usable as `-map 0:<index>`.
  final int index;
  final String codec;

  /// Text subtitles can be converted to mov_text; image ones cannot.
  final bool isText;
}

class ProbeResult {
  const ProbeResult({
    required this.videoBitRate,
    required this.fieldOrder,
    required this.frameRate,
    required this.bitDepth,
    required this.duration,
    required this.subtitles,
  });

  final int? videoBitRate;
  final FieldOrder fieldOrder;

  /// Fraction as ffprobe prints it ("30000/1001"), null when unknown.
  final String? frameRate;
  final int bitDepth;
  final Duration? duration;
  final List<SubtitleStreamInfo> subtitles;

  bool get isInterlaced => fieldOrder != FieldOrder.progressive;

  static const _textSubtitleCodecs = {'subrip', 'srt', 'ass', 'ssa', 'webvtt', 'mov_text', 'text'};

  static ProbeResult parse(String json) {
    final root = jsonDecode(json);
    if (root is! Map<String, dynamic>) {
      throw const FormatException('ffprobe output is not a JSON object');
    }
    final streams = (root['streams'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    final format = root['format'] is Map<String, dynamic> ? root['format'] as Map<String, dynamic> : const {};
    final video = streams.where((s) => s['codec_type'] == 'video').firstOrNull;

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
    );
  }

  static int? _positiveInt(Object? v) {
    final parsed = v is int ? v : int.tryParse('${v ?? ''}');
    return (parsed != null && parsed > 0) ? parsed : null;
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
