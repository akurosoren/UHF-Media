import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/util/time_format.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/icons.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_icon_button.dart';
import '../../ui/uhf_menu.dart';
import '../music_id/identify_button.dart';
import '../music_id/music_id_controller.dart';
import '../settings/settings_controller.dart';
import '../shell/shell_controller.dart';
import '../studio/studio_controller.dart';
import 'controls_visibility.dart';
import 'player_controller.dart';
import 'player_menus.dart';
import 'subtitle_settings_dialog.dart';
import 'timeline.dart';
import 'volume_control.dart';

/// The timeline and a floating glass dock over a dark scrim; both fade and
/// slide away while the pointer rests.
class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({
    super.key,
    required this.player,
    required this.shell,
    required this.settings,
    required this.visibility,
    required this.onMenuOpenChanged,
    this.studio,
    this.music,
  });

  final PlayerController player;
  final ShellController shell;
  final SettingsController settings;
  final ControlsVisibility visibility;
  final ValueChanged<bool> onMenuOpenChanged;
  final StudioController? studio;
  final MusicIdController? music;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([player, shell, settings, visibility, ?studio]),
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        return IgnorePointer(
          key: const Key('controls-ignore'),
          ignoring: !visibility.visible,
          child: AnimatedOpacity(
            opacity: visibility.visible ? 1 : 0,
            duration: UhfDurations.base,
            curve: UhfCurves.ease,
            child: AnimatedSlide(
              offset: visibility.visible ? Offset.zero : const Offset(0, 0.12),
              duration: UhfDurations.slow,
              curve: UhfCurves.ease,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0009090A), Color(0xD909090A)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(22, 40, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Timeline(position: player.position, duration: player.duration, onSeek: player.seekTo),
                    const SizedBox(height: 10),
                    FittedBox(fit: BoxFit.scaleDown, child: _dock(context, l)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dock(BuildContext context, AppLocalizations l) {
    final studio = this.studio;
    final music = this.music;
    return ClipRRect(
      borderRadius: BorderRadius.circular(UhfRadii.lg + 4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: UhfColors.glass,
            borderRadius: BorderRadius.circular(UhfRadii.lg + 4),
            border: Border.all(color: UhfColors.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UhfIconButton(
                icon: UhfIcons.replay_10,
                tooltip: '−10 s',
                onPressed: () => player.seekRelative(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 2),
              _PlayButton(
                playing: player.playing,
                tooltip: player.playing ? l.tooltipPause : l.tooltipPlay,
                onPressed: player.togglePlay,
              ),
              const SizedBox(width: 2),
              UhfIconButton(
                icon: UhfIcons.forward_10,
                tooltip: '+10 s',
                onPressed: () => player.seekRelative(const Duration(seconds: 10)),
              ),
              const SizedBox(width: 12),
              Text(formatTimecode(player.position), style: UhfText.mono()),
              const SizedBox(width: 6),
              Text('/ ${formatTimecode(player.duration)}', style: UhfText.mono(color: UhfColors.textMuted)),
              const SizedBox(width: 14),
              if (music != null) ...[IdentifyButton(music: music), const SizedBox(width: 10)],
              VolumeControl(player: player),
              const SizedBox(width: 4),
              if (player.audioTracks.length > 1)
                UhfMenuButton(
                  icon: UhfIcons.audiotrack,
                  tooltip: l.tooltipAudioTrack,
                  entries: audioMenuEntries(player, l),
                  onOpenChanged: onMenuOpenChanged,
                ),
              UhfMenuButton(
                icon: UhfIcons.subtitles,
                tooltip: l.tooltipSubtitles,
                active: player.selectedSubtitleId != null,
                entries: subtitleMenuEntries(player, l),
                onOpenChanged: onMenuOpenChanged,
              ),
              if (studio != null)
                UhfIconButton(
                  icon: UhfIcons.movie_edit,
                  tooltip: l.tooltipStudio,
                  active: studio.isOpen,
                  onPressed: studio.available ? studio.toggle : null,
                ),
              UhfMenuButton(
                icon: UhfIcons.more_horiz,
                tooltip: l.tooltipMore,
                entries: moreMenuEntries(
                  player: player,
                  shell: shell,
                  settings: settings,
                  l: l,
                  onSubtitleSettings: () => showSubtitleSettings(context, player),
                  music: music,
                ),
                onOpenChanged: onMenuOpenChanged,
              ),
              UhfIconButton(
                icon: shell.fullscreen ? UhfIcons.fullscreen_exit : UhfIcons.fullscreen,
                tooltip: shell.fullscreen ? l.tooltipExitFullscreen : l.tooltipFullscreen,
                onPressed: shell.toggleFullscreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round play / pause button; the icon turns and swaps with a short fade.
class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.playing, required this.tooltip, required this.onPressed});

  final bool playing;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => _down = true),
            onTapUp: (_) => setState(() => _down = false),
            onTapCancel: () => setState(() => _down = false),
            child: AnimatedScale(
              scale: _down ? 0.92 : (_hover ? 1.06 : 1),
              duration: UhfDurations.fast,
              curve: UhfCurves.spring,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: UhfColors.text, shape: BoxShape.circle),
                child: AnimatedSwitcher(
                  duration: UhfDurations.base,
                  switchInCurve: UhfCurves.ease,
                  transitionBuilder: (child, animation) => RotationTransition(
                    turns: Tween(begin: 0.12, end: 0.0).animate(animation),
                    child: ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
                  ),
                  child: Icon(
                    widget.playing ? UhfIcons.pause : UhfIcons.play_arrow,
                    key: ValueKey(widget.playing),
                    size: 26,
                    weight: 400,
                    color: UhfColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
