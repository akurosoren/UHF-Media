import '../settings/settings_controller.dart';
import 'player_controller.dart';

void bindPlayerSettings(PlayerController player, SettingsController settings) {
  player.addListener(() {
    settings.update((s) => s.copyWith(
          volume: player.volume,
          muted: player.muted,
          subtitleScale: player.subtitleScale,
          subtitlePos: player.subtitlePos,
        ));
  });
}
