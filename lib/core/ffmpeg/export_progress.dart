/// Reads the key=value lines ffmpeg writes with `-progress pipe:1`.
class ProgressParser {
  ProgressParser(this.total);

  final Duration total;

  /// Fraction done in [0, 1], or null when [line] carries no progress.
  double? feed(String line) {
    final eq = line.indexOf('=');
    if (eq < 0) return null;
    final key = line.substring(0, eq).trim();
    final value = line.substring(eq + 1).trim();
    if (key == 'progress' && value == 'end') return 1.0;
    if (key != 'out_time_us' || total <= Duration.zero) return null;
    final us = int.tryParse(value);
    if (us == null) return null;
    return (us / total.inMicroseconds).clamp(0.0, 1.0);
  }
}
