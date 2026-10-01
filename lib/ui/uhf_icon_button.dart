import 'package:flutter/material.dart';

import 'tokens.dart';

class UhfIconButton extends StatefulWidget {
  const UhfIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.size = 32,
    this.iconSize = 18,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final double size;
  final double iconSize;

  @override
  State<UhfIconButton> createState() => _UhfIconButtonState();
}

class _UhfIconButtonState extends State<UhfIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = widget.active
        ? UhfColors.signal
        : enabled
            ? UhfColors.text
            : UhfColors.textMuted;
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: UhfDurations.fast,
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _hover && enabled ? UhfColors.text.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(UhfRadii.sm),
              ),
              child: Icon(widget.icon, size: widget.iconSize, weight: 300, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
