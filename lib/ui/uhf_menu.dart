import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'tokens.dart';
import 'typography.dart';
import 'uhf_icon_button.dart';

class UhfMenuEntry {
  const UhfMenuEntry({required this.label, this.onSelected, this.checked, this.shortcut, this.children});

  final String label;
  final VoidCallback? onSelected;

  /// null: no check column; true / false: checked or empty column.
  final bool? checked;
  final String? shortcut;
  final List<UhfMenuEntry>? children;
}

class UhfMenuButton extends StatelessWidget {
  const UhfMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.entries,
    this.onOpenChanged,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final List<UhfMenuEntry> entries;
  final ValueChanged<bool>? onOpenChanged;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      onOpen: () => onOpenChanged?.call(true),
      onClose: () => onOpenChanged?.call(false),
      menuChildren: [for (final e in entries) _item(e)],
      builder: (context, controller, _) => UhfIconButton(
        icon: icon,
        tooltip: tooltip,
        active: active,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  Widget _item(UhfMenuEntry e) {
    final children = e.children;
    if (children != null) {
      return SubmenuButton(menuChildren: [for (final c in children) _item(c)], child: Text(e.label));
    }
    final checked = e.checked;
    return MenuItemButton(
      onPressed: e.onSelected,
      leadingIcon: checked == null
          ? null
          : SizedBox(
              width: 18,
              child: checked ? const Icon(Symbols.check_sharp, size: 16, weight: 300) : null,
            ),
      trailingIcon: e.shortcut == null
          ? null
          : Text(e.shortcut!, style: UhfText.mono(size: 11, color: UhfColors.textMuted)),
      child: Text(e.label),
    );
  }
}
