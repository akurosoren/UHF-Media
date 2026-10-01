// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'UHF Media';

  @override
  String get idleHint => 'Drop a video here · Ctrl+O';

  @override
  String get tooltipOpen => 'Open (Ctrl+O)';

  @override
  String get tooltipPin => 'Always on top (Ctrl+T)';

  @override
  String get tooltipMinimize => 'Minimize';

  @override
  String get tooltipMaximize => 'Maximize';

  @override
  String get tooltipRestore => 'Restore';

  @override
  String get tooltipClose => 'Close';

  @override
  String get tooltipPlay => 'Play (Space)';

  @override
  String get tooltipPause => 'Pause (Space)';

  @override
  String get tooltipMute => 'Mute (M)';

  @override
  String get tooltipUnmute => 'Unmute (M)';

  @override
  String get tooltipAudioTrack => 'Audio track';

  @override
  String get tooltipSubtitles => 'Subtitles';

  @override
  String get tooltipMore => 'More';

  @override
  String get tooltipFullscreen => 'Fullscreen (F)';

  @override
  String get tooltipExitFullscreen => 'Exit fullscreen (Esc)';

  @override
  String get subtitlesOff => 'Off';

  @override
  String trackNumber(int number) {
    return 'Track $number';
  }

  @override
  String get menuScreenshot => 'Screenshot';

  @override
  String get menuMonoLeft => 'Mono from left channel';

  @override
  String get menuMonoRight => 'Mono from right channel';

  @override
  String get menuSubtitleSettings => 'Subtitle settings…';

  @override
  String get menuLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get subtitleSize => 'Size';

  @override
  String get subtitlePosition => 'Position';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionRestart => 'Restart';

  @override
  String get actionShow => 'Show';

  @override
  String toastResumed(String time) {
    return 'Resumed at $time';
  }

  @override
  String get toastScreenshotSaved => 'Screenshot saved';

  @override
  String get toastOpenFailed => 'Couldn\'t open this file';

  @override
  String get dialogOpenTitle => 'Open a video';

  @override
  String get startupFailed => 'UHF Media could not start.';

  @override
  String get tooltipStudio => 'Studio (E)';

  @override
  String get studioTrim => 'Trim';

  @override
  String get studioIn => 'In';

  @override
  String get studioOut => 'Out';

  @override
  String get tooltipCrop => 'Crop (C)';

  @override
  String get cropOff => 'Off';

  @override
  String get cropFree => 'Free';

  @override
  String get actionExport => 'Export';

  @override
  String exportRemaining(String time) {
    return '$time left';
  }

  @override
  String get toastExportDone => 'Export finished';

  @override
  String get toastExportCancelled => 'Export cancelled';

  @override
  String get toastExportFailed => 'The export failed';

  @override
  String get actionCopyDetails => 'Copy details';

  @override
  String get toastExportRetryCpu =>
      'Hardware encoding failed, retrying on the CPU';

  @override
  String get toastNoChanges => 'Choose a rotation, a crop or a trim first';

  @override
  String get toastTrimTooShort => 'The trim is too short';

  @override
  String get toastCropTooSmall => 'The crop is too small';

  @override
  String toastFfmpegMissing(String folder) {
    return 'ffmpeg is missing: put ffmpeg.exe and ffprobe.exe in $folder';
  }

  @override
  String get menuIdentifyMusic => 'Identify music';

  @override
  String get menuAutoRename => 'Rename automatically after identification';

  @override
  String get toastListening => 'Listening…';

  @override
  String get toastMusicNotFound => 'No song recognized';

  @override
  String get toastMusicFailed => 'Identification failed; check your connection';

  @override
  String get actionRenameFile => 'Rename the file';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionUndo => 'Undo';

  @override
  String toastRenamed(String name) {
    return 'Renamed to $name';
  }

  @override
  String get toastRenameFailed => 'Couldn\'t rename the file';
}
