import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';
import 'package:uhf_media/l10n/app_localizations.dart';

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(children: [
      Text(l.tooltipStudio),
      Text(l.toastExportCancelled),
      Text(l.exportRemaining('00:01:12')),
      Text(l.toastRenamed('A - B.mp3')),
      Text(l.toastFfmpegMissing(r'C:\App')),
    ]);
  }
}

void main() {
  const expected = {
    'en': [
      'Studio (E)',
      'Export cancelled',
      '00:01:12 left',
      'Renamed to A - B.mp3',
      r'ffmpeg is missing: put ffmpeg.exe and ffprobe.exe in C:\App',
    ],
    'fr': [
      'Studio (E)',
      'Export annulé',
      'reste 00:01:12',
      'Renommé en A - B.mp3',
      r'ffmpeg est introuvable : place ffmpeg.exe et ffprobe.exe dans C:\App',
    ],
    'tr': [
      'Stüdyo (E)',
      'Dışa aktarma iptal edildi',
      '00:01:12 kaldı',
      'A - B.mp3 olarak yeniden adlandırıldı',
      r'ffmpeg bulunamadı: ffmpeg.exe ve ffprobe.exe dosyalarını C:\App klasörüne koy',
    ],
  };

  for (final entry in expected.entries) {
    testWidgets('studio and music strings in ${entry.key}', (tester) async {
      await tester.pumpWidget(UhfApp(locale: Locale(entry.key), home: const _Probe()));
      await tester.pumpAndSettle();
      for (final text in entry.value) {
        expect(find.text(text), findsOneWidget);
      }
    });
  }
}
