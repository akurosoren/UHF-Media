class AppSettings {
  const AppSettings({
    required this.volume,
    required this.muted,
    required this.subtitleScale,
    required this.subtitlePos,
    required this.windowX,
    required this.windowY,
    required this.windowWidth,
    required this.windowHeight,
    required this.maximized,
    required this.alwaysOnTop,
    required this.language,
    required this.autoRename,
    required this.lastOpenDir,
  });

  factory AppSettings.defaults() => const AppSettings(
        volume: 80,
        muted: false,
        subtitleScale: 100,
        subtitlePos: 100,
        windowX: null,
        windowY: null,
        windowWidth: 1100,
        windowHeight: 780,
        maximized: false,
        alwaysOnTop: false,
        language: 'system',
        autoRename: false,
        lastOpenDir: null,
      );

  static const languages = {'system', 'en', 'fr', 'tr'};

  final double volume;
  final bool muted;
  final int subtitleScale;
  final int subtitlePos;
  final double? windowX;
  final double? windowY;
  final double windowWidth;
  final double windowHeight;
  final bool maximized;
  final bool alwaysOnTop;
  final String language;
  final bool autoRename;
  final String? lastOpenDir;

  AppSettings copyWith({
    double? volume,
    bool? muted,
    int? subtitleScale,
    int? subtitlePos,
    double? windowX,
    double? windowY,
    double? windowWidth,
    double? windowHeight,
    bool? maximized,
    bool? alwaysOnTop,
    String? language,
    bool? autoRename,
    String? lastOpenDir,
  }) =>
      AppSettings(
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
        subtitleScale: subtitleScale ?? this.subtitleScale,
        subtitlePos: subtitlePos ?? this.subtitlePos,
        windowX: windowX ?? this.windowX,
        windowY: windowY ?? this.windowY,
        windowWidth: windowWidth ?? this.windowWidth,
        windowHeight: windowHeight ?? this.windowHeight,
        maximized: maximized ?? this.maximized,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
        language: language ?? this.language,
        autoRename: autoRename ?? this.autoRename,
        lastOpenDir: lastOpenDir ?? this.lastOpenDir,
      );

  Map<String, dynamic> toJson() => {
        'volume': volume,
        'muted': muted,
        'subtitleScale': subtitleScale,
        'subtitlePos': subtitlePos,
        'windowX': windowX,
        'windowY': windowY,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'maximized': maximized,
        'alwaysOnTop': alwaysOnTop,
        'language': language,
        'autoRename': autoRename,
        'lastOpenDir': lastOpenDir,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final d = AppSettings.defaults();

    double readNum(String key, double fallback, {double? min, double? max}) {
      final v = json[key];
      if (v is! num) return fallback;
      final x = v.toDouble();
      if ((min != null && x < min) || (max != null && x > max)) return fallback;
      return x;
    }

    double? readOptionalNum(String key) => json[key] is num ? (json[key] as num).toDouble() : null;

    int readInt(String key, int fallback, int min, int max) {
      final v = json[key];
      return (v is int && v >= min && v <= max) ? v : fallback;
    }

    bool readBool(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;

    final lang = json['language'];
    final dir = json['lastOpenDir'];
    return AppSettings(
      volume: readNum('volume', d.volume, min: 0, max: 100),
      muted: readBool('muted', d.muted),
      subtitleScale: readInt('subtitleScale', d.subtitleScale, 50, 300),
      subtitlePos: readInt('subtitlePos', d.subtitlePos, 0, 100),
      windowX: readOptionalNum('windowX'),
      windowY: readOptionalNum('windowY'),
      windowWidth: readNum('windowWidth', d.windowWidth, min: 320),
      windowHeight: readNum('windowHeight', d.windowHeight, min: 240),
      maximized: readBool('maximized', d.maximized),
      alwaysOnTop: readBool('alwaysOnTop', d.alwaysOnTop),
      language: lang is String && languages.contains(lang) ? lang : d.language,
      autoRename: readBool('autoRename', d.autoRename),
      lastOpenDir: dir is String && dir.isNotEmpty ? dir : null,
    );
  }
}
