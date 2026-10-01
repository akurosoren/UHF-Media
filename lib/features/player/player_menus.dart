import 'package:flutter/foundation.dart';

import '../../core/media/pan_mode.dart';
import '../../core/media/track_info.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/uhf_menu.dart';
import '../settings/settings_controller.dart';
import '../shell/shell_controller.dart';
import 'player_controller.dart';

String _trackLabel(TrackInfo t, AppLocalizations l) => t.label ?? l.trackNumber(t.id);

List<UhfMenuEntry> audioMenuEntries(PlayerController player, AppLocalizations l) => [
      for (final t in player.audioTracks)
        UhfMenuEntry(label: _trackLabel(t, l), checked: t.selected, onSelected: () => player.selectAudio(t.id)),
    ];

List<UhfMenuEntry> subtitleMenuEntries(PlayerController player, AppLocalizations l) => [
      UhfMenuEntry(
        label: l.subtitlesOff,
        checked: player.selectedSubtitleId == null,
        onSelected: () => player.selectSubtitle(null),
      ),
      for (final t in player.subtitleTracks)
        UhfMenuEntry(label: _trackLabel(t, l), checked: t.selected, onSelected: () => player.selectSubtitle(t.id)),
    ];

List<UhfMenuEntry> moreMenuEntries({
  required PlayerController player,
  required ShellController shell,
  required SettingsController settings,
  required AppLocalizations l,
  required VoidCallback onSubtitleSettings,
}) {
  final language = settings.value.language;
  UhfMenuEntry lang(String code, String label) => UhfMenuEntry(
        label: label,
        checked: language == code,
        onSelected: () => settings.update((s) => s.copyWith(language: code)),
      );
  return [
    UhfMenuEntry(label: l.menuScreenshot, shortcut: 'S', onSelected: player.screenshot),
    UhfMenuEntry(
      label: l.menuMonoLeft,
      checked: player.pan == PanMode.left,
      onSelected: () => player.togglePan(PanMode.left),
    ),
    UhfMenuEntry(
      label: l.menuMonoRight,
      checked: player.pan == PanMode.right,
      onSelected: () => player.togglePan(PanMode.right),
    ),
    UhfMenuEntry(label: l.menuSubtitleSettings, onSelected: onSubtitleSettings),
    UhfMenuEntry(label: l.tooltipPin, checked: shell.alwaysOnTop, onSelected: shell.toggleAlwaysOnTop),
    UhfMenuEntry(label: l.menuLanguage, children: [
      lang('system', l.languageSystem),
      lang('en', 'English'),
      lang('fr', 'Français'),
      lang('tr', 'Türkçe'),
    ]),
  ];
}
