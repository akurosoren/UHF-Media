import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/geometry/crop_drag.dart';
import '../../core/geometry/geometry.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';

class CropOverlay extends StatefulWidget {
  const CropOverlay({
    super.key,
    required this.crop,
    required this.lockRatio,
    required this.label,
    required this.onChanged,
  });

  /// Fractions of the displayed picture this widget covers exactly.
  final RatioRect crop;

  /// Width / height of the output picture, null when free.
  final double? lockRatio;
  final String label;
  final ValueChanged<RatioRect> onChanged;

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  static const _grab = 12.0;

  CropHandle? _handle;
  RatioRect? _startCrop;
  Offset _startPoint = Offset.zero;

  CropHandle? _hit(Offset p, Rect f) {
    bool near(Offset corner) => (p - corner).distance <= _grab;
    if (near(f.topLeft)) return CropHandle.nw;
    if (near(f.topRight)) return CropHandle.ne;
    if (near(f.bottomLeft)) return CropHandle.sw;
    if (near(f.bottomRight)) return CropHandle.se;
    final inX = p.dx >= f.left && p.dx <= f.right;
    final inY = p.dy >= f.top && p.dy <= f.bottom;
    if (inX && (p.dy - f.top).abs() <= _grab) return CropHandle.n;
    if (inX && (p.dy - f.bottom).abs() <= _grab) return CropHandle.s;
    if (inY && (p.dx - f.left).abs() <= _grab) return CropHandle.w;
    if (inY && (p.dx - f.right).abs() <= _grab) return CropHandle.e;
    if (f.contains(p)) return CropHandle.move;
    return null;
  }

  void _end() => setState(() {
        _handle = null;
        _startCrop = null;
      });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final c = widget.crop;
      final frame = Rect.fromLTWH(
        c.left * size.width,
        c.top * size.height,
        c.width * size.width,
        c.height * size.height,
      );
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (d) => setState(() {
          _handle = _hit(d.localPosition, frame);
          _startCrop = widget.crop;
          _startPoint = d.localPosition;
        }),
        onPanUpdate: (d) {
          final handle = _handle;
          final start = _startCrop;
          if (handle == null || start == null) return;
          final delta = d.localPosition - _startPoint;
          widget.onChanged(dragCrop(
            start,
            handle,
            delta.dx,
            delta.dy,
            pictureWidth: size.width,
            pictureHeight: size.height,
            lockRatio: widget.lockRatio,
          ));
        },
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _CropPainter(frame, thirds: _handle != null))),
            Positioned(
              left: frame.left,
              top: math.max(0, frame.top - 20),
              child: IgnorePointer(child: Text(widget.label, style: UhfText.mono(size: 11))),
            ),
          ],
        ),
      );
    });
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.frame, {required this.thirds});

  final Rect frame;
  final bool thirds;

  @override
  void paint(Canvas canvas, Size size) {
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(outside, Paint()..color = UhfColors.ink.withValues(alpha: 0.7));

    canvas.drawRect(
      frame.deflate(0.5),
      Paint()
        ..color = UhfColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (thirds) {
      final faint = Paint()
        ..color = UhfColors.text.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (var i = 1; i <= 2; i++) {
        final x = frame.left + frame.width * i / 3;
        final y = frame.top + frame.height * i / 3;
        canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), faint);
        canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), faint);
      }
    }

    final handle = Paint()
      ..color = UhfColors.text
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    const arm = 12.0;
    void corner(Offset p, double sx, double sy) {
      canvas.drawLine(p, p + Offset(arm * sx, 0), handle);
      canvas.drawLine(p, p + Offset(0, arm * sy), handle);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);
    const half = 8.0;
    canvas.drawLine(frame.topCenter - const Offset(half, 0), frame.topCenter + const Offset(half, 0), handle);
    canvas.drawLine(frame.bottomCenter - const Offset(half, 0), frame.bottomCenter + const Offset(half, 0), handle);
    canvas.drawLine(frame.centerLeft - const Offset(0, half), frame.centerLeft + const Offset(0, half), handle);
    canvas.drawLine(frame.centerRight - const Offset(0, half), frame.centerRight + const Offset(0, half), handle);
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.frame != frame || old.thirds != thirds;
}
