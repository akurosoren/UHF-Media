String formatTimecode(Duration? d) {
  final totalSeconds = (d == null || d.isNegative) ? 0 : d.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}

String formatSeconds3(Duration d) {
  final ms = d.isNegative ? 0 : d.inMilliseconds;
  return '${ms ~/ 1000}.${(ms % 1000).toString().padLeft(3, '0')}';
}

String reducedRatio(int w, int h) {
  if (w <= 0 || h <= 0) return '';
  final g = _gcd(w, h);
  return '${w ~/ g}:${h ~/ g}';
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
