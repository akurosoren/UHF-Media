import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/typography.dart';
import 'player_controller.dart';

Future<void> showSubtitleSettings(BuildContext context, PlayerController player) async {
  final originalScale = player.subtitleScale;
  final originalPos = player.subtitlePos;
  final applied = await showDialog<bool>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (_) => _SubtitleSettingsDialog(player: player),
  );
  if (applied != true) await player.previewSubtitleStyle(originalScale, originalPos);
}

class _SubtitleSettingsDialog extends StatefulWidget {
  const _SubtitleSettingsDialog({required this.player});

  final PlayerController player;

  @override
  State<_SubtitleSettingsDialog> createState() => _SubtitleSettingsDialogState();
}

class _SubtitleSettingsDialogState extends State<_SubtitleSettingsDialog> {
  late int _scale = widget.player.subtitleScale;
  late int _pos = widget.player.subtitlePos;

  void _preview() => widget.player.previewSubtitleStyle(_scale, _pos);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget row(String label, int value, int min, int max, ValueChanged<int> onChanged) => Row(
          children: [
            SizedBox(width: 72, child: Text(label, style: UhfText.body)),
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.right, style: UhfText.mono())),
          ],
        );

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(l.subtitleSize, _scale, 50, 300, (v) {
              setState(() => _scale = v);
              _preview();
            }),
            row(l.subtitlePosition, _pos, 0, 100, (v) {
              setState(() => _pos = v);
              _preview();
            }),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.actionCancel)),
        TextButton(
          onPressed: () async {
            await widget.player.commitSubtitleStyle(_scale, _pos);
            if (context.mounted) Navigator.of(context).pop(true);
          },
          child: Text(l.actionApply),
        ),
      ],
    );
  }
}
