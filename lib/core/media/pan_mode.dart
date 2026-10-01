enum PanMode {
  stereo(''),
  left('lavfi=[pan=stereo|c0=c0|c1=c0]'),
  right('lavfi=[pan=stereo|c0=c1|c1=c1]');

  const PanMode(this.audioFilter);

  /// Value of mpv's `af` property. `pan` is a libavfilter filter, so mpv
  /// needs the `lavfi=[...]` wrapper.
  final String audioFilter;
}
