import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/icons.dart';
import '../../ui/tokens.dart';
import '../../ui/uhf_icon_button.dart';
import 'player_controller.dart';

/// Mute button; the slider unfolds while the pointer is over it.
class VolumeControl extends StatefulWidget {
  const VolumeControl({super.key, required this.player});

  final PlayerController player;

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  bool _hover = false;
  bool _drag = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final player = widget.player;
    final silent = player.muted || player.volume == 0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UhfIconButton(
            icon: silent ? UhfIcons.volume_off : UhfIcons.volume_up,
            tooltip: player.muted ? l.tooltipUnmute : l.tooltipMute,
            onPressed: player.toggleMute,
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: _hover || _drag ? 1.0 : 0.0),
            duration: UhfDurations.base,
            curve: UhfCurves.ease,
            builder: (context, open, child) => ClipRect(
              child: Align(alignment: Alignment.centerLeft, widthFactor: open, child: child),
            ),
            child: SizedBox(
              width: 84,
              child: ExcludeFocus(
                child: Slider(
                  value: player.volume / 100,
                  onChangeStart: (_) => setState(() => _drag = true),
                  onChangeEnd: (_) => setState(() => _drag = false),
                  onChanged: (v) => player.setVolume(v * 100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
