import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/util/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_icon_button.dart';
import '../../ui/uhf_menu.dart';
import '../settings/settings_controller.dart';
import '../shell/shell_controller.dart';
import '../studio/studio_controller.dart';
import 'controls_visibility.dart';
import 'player_controller.dart';
import 'player_menus.dart';
import 'subtitle_settings_dialog.dart';
import 'timeline.dart';
import 'volume_control.dart';

class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({
    super.key,
    required this.player,
    required this.shell,
    required this.settings,
    required this.visibility,
    required this.onMenuOpenChanged,
    this.studio,
  });

  final PlayerController player;
  final ShellController shell;
  final SettingsController settings;
  final ControlsVisibility visibility;
  final ValueChanged<bool> onMenuOpenChanged;
  final StudioController? studio;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, shell, settings, visibility, ?studio]),
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final studio = this.studio;
        return IgnorePointer(
          key: const Key('controls-ignore'),
          ignoring: !visibility.visible,
          child: AnimatedOpacity(
            opacity: visibility.visible ? 1 : 0,
            duration: UhfDurations.base,
            curve: Curves.easeOut,
            child: Container(
              color: UhfColors.ink.withValues(alpha: 0.9),
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Timeline(position: player.position, duration: player.duration, onSeek: player.seekTo),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      UhfIconButton(
                        icon: player.playing ? Symbols.pause_sharp : Symbols.play_arrow_sharp,
                        tooltip: player.playing ? l.tooltipPause : l.tooltipPlay,
                        onPressed: player.togglePlay,
                      ),
                      const SizedBox(width: 10),
                      Text(formatTimecode(player.position), style: UhfText.mono()),
                      const SizedBox(width: 6),
                      Text('/ ${formatTimecode(player.duration)}', style: UhfText.mono(color: UhfColors.textMuted)),
                      const Spacer(),
                      VolumeControl(player: player),
                      const SizedBox(width: 6),
                      if (player.audioTracks.length > 1)
                        UhfMenuButton(
                          icon: Symbols.audiotrack_sharp,
                          tooltip: l.tooltipAudioTrack,
                          entries: audioMenuEntries(player, l),
                          onOpenChanged: onMenuOpenChanged,
                        ),
                      UhfMenuButton(
                        icon: Symbols.subtitles_sharp,
                        tooltip: l.tooltipSubtitles,
                        active: player.selectedSubtitleId != null,
                        entries: subtitleMenuEntries(player, l),
                        onOpenChanged: onMenuOpenChanged,
                      ),
                      UhfMenuButton(
                        icon: Symbols.more_horiz_sharp,
                        tooltip: l.tooltipMore,
                        entries: moreMenuEntries(
                          player: player,
                          shell: shell,
                          settings: settings,
                          l: l,
                          onSubtitleSettings: () => showSubtitleSettings(context, player),
                        ),
                        onOpenChanged: onMenuOpenChanged,
                      ),
                      if (studio != null)
                        UhfIconButton(
                          icon: Symbols.movie_edit_sharp,
                          tooltip: l.tooltipStudio,
                          active: studio.isOpen,
                          onPressed: studio.available ? studio.toggle : null,
                        ),
                      UhfIconButton(
                        icon: shell.fullscreen ? Symbols.fullscreen_exit_sharp : Symbols.fullscreen_sharp,
                        tooltip: shell.fullscreen ? l.tooltipExitFullscreen : l.tooltipFullscreen,
                        onPressed: shell.toggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
