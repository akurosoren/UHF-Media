// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'UHF Media';

  @override
  String get idleHint => 'Bir videoyu buraya sürükleyin · Ctrl+O';

  @override
  String get tooltipOpen => 'Aç (Ctrl+O)';

  @override
  String get tooltipPin => 'Her zaman üstte (Ctrl+T)';

  @override
  String get tooltipMinimize => 'Küçült';

  @override
  String get tooltipMaximize => 'Büyüt';

  @override
  String get tooltipRestore => 'Eski boyuta getir';

  @override
  String get tooltipClose => 'Kapat';

  @override
  String get tooltipPlay => 'Oynat (Boşluk)';

  @override
  String get tooltipPause => 'Duraklat (Boşluk)';

  @override
  String get tooltipMute => 'Sesi kapat (M)';

  @override
  String get tooltipUnmute => 'Sesi aç (M)';

  @override
  String get tooltipAudioTrack => 'Ses kanalı';

  @override
  String get tooltipSubtitles => 'Altyazı';

  @override
  String get tooltipMore => 'Diğer';

  @override
  String get tooltipFullscreen => 'Tam ekran (F)';

  @override
  String get tooltipExitFullscreen => 'Tam ekrandan çık (Esc)';

  @override
  String get subtitlesOff => 'Kapalı';

  @override
  String trackNumber(int number) {
    return 'Parça $number';
  }

  @override
  String get menuScreenshot => 'Ekran görüntüsü';

  @override
  String get menuMonoLeft => 'Sol kanaldan mono';

  @override
  String get menuMonoRight => 'Sağ kanaldan mono';

  @override
  String get menuSubtitleSettings => 'Altyazı ayarları…';

  @override
  String get menuLanguage => 'Dil';

  @override
  String get languageSystem => 'Sistem';

  @override
  String get subtitleSize => 'Boyut';

  @override
  String get subtitlePosition => 'Konum';

  @override
  String get actionCancel => 'İptal';

  @override
  String get actionApply => 'Uygula';

  @override
  String get actionRestart => 'Baştan başlat';

  @override
  String get actionShow => 'Göster';

  @override
  String toastResumed(String time) {
    return '$time konumundan devam ediliyor';
  }

  @override
  String get toastScreenshotSaved => 'Ekran görüntüsü kaydedildi';

  @override
  String get toastOpenFailed => 'Bu dosya açılamadı';

  @override
  String get dialogOpenTitle => 'Video aç';

  @override
  String get startupFailed => 'UHF Media başlatılamadı.';
}
