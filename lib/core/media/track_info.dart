import 'dart:convert';

enum TrackType { video, audio, subtitle }

class TrackInfo {
  const TrackInfo({
    required this.type,
    required this.id,
    this.ffIndex,
    this.selected = false,
    this.title,
    this.language,
    this.codec,
    this.external = false,
  });

  final TrackType type;

  /// mpv track id (`aid` / `sid` value).
  final int id;

  /// Stream index in the container, usable as ffmpeg `-map 0:<ffIndex>`.
  final int? ffIndex;
  final bool selected;
  final String? title;
  final String? language;
  final String? codec;
  final bool external;

  /// "Commentary · ENG", "ENG", or null when mpv knows neither.
  String? get label {
    final parts = [
      if (title != null && title!.isNotEmpty) title!,
      if (language != null && language!.isNotEmpty) language!.toUpperCase(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Parses mpv's `track-list` property, read as a JSON string.
List<TrackInfo> parseTrackList(String json) {
  final Object? root;
  try {
    root = jsonDecode(json);
  } on FormatException {
    return const [];
  }
  if (root is! List) return const [];

  final tracks = <TrackInfo>[];
  for (final item in root.whereType<Map<String, dynamic>>()) {
    final type = switch (item['type']) {
      'video' => TrackType.video,
      'audio' => TrackType.audio,
      'sub' => TrackType.subtitle,
      _ => null,
    };
    final id = item['id'];
    if (type == null || id is! int) continue;
    String? text(String key) => item[key] is String ? item[key] as String : null;
    final ff = item['ff-index'];
    tracks.add(TrackInfo(
      type: type,
      id: id,
      ffIndex: ff is int ? ff : null,
      selected: item['selected'] == true,
      title: text('title'),
      language: text('lang'),
      codec: text('codec'),
      external: item['external'] == true,
    ));
  }
  return tracks;
}
