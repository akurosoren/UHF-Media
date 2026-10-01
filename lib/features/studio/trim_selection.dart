import '../../core/ffmpeg/export_plan.dart';

enum TrimHandle { start, end }

/// Trim range on a file of known [duration]. Every edit keeps
/// 0 <= start < end <= duration with a gap of at least [minGap].
class TrimSelection {
  const TrimSelection({required this.start, required this.end, required this.duration});

  /// [length] from [from], shortened at the end of the file.
  factory TrimSelection.window(Duration from, Duration duration, {Duration length = const Duration(seconds: 60)}) {
    final gap = _gapOf(duration);
    final start = _clamp(from, Duration.zero, duration - gap);
    final end = start + length > duration ? duration : start + length;
    return TrimSelection(start: start, end: end, duration: duration);
  }

  final Duration start;
  final Duration end;
  final Duration duration;

  static Duration _gapOf(Duration d) => Duration(microseconds: (d.inMicroseconds * 0.005).round());

  /// 0.5 % of the duration, so the handles never overlap.
  Duration get minGap => _gapOf(duration);
  Duration get length => end - start;
  TrimRange get range => TrimRange(start, end);

  TrimSelection withStart(Duration value) =>
      TrimSelection(start: _clamp(value, Duration.zero, end - minGap), end: end, duration: duration);

  TrimSelection withEnd(Duration value) =>
      TrimSelection(start: start, end: _clamp(value, start + minGap, duration), duration: duration);

  TrimSelection moveBy(Duration delta) {
    final shifted = _clamp(start + delta, Duration.zero, duration - length);
    return TrimSelection(start: shifted, end: shifted + length, duration: duration);
  }

  TrimHandle nearestHandle(Duration at) =>
      (at - start).abs() <= (at - end).abs() ? TrimHandle.start : TrimHandle.end;

  @override
  bool operator ==(Object other) =>
      other is TrimSelection && other.start == start && other.end == end && other.duration == duration;

  @override
  int get hashCode => Object.hash(start, end, duration);

  @override
  String toString() => 'TrimSelection($start, $end / $duration)';
}

Duration _clamp(Duration value, Duration low, Duration high) {
  if (high < low) return low;
  if (value < low) return low;
  if (value > high) return high;
  return value;
}
