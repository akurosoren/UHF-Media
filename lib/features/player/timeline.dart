import 'package:flutter/material.dart';

import '../../core/util/time_format.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';

class Timeline extends StatefulWidget {
  const Timeline({super.key, required this.position, required this.duration, required this.onSeek});

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  double? _dragFraction;
  double? _hoverX;

  bool get _known => widget.duration > Duration.zero;

  Duration _at(double fraction) =>
      Duration(milliseconds: (widget.duration.inMilliseconds * fraction.clamp(0.0, 1.0)).round());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      double fractionOf(double x) => width <= 0 ? 0 : (x / width).clamp(0.0, 1.0);
      final played = _dragFraction ??
          (_known ? widget.position.inMilliseconds / widget.duration.inMilliseconds : 0.0);
      final hoverX = _hoverX;

      return MouseRegion(
        cursor: _known ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
        onExit: (_) => setState(() => _hoverX = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            if (_known) widget.onSeek(_at(fractionOf(d.localPosition.dx)));
          },
          onHorizontalDragStart: (d) {
            if (_known) setState(() => _dragFraction = fractionOf(d.localPosition.dx));
          },
          onHorizontalDragUpdate: (d) {
            if (_known) setState(() => _dragFraction = fractionOf(d.localPosition.dx));
          },
          onHorizontalDragEnd: (_) {
            final f = _dragFraction;
            setState(() => _dragFraction = null);
            if (f != null) widget.onSeek(_at(f));
          },
          child: SizedBox(
            height: 22,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: hoverX != null || _dragFraction != null ? 1.0 : 0.0),
                    duration: UhfDurations.base,
                    curve: UhfCurves.spring,
                    builder: (context, grow, _) => CustomPaint(
                      painter: _TimelinePainter(played: played.clamp(0.0, 1.0), grow: grow),
                    ),
                  ),
                ),
                if (hoverX != null && _known)
                  Positioned(
                    left: (hoverX - 36).clamp(0.0, (width - 72).clamp(0.0, double.infinity)),
                    bottom: 26,
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: UhfColors.glass,
                        borderRadius: BorderRadius.circular(UhfRadii.sm),
                        border: Border.all(color: UhfColors.lineStrong),
                      ),
                      child: Text(
                        formatTimecode(_at(fractionOf(hoverX))),
                        textAlign: TextAlign.center,
                        style: UhfText.mono(size: 11),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({required this.played, required this.grow});

  final double played;
  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final h = 3.0 + 3.0 * grow;
    final top = (size.height - h) / 2;
    final radius = Radius.circular(h / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, h), radius),
      Paint()..color = UhfColors.text.withValues(alpha: 0.18),
    );
    final x = (size.width * played).clamp(0.0, size.width);
    if (x > 0) {
      final bar = RRect.fromRectAndRadius(Rect.fromLTWH(0, top, x, h), radius);
      canvas.drawRRect(
        bar,
        Paint()
          ..color = UhfColors.signal.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawRRect(bar, Paint()..color = UhfColors.signal);
    }
    if (grow > 0.01) {
      canvas.drawCircle(Offset(x, size.height / 2), 7 * grow, Paint()..color = UhfColors.text);
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.played != played || old.grow != grow;
}
