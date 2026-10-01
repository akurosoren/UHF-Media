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

  @override
  String get tooltipStudio => 'Stüdyo (E)';

  @override
  String get studioTrim => 'Kesme';

  @override
  String get studioIn => 'Başlangıç';

  @override
  String get studioOut => 'Bitiş';

  @override
  String get tooltipCrop => 'Kırpma (C)';

  @override
  String get cropOff => 'Kapalı';

  @override
  String get cropFree => 'Serbest';

  @override
  String get actionExport => 'Dışa aktar';

  @override
  String exportRemaining(String time) {
    return '$time kaldı';
  }

  @override
  String get toastExportDone => 'Dışa aktarma tamamlandı';

  @override
  String get toastExportCancelled => 'Dışa aktarma iptal edildi';

  @override
  String get toastExportFailed => 'Dışa aktarma başarısız oldu';

  @override
  String get actionCopyDetails => 'Ayrıntıyı kopyala';

  @override
  String get toastExportRetryCpu =>
      'Donanım kodlama başarısız oldu, işlemciyle yeniden deneniyor';

  @override
  String get toastNoChanges => 'Önce bir döndürme, kırpma ya da kesme seç';

  @override
  String get toastTrimTooShort => 'Kesme aralığı çok kısa';

  @override
  String get toastCropTooSmall => 'Kırpma alanı çok küçük';

  @override
  String toastFfmpegMissing(String folder) {
    return 'ffmpeg bulunamadı: ffmpeg.exe ve ffprobe.exe dosyalarını $folder klasörüne koy';
  }

  @override
  String get menuIdentifyMusic => 'Müziği tanı';

  @override
  String get menuAutoRename => 'Tanımadan sonra otomatik yeniden adlandır';

  @override
  String get toastListening => 'Dinleniyor…';

  @override
  String get toastMusicNotFound => 'Şarkı tanınamadı';

  @override
  String get toastMusicFailed => 'Tanıma başarısız oldu; bağlantını kontrol et';

  @override
  String get actionRenameFile => 'Dosyayı yeniden adlandır';

  @override
  String get actionCopy => 'Kopyala';

  @override
  String get actionUndo => 'Geri al';

  @override
  String toastRenamed(String name) {
    return '$name olarak yeniden adlandırıldı';
  }

  @override
  String get toastRenameFailed => 'Dosya yeniden adlandırılamadı';
}
