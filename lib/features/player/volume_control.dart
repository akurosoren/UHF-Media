import 'package:flutter/material.dart';
import '../../ui/icons.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/uhf_icon_button.dart';
import 'player_controller.dart';

class VolumeControl extends StatelessWidget {
  const VolumeControl({super.key, required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final silent = player.muted || player.volume == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UhfIconButton(
          icon: silent ? UhfIcons.volume_off : UhfIcons.volume_up,
          tooltip: player.muted ? l.tooltipUnmute : l.tooltipMute,
          onPressed: player.toggleMute,
        ),
        SizedBox(
          width: 80,
          child: ExcludeFocus(
            child: Slider(
              value: player.volume / 100,
              onChanged: (v) => player.setVolume(v * 100),
            ),
          ),
        ),
      ],
    );
  }
}
