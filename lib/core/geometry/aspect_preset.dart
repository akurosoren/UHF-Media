enum AspectPreset {
  free(null, ''),
  r16x9(16 / 9, '16:9'),
  r9x16(9 / 16, '9:16'),
  r1x1(1, '1:1'),
  r4x3(4 / 3, '4:3');

  const AspectPreset(this.ratio, this.label);

  /// Width / height of the output picture, null when unconstrained.
  final double? ratio;
  final String label;
}
