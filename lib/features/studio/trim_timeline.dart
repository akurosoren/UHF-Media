import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import 'trim_selection.dart';

class TrimTimeline extends StatefulWidget {
  const TrimTimeline({
    super.key,
    required this.selection,
    required this.position,
    required this.onChanged,
    required this.onPreview,
  });

  final TrimSelection selection;
  final Duration position;
  final ValueChanged<TrimSelection> onChanged;
  final ValueChanged<Duration> onPreview;

  static const double height = 28;

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

enum _Drag { start, end, range }

class _TrimTimelineState extends State<TrimTimeline> {
  static const _grab = 8.0;

  _Drag? _drag;
  double _anchorX = 0;
  TrimSelection? _anchor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final total = widget.selection.duration.inMicroseconds;
      double xOf(Duration d) => total <= 0 || width <= 0 ? 0 : width * d.inMicroseconds / total;
      Duration at(double x) => total <= 0 || width <= 0
          ? Duration.zero
          : Duration(microseconds: (total * (x / width).clamp(0.0, 1.0)).round());

      void apply(TrimSelection next, Duration preview) {
        widget.onChanged(next);
        widget.onPreview(preview);
      }

      return MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) {
            final s = widget.selection;
            final x = d.localPosition.dx;
            final toStart = (x - xOf(s.start)).abs();
            final toEnd = (x - xOf(s.end)).abs();
            if (toStart <= _grab && toStart <= toEnd) {
              _drag = _Drag.start;
              widget.onPreview(s.start);
            } else if (toEnd <= _grab) {
              _drag = _Drag.end;
              widget.onPreview(s.end);
            } else if (x > xOf(s.start) && x < xOf(s.end)) {
              _drag = _Drag.range;
              _anchorX = x;
              _anchor = s;
              widget.onPreview(s.start);
            } else if (s.nearestHandle(at(x)) == TrimHandle.start) {
              _drag = _Drag.start;
              final next = s.withStart(at(x));
              apply(next, next.start);
            } else {
              _drag = _Drag.end;
              final next = s.withEnd(at(x));
              apply(next, next.end);
            }
          },
          onPanUpdate: (d) {
            final s = widget.selection;
            final x = d.localPosition.dx;
            switch (_drag) {
              case _Drag.start:
                final next = s.withStart(at(x));
                apply(next, next.start);
              case _Drag.end:
                final next = s.withEnd(at(x));
                apply(next, next.end);
              case _Drag.range:
                final shift = width <= 0 ? 0.0 : (x - _anchorX) / width;
                final next = _anchor!.moveBy(Duration(microseconds: (total * shift).round()));
                apply(next, next.start);
              case null:
                break;
            }
          },
          onPanEnd: (_) => _drag = null,
          onPanCancel: () => _drag = null,
          child: CustomPaint(
            size: Size(width, TrimTimeline.height),
            painter: _TrimPainter(
              start: xOf(widget.selection.start),
              end: xOf(widget.selection.end),
              playhead: xOf(widget.position),
            ),
          ),
        ),
      );
    });
  }
}

class _TrimPainter extends CustomPainter {
  _TrimPainter({required this.start, required this.end, required this.playhead});

  final double start;
  final double end;
  final double playhead;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    canvas.drawRect(Rect.fromLTWH(0, midY - 1, size.width, 2), Paint()..color = UhfColors.line);
    final range = Rect.fromLTRB(start, midY - 6, end, midY + 6);
    canvas.drawRect(range, Paint()..color = UhfColors.signal.withValues(alpha: 0.25));
    final edge = Paint()..color = UhfColors.signal;
    canvas.drawRect(Rect.fromLTWH(start - 1, 2, 2, size.height - 4), edge);
    canvas.drawRect(Rect.fromLTWH(end - 1, 2, 2, size.height - 4), edge);
    canvas.drawRect(Rect.fromLTWH(playhead, 4, 1, size.height - 8), Paint()..color = UhfColors.text);
  }

  @override
  bool shouldRepaint(_TrimPainter old) => old.start != start || old.end != end || old.playhead != playhead;
}
