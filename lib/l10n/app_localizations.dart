import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'UHF Media'**
  String get appTitle;

  /// Hint under the UHF logo when no file is open.
  ///
  /// In en, this message translates to:
  /// **'Drop a video here · Ctrl+O'**
  String get idleHint;

  /// No description provided for @tooltipOpen.
  ///
  /// In en, this message translates to:
  /// **'Open (Ctrl+O)'**
  String get tooltipOpen;

  /// No description provided for @tooltipPin.
  ///
  /// In en, this message translates to:
  /// **'Always on top (Ctrl+T)'**
  String get tooltipPin;

  /// No description provided for @tooltipMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get tooltipMinimize;

  /// No description provided for @tooltipMaximize.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get tooltipMaximize;

  /// No description provided for @tooltipRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get tooltipRestore;

  /// No description provided for @tooltipClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tooltipClose;

  /// No description provided for @tooltipPlay.
  ///
  /// In en, this message translates to:
  /// **'Play (Space)'**
  String get tooltipPlay;

  /// No description provided for @tooltipPause.
  ///
  /// In en, this message translates to:
  /// **'Pause (Space)'**
  String get tooltipPause;

  /// No description provided for @tooltipMute.
  ///
  /// In en, this message translates to:
  /// **'Mute (M)'**
  String get tooltipMute;

  /// No description provided for @tooltipUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute (M)'**
  String get tooltipUnmute;

  /// No description provided for @tooltipAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Audio track'**
  String get tooltipAudioTrack;

  /// No description provided for @tooltipSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get tooltipSubtitles;

  /// No description provided for @tooltipMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tooltipMore;

  /// No description provided for @tooltipFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen (F)'**
  String get tooltipFullscreen;

  /// No description provided for @tooltipExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen (Esc)'**
  String get tooltipExitFullscreen;

  /// No description provided for @subtitlesOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get subtitlesOff;

  /// No description provided for @trackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track {number}'**
  String trackNumber(int number);

  /// No description provided for @menuScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot'**
  String get menuScreenshot;

  /// No description provided for @menuMonoLeft.
  ///
  /// In en, this message translates to:
  /// **'Mono from left channel'**
  String get menuMonoLeft;

  /// No description provided for @menuMonoRight.
  ///
  /// In en, this message translates to:
  /// **'Mono from right channel'**
  String get menuMonoRight;

  /// No description provided for @menuSubtitleSettings.
  ///
  /// In en, this message translates to:
  /// **'Subtitle settings…'**
  String get menuSubtitleSettings;

  /// No description provided for @menuLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get menuLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @subtitleSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get subtitleSize;

  /// No description provided for @subtitlePosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get subtitlePosition;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get actionRestart;

  /// No description provided for @actionShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get actionShow;

  /// No description provided for @toastResumed.
  ///
  /// In en, this message translates to:
  /// **'Resumed at {time}'**
  String toastResumed(String time);

  /// No description provided for @toastScreenshotSaved.
  ///
  /// In en, this message translates to:
  /// **'Screenshot saved'**
  String get toastScreenshotSaved;

  /// No description provided for @toastOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this file'**
  String get toastOpenFailed;

  /// No description provided for @dialogOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a video'**
  String get dialogOpenTitle;

  /// Shown instead of the player when startup fails (settings, window or video engine).
  ///
  /// In en, this message translates to:
  /// **'UHF Media could not start.'**
  String get startupFailed;

  /// No description provided for @tooltipStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio (E)'**
  String get tooltipStudio;

  /// No description provided for @studioTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get studioTrim;

  /// No description provided for @studioIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get studioIn;

  /// No description provided for @studioOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get studioOut;

  /// No description provided for @tooltipCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop (C)'**
  String get tooltipCrop;

  /// No description provided for @cropOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get cropOff;

  /// No description provided for @cropFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get cropFree;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @exportRemaining.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String exportRemaining(String time);

  /// No description provided for @toastExportDone.
  ///
  /// In en, this message translates to:
  /// **'Export finished'**
  String get toastExportDone;

  /// No description provided for @toastExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get toastExportCancelled;

  /// No description provided for @toastExportFailed.
  ///
  /// In en, this message translates to:
  /// **'The export failed'**
  String get toastExportFailed;

  /// No description provided for @actionCopyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get actionCopyDetails;

  /// No description provided for @toastExportRetryCpu.
  ///
  /// In en, this message translates to:
  /// **'Hardware encoding failed, retrying on the CPU'**
  String get toastExportRetryCpu;

  /// No description provided for @toastNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Choose a rotation, a crop or a trim first'**
  String get toastNoChanges;

  /// No description provided for @toastTrimTooShort.
  ///
  /// In en, this message translates to:
  /// **'The trim is too short'**
  String get toastTrimTooShort;

  /// No description provided for @toastCropTooSmall.
  ///
  /// In en, this message translates to:
  /// **'The crop is too small'**
  String get toastCropTooSmall;

  /// No description provided for @toastFfmpegMissing.
  ///
  /// In en, this message translates to:
  /// **'ffmpeg is missing: put ffmpeg.exe and ffprobe.exe in {folder}'**
  String toastFfmpegMissing(String folder);

  /// No description provided for @menuIdentifyMusic.
  ///
  /// In en, this message translates to:
  /// **'Identify music'**
  String get menuIdentifyMusic;

  /// No description provided for @menuAutoRename.
  ///
  /// In en, this message translates to:
  /// **'Rename automatically after identification'**
  String get menuAutoRename;

  /// No description provided for @toastListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get toastListening;

  /// No description provided for @toastMusicNotFound.
  ///
  /// In en, this message translates to:
  /// **'No song recognized'**
  String get toastMusicNotFound;

  /// No description provided for @toastMusicFailed.
  ///
  /// In en, this message translates to:
  /// **'Identification failed; check your connection'**
  String get toastMusicFailed;

  /// No description provided for @actionRenameFile.
  ///
  /// In en, this message translates to:
  /// **'Rename the file'**
  String get actionRenameFile;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @toastRenamed.
  ///
  /// In en, this message translates to:
  /// **'Renamed to {name}'**
  String toastRenamed(String name);

  /// No description provided for @toastRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename the file'**
  String get toastRenameFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
