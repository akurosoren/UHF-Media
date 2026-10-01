import 'dart:math' as math;
import 'dart:typed_data';

/// True when the RMS level (samples normalized to -1..1) is under [threshold].
bool isSilent(Int16List samples, {double threshold = 0.01}) {
  if (samples.isEmpty) return true;
  var sum = 0.0;
  for (final s in samples) {
    final v = s / 32768.0;
    sum += v * v;
  }
  return math.sqrt(sum / samples.length) < threshold;
}
