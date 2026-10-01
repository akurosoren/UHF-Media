import 'package:flutter/material.dart';
import '../../ui/icons.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_icon_button.dart';
import 'shell_controller.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({super.key, required this.shell, required this.fileName, required this.onOpen});

  static const double height = 36;

  final ShellController shell;
  final String? fileName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: shell,
      builder: (context, _) => Container(
        height: height,
        color: UhfColors.ink,
        child: Row(
          children: [
            const SizedBox(width: 10),
            const _MiniLogo(),
            const SizedBox(width: 6),
            UhfIconButton(
              icon: UhfIcons.folder_open,
              tooltip: l.tooltipOpen,
              onPressed: onOpen,
              size: 28,
              iconSize: 17,
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => shell.startDragging(),
                onDoubleTap: shell.toggleMaximize,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: UhfDurations.base,
                    child: Text(
                      fileName ?? '',
                      key: ValueKey(fileName),
                      style: UhfText.sans(size: 12.5, color: UhfColors.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
            UhfIconButton(
              icon: UhfIcons.push_pin,
              tooltip: l.tooltipPin,
              onPressed: shell.toggleAlwaysOnTop,
              active: shell.alwaysOnTop,
              size: 28,
              iconSize: 15,
            ),
            const SizedBox(width: 4),
            _WindowButton(glyph: _Glyph.minimize, tooltip: l.tooltipMinimize, onPressed: shell.minimize),
            _WindowButton(
              glyph: shell.maximized ? _Glyph.restore : _Glyph.maximize,
              tooltip: shell.maximized ? l.tooltipRestore : l.tooltipMaximize,
              onPressed: shell.toggleMaximize,
            ),
            _WindowButton(glyph: _Glyph.close, tooltip: l.tooltipClose, onPressed: shell.close, danger: true),
          ],
        ),
      ),
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h) => Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(color: UhfColors.signal, borderRadius: BorderRadius.circular(1)),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [bar(6), bar(9), bar(12)]);
  }
}

enum _Glyph { minimize, maximize, restore, close }

class _WindowButton extends StatefulWidget {
  const _WindowButton({required this.glyph, required this.tooltip, required this.onPressed, this.danger = false});

  final _Glyph glyph;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final background = !_hover
        ? Colors.transparent
        : widget.danger
            ? UhfColors.signal
            : UhfColors.text.withValues(alpha: 0.08);
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: UhfDurations.fast,
              width: 44,
              height: TitleBar.height,
              color: background,
              child: CustomPaint(
                painter: _GlyphPainter(
                  widget.glyph,
                  _hover && widget.danger ? UhfColors.ink : UhfColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final c = size.center(Offset.zero);
    const h = 5.0;
    switch (glyph) {
      case _Glyph.minimize:
        canvas.drawLine(Offset(c.dx - h, c.dy + 0.5), Offset(c.dx + h, c.dy + 0.5), paint);
      case _Glyph.maximize:
        canvas.drawRect(Rect.fromCenter(center: c + const Offset(0.5, 0.5), width: 2 * h, height: 2 * h), paint);
      case _Glyph.restore:
        canvas.drawRect(Rect.fromLTWH(c.dx - h + 0.5, c.dy - h + 2.5, 2 * h - 2, 2 * h - 2), paint);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - h + 2.5, c.dy - h + 2.5)
            ..lineTo(c.dx - h + 2.5, c.dy - h + 0.5)
            ..lineTo(c.dx + h + 0.5, c.dy - h + 0.5)
            ..lineTo(c.dx + h + 0.5, c.dy + h - 1.5)
            ..lineTo(c.dx + h - 1.5, c.dy + h - 1.5),
          paint,
        );
      case _Glyph.close:
        canvas.drawLine(c + const Offset(-h, -h), c + const Offset(h, h), paint);
        canvas.drawLine(c + const Offset(h, -h), c + const Offset(-h, h), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}
