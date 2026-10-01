import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Small toggle with a 1 px outline; never takes keyboard focus.
class UhfChip extends StatefulWidget {
  const UhfChip({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.icon,
    this.mono = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final IconData? icon;
  final bool mono;

  @override
  State<UhfChip> createState() => _UhfChipState();
}

class _UhfChipState extends State<UhfChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = widget.selected
        ? UhfColors.signal
        : enabled
            ? UhfColors.text
            : UhfColors.textMuted;
    final style = widget.mono ? UhfText.mono(size: 12, color: color) : UhfText.sans(size: 12, color: color);
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: UhfDurations.fast,
            curve: UhfCurves.ease,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? UhfColors.signalSoft
                  : _hover && enabled
                      ? UhfColors.text.withValues(alpha: 0.09)
                      : UhfColors.text.withValues(alpha: 0.04),
              border: Border.all(color: widget.selected ? UhfColors.signal.withValues(alpha: 0.5) : UhfColors.line),
              borderRadius: BorderRadius.circular(UhfRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, weight: 300, color: color),
                  const SizedBox(width: 6),
                ],
                Text(widget.label, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
