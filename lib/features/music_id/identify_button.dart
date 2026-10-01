import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import 'music_id_controller.dart';

/// One-click music identification in the control bar: an equalizer icon that
/// dances while the app listens.
class IdentifyButton extends StatefulWidget {
  const IdentifyButton({super.key, required this.music});

  final MusicIdController music;

  @override
  State<IdentifyButton> createState() => _IdentifyButtonState();
}

class _IdentifyButtonState extends State<IdentifyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _eq = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    widget.music.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.music.removeListener(_sync);
    _eq.dispose();
    super.dispose();
  }

  void _sync() {
    if (widget.music.busy) {
      if (!_eq.isAnimating) _eq.repeat();
    } else if (_eq.isAnimating) {
      _eq.stop();
      _eq.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.music,
      builder: (context, _) {
        final busy = widget.music.busy;
        final color = busy ? UhfColors.signal : UhfColors.text;
        return Tooltip(
          message: '${l.menuIdentifyMusic} (Ctrl+I)',
          excludeFromSemantics: true,
          child: Semantics(
            button: true,
            label: l.menuIdentifyMusic,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.music.identify,
                child: AnimatedContainer(
                  duration: UhfDurations.base,
                  curve: UhfCurves.ease,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: busy
                        ? UhfColors.signalSoft
                        : _hover
                            ? UhfColors.text.withValues(alpha: 0.12)
                            : UhfColors.text.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(UhfRadii.pill),
                    border: Border.all(color: busy ? UhfColors.signal.withValues(alpha: 0.5) : UhfColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _eq,
                        builder: (context, _) => CustomPaint(
                          size: const Size(16, 16),
                          painter: _EqualizerPainter(color: color, t: _eq.value, animate: busy),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: UhfDurations.fast,
                        child: Text(
                          busy ? l.buttonListening : l.buttonIdentify,
                          key: ValueKey(busy),
                          style: UhfText.sans(size: 12.5, weight: 500, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({required this.color, required this.t, required this.animate});

  final Color color;
  final double t;
  final bool animate;

  static const _rest = [0.45, 0.85, 0.6, 1.0];
  static const _phase = [0.0, 0.25, 0.5, 0.75];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const barWidth = 2.5;
    final gap = (size.width - barWidth * 4) / 3;
    for (var i = 0; i < 4; i++) {
      final level = animate ? 0.3 + 0.7 * (0.5 + 0.5 * _wave(t + _phase[i])) : _rest[i];
      final h = size.height * level;
      final x = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(1.2),
        ),
        paint,
      );
    }
  }

  double _wave(double x) => (1 - 2 * ((x % 1.0) - 0.5).abs()) * 2 - 1;

  @override
  bool shouldRepaint(_EqualizerPainter old) => old.color != color || old.t != t || old.animate != animate;
}
