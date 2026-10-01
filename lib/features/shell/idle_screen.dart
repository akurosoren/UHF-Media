import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';

/// Start screen shown while no file is open: the red pixel "UHF" of an old
/// TV channel search, over a yellow signal bar whose last stroke blinks.
class IdleScreen extends StatefulWidget {
  const IdleScreen({super.key});

  @override
  State<IdleScreen> createState() => _IdleScreenState();
}

class _IdleScreenState extends State<IdleScreen> {
  late final Timer _timer;
  bool _barVisible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(UhfDurations.idleBlink, (_) {
      setState(() => _barVisible = !_barVisible);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [Color(0xFF151517), UhfColors.ink],
        ),
      ),
      child: CustomPaint(
        painter: _ScanlinePainter(),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: UhfDurations.slow * 2,
            curve: UhfCurves.ease,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: IdleSignalPainter.logoSize,
                  painter: IdleSignalPainter(barVisible: _barVisible),
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(UhfRadii.lg),
                    border: Border.all(color: UhfColors.lineStrong),
                  ),
                  child: Text(AppLocalizations.of(context).idleHint, style: UhfText.caption.copyWith(fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint horizontal lines, like an old television.
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x06FFFFFF);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => false;
}

class IdleSignalPainter extends CustomPainter {
  IdleSignalPainter({required this.barVisible});

  final bool barVisible;

  static const double _pixel = 10;
  static const double _textWidth = (3 * 5 + 2) * _pixel;
  static const double _textHeight = 7 * _pixel;
  static const double _rowGap = 26;
  static const double _barHeight = 34;
  static const int _barCount = 6;
  static const double _dotSize = 5;
  static const double _dotPitch = 10;

  static const Size logoSize = Size(_textWidth, _textHeight + _rowGap + _barHeight);

  // 5x7 bitmap glyphs; '1' is a filled pixel.
  static const Map<String, List<String>> _glyphs = {
    'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
    'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
    'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = UhfColors.logoRed;
    var cursorX = 0.0;
    for (final ch in 'UHF'.split('')) {
      final rows = _glyphs[ch]!;
      for (var row = 0; row < rows.length; row++) {
        for (var col = 0; col < rows[row].length; col++) {
          if (rows[row][col] == '1') {
            canvas.drawRect(
              Rect.fromLTWH(cursorX + col * _pixel, row * _pixel, _pixel, _pixel),
              red,
            );
          }
        }
      }
      cursorX += 6 * _pixel;
    }

    final yellow = Paint()..color = UhfColors.signalYellow;
    const rowTop = _textHeight + _rowGap;
    const half = _textWidth / 2;
    const pitch = half / _barCount;
    const barWidth = pitch * 0.4;
    for (var i = 0; i < _barCount; i++) {
      if (i == _barCount - 1 && !barVisible) continue;
      canvas.drawRect(Rect.fromLTWH(i * pitch, rowTop, barWidth, _barHeight), yellow);
    }
    const dotY = rowTop + _barHeight - _dotSize;
    var x = half + _dotPitch / 2;
    while (x + _dotSize <= _textWidth) {
      canvas.drawOval(Rect.fromLTWH(x, dotY, _dotSize, _dotSize), yellow);
      x += _dotPitch;
    }
  }

  @override
  bool shouldRepaint(IdleSignalPainter oldDelegate) => oldDelegate.barVisible != barVisible;
}
