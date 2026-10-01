import 'package:flutter/material.dart';
import '../../ui/icons.dart';

import '../../core/geometry/aspect_preset.dart';
import '../../core/geometry/rotation.dart';
import '../../core/util/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_chip.dart';
import '../../ui/uhf_icon_button.dart';
import '../../ui/uhf_menu.dart';
import '../player/player_controller.dart';
import 'studio_controller.dart';
import 'trim_selection.dart';
import 'trim_timeline.dart';

class StudioPanel extends StatelessWidget {
  const StudioPanel({super.key, required this.studio, required this.player, this.onMenuOpenChanged});

  final StudioController studio;
  final PlayerController player;
  final ValueChanged<bool>? onMenuOpenChanged;

  static String rotationLabel(Rotation r) => switch (r) {
        Rotation.none => '0°',
        Rotation.cw90 => '90°',
        Rotation.ccw90 => '−90°',
        Rotation.half => '180°',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([studio, player]),
      builder: (context, _) {
        final trim = studio.trim;
        return Container(
          decoration: const BoxDecoration(
            color: UhfColors.surface,
            border: Border(top: BorderSide(color: UhfColors.line)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (trim != null) ...[
                TrimTimeline(
                  selection: trim,
                  position: player.position,
                  onChanged: studio.setTrim,
                  onPreview: studio.preview,
                ),
                const SizedBox(height: 6),
                _TrimRow(studio: studio, trim: trim),
                const SizedBox(height: 10),
              ],
              if (studio.exporting) _ExportBar(studio: studio) else _EditRow(studio: studio, onMenuOpenChanged: onMenuOpenChanged),
            ],
          ),
        );
      },
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.studio, required this.onMenuOpenChanged});

  final StudioController studio;
  final ValueChanged<bool>? onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final out = studio.outputSize;
    return Row(
      children: [
        for (final r in Rotation.values) ...[
          UhfChip(
            label: StudioPanel.rotationLabel(r),
            mono: true,
            selected: studio.rotation == r,
            onPressed: () => studio.setRotation(r),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 8),
        UhfChip(
          icon: UhfIcons.content_cut,
          label: l.studioTrim,
          selected: studio.trimEnabled,
          onPressed: studio.toggleTrim,
        ),
        const SizedBox(width: 4),
        UhfMenuButton(
          icon: UhfIcons.crop,
          tooltip: l.tooltipCrop,
          active: studio.cropEnabled,
          onOpenChanged: onMenuOpenChanged,
          entries: [
            UhfMenuEntry(
              label: l.cropOff,
              checked: !studio.cropEnabled,
              onSelected: () => studio.setCropPreset(null),
            ),
            for (final p in AspectPreset.values)
              UhfMenuEntry(
                label: p == AspectPreset.free ? l.cropFree : p.label,
                checked: studio.cropPreset == p,
                onSelected: () => studio.setCropPreset(p),
              ),
          ],
        ),
        const SizedBox(width: 12),
        if (out != null)
          Text(
            '${out.width} × ${out.height} · ${reducedRatio(out.width, out.height)}',
            style: UhfText.mono(size: 12, color: UhfColors.textMuted),
          ),
        const Spacer(),
        _ExportButton(label: l.actionExport, onPressed: studio.export),
      ],
    );
  }
}

class _TrimRow extends StatelessWidget {
  const _TrimRow({required this.studio, required this.trim});

  final StudioController studio;
  final TrimSelection trim;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = UhfText.sans(size: 11, color: UhfColors.textMuted);
    Widget nudge(IconData icon, String tooltip, VoidCallback onPressed) =>
        UhfIconButton(icon: icon, tooltip: tooltip, size: 24, iconSize: 16, onPressed: onPressed);
    return Row(
      children: [
        Text(l.studioIn, style: label),
        const SizedBox(width: 6),
        Text(formatTimecode(trim.start), style: UhfText.mono(size: 12)),
        nudge(UhfIcons.remove, '−1 s', () => studio.nudgeStart(-1)),
        nudge(UhfIcons.add, '+1 s', () => studio.nudgeStart(1)),
        const SizedBox(width: 16),
        Text(l.studioOut, style: label),
        const SizedBox(width: 6),
        Text(formatTimecode(trim.end), style: UhfText.mono(size: 12)),
        nudge(UhfIcons.remove, '−1 s', () => studio.nudgeEnd(-1)),
        nudge(UhfIcons.add, '+1 s', () => studio.nudgeEnd(1)),
        const Spacer(),
        Text(formatTimecode(trim.length), style: UhfText.mono(size: 12, color: UhfColors.textMuted)),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UhfColors.signal,
              borderRadius: BorderRadius.circular(UhfRadii.sm),
            ),
            child: Text(label, style: UhfText.sans(size: 13, weight: 500, color: UhfColors.ink)),
          ),
        ),
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  const _ExportBar({required this.studio});

  final StudioController studio;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final progress = studio.exportProgress!;
    final remaining = progress.remaining;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: UhfColors.line),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress.fraction.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: const ColoredBox(color: UhfColors.signal),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${(progress.fraction * 100).floor()} %', style: UhfText.mono(size: 12)),
          if (remaining != null) ...[
            const SizedBox(width: 12),
            Text(
              l.exportRemaining(formatTimecode(remaining)),
              style: UhfText.mono(size: 12, color: UhfColors.textMuted),
            ),
          ],
          const SizedBox(width: 12),
          UhfChip(label: l.actionCancel, onPressed: studio.cancelExport),
        ],
      ),
    );
  }
}
