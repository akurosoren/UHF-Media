enum Rotation {
  none(0, ''),
  cw90(90, '_rot90'),
  ccw90(270, '_rot270'),
  half(180, '_rot180');

  const Rotation(this.degrees, this.suffix);

  /// Value of mpv's `video-rotate` property.
  final int degrees;

  /// Output file name suffix.
  final String suffix;

  bool get swapsAxes => this == cw90 || this == ccw90;

  Rotation get next => switch (this) {
        none => cw90,
        cw90 => ccw90,
        ccw90 => half,
        half => none,
      };
}
