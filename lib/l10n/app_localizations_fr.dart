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

  @override
  String get startupFailed => 'UHF Media n\'a pas pu démarrer.';

  @override
  String get tooltipStudio => 'Studio (E)';

  @override
  String get studioTrim => 'Découpe';

  @override
  String get studioIn => 'Entrée';

  @override
  String get studioOut => 'Sortie';

  @override
  String get tooltipCrop => 'Cadre (C)';

  @override
  String get cropOff => 'Désactivé';

  @override
  String get cropFree => 'Libre';

  @override
  String get actionExport => 'Exporter';

  @override
  String exportRemaining(String time) {
    return 'reste $time';
  }

  @override
  String get toastExportDone => 'Export terminé';

  @override
  String get toastExportCancelled => 'Export annulé';

  @override
  String get toastExportFailed => 'L\'export a échoué';

  @override
  String get actionCopyDetails => 'Copier le détail';

  @override
  String get toastExportRetryCpu =>
      'L\'encodage matériel a échoué, nouvel essai sur le processeur';

  @override
  String get toastNoChanges =>
      'Choisis d\'abord une rotation, un cadre ou une découpe';

  @override
  String get toastTrimTooShort => 'La découpe est trop courte';

  @override
  String get toastCropTooSmall => 'Le cadre est trop petit';

  @override
  String toastFfmpegMissing(String folder) {
    return 'ffmpeg est introuvable : place ffmpeg.exe et ffprobe.exe dans $folder';
  }

  @override
  String get menuIdentifyMusic => 'Identifier la musique';

  @override
  String get menuAutoRename => 'Renommer automatiquement après identification';

  @override
  String get toastListening => 'Écoute en cours…';

  @override
  String get toastMusicNotFound => 'Aucun morceau reconnu';

  @override
  String get toastMusicFailed =>
      'L\'identification a échoué ; vérifie ta connexion';

  @override
  String get actionRenameFile => 'Renommer le fichier';

  @override
  String get actionCopy => 'Copier';

  @override
  String get actionUndo => 'Annuler';

  @override
  String toastRenamed(String name) {
    return 'Renommé en $name';
  }

  @override
  String get toastRenameFailed => 'Impossible de renommer le fichier';
}
