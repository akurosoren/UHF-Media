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
      Text(l.tooltipPlay),
      Text(l.trackNumber(3)),
      Text(l.toastResumed('00:41:12')),
      Text(l.menuMonoLeft),
    ]);
  }
}

void main() {
  const expected = {
    'en': ['Play (Space)', 'Track 3', 'Resumed at 00:41:12', 'Mono from left channel'],
    'fr': ['Lecture (Espace)', 'Piste 3', 'Reprise à 00:41:12', 'Mono depuis le canal gauche'],
    'tr': ['Oynat (Boşluk)', 'Parça 3', '00:41:12 konumundan devam ediliyor', 'Sol kanaldan mono'],
  };

  for (final entry in expected.entries) {
    testWidgets('player strings in ${entry.key}', (tester) async {
      await tester.pumpWidget(UhfApp(locale: Locale(entry.key), home: const _Probe()));
      await tester.pumpAndSettle();
      for (final text in entry.value) {
        expect(find.text(text), findsOneWidget);
      }
    });
  }
}
