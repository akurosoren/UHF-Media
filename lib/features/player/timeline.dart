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
            height: 16,
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TimelinePainter(
                      played: played.clamp(0.0, 1.0),
                      thick: hoverX != null || _dragFraction != null,
                    ),
                  ),
                ),
                if (hoverX != null && _known)
                  Positioned(
                    left: (hoverX - 32).clamp(0.0, (width - 64).clamp(0.0, double.infinity)),
                    bottom: 18,
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: UhfColors.raised,
                        borderRadius: BorderRadius.circular(UhfRadii.sm),
                        border: Border.all(color: UhfColors.line),
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
  _TimelinePainter({required this.played, required this.thick});

  final double played;
  final bool thick;

  @override
  void paint(Canvas canvas, Size size) {
    final h = thick ? 4.0 : 2.0;
    final top = (size.height - h) / 2;
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, h), Paint()..color = UhfColors.line);
    final x = size.width * played;
    canvas.drawRect(Rect.fromLTWH(0, top, x, h), Paint()..color = UhfColors.signal);
    canvas.drawRect(Rect.fromLTWH(x - 1, (size.height - 11) / 2, 2, 11), Paint()..color = UhfColors.text);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.played != played || old.thick != thick;
}
