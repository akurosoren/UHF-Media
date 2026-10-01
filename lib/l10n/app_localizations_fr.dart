// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'UHF Media';

  @override
  String get idleHint => 'Glisse une vidéo ici · Ctrl+O';

  @override
  String get tooltipOpen => 'Ouvrir (Ctrl+O)';

  @override
  String get tooltipPin => 'Toujours au premier plan (Ctrl+T)';

  @override
  String get tooltipMinimize => 'Réduire';

  @override
  String get tooltipMaximize => 'Agrandir';

  @override
  String get tooltipRestore => 'Restaurer';

  @override
  String get tooltipClose => 'Fermer';

  @override
  String get tooltipPlay => 'Lecture (Espace)';

  @override
  String get tooltipPause => 'Pause (Espace)';

  @override
  String get tooltipMute => 'Couper le son (M)';

  @override
  String get tooltipUnmute => 'Rétablir le son (M)';

  @override
  String get tooltipAudioTrack => 'Piste audio';

  @override
  String get tooltipSubtitles => 'Sous-titres';

  @override
  String get tooltipMore => 'Plus';

  @override
  String get tooltipFullscreen => 'Plein écran (F)';

  @override
  String get tooltipExitFullscreen => 'Quitter le plein écran (Échap)';

  @override
  String get subtitlesOff => 'Désactivés';

  @override
  String trackNumber(int number) {
    return 'Piste $number';
  }

  @override
  String get menuScreenshot => 'Capture d\'écran';

  @override
  String get menuMonoLeft => 'Mono depuis le canal gauche';

  @override
  String get menuMonoRight => 'Mono depuis le canal droit';

  @override
  String get menuSubtitleSettings => 'Réglages des sous-titres…';

  @override
  String get menuLanguage => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get subtitleSize => 'Taille';

  @override
  String get subtitlePosition => 'Position';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionApply => 'Appliquer';

  @override
  String get actionRestart => 'Recommencer';

  @override
  String get actionShow => 'Afficher';

  @override
  String toastResumed(String time) {
    return 'Reprise à $time';
  }

  @override
  String get toastScreenshotSaved => 'Capture enregistrée';

  @override
  String get toastOpenFailed => 'Impossible d\'ouvrir ce fichier';

  @override
  String get dialogOpenTitle => 'Ouvrir une vidéo';
}
