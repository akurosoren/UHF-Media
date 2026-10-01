import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';
import 'package:uhf_media/l10n/app_localizations.dart';

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Text(AppLocalizations.of(context).idleHint);
}

void main() {
  const cases = {
    'en': 'Drop a video here · Ctrl+O',
    'fr': 'Glisse une vidéo ici · Ctrl+O',
    'tr': 'Bir videoyu buraya sürükleyin · Ctrl+O',
    'de': 'Drop a video here · Ctrl+O',
  };

  for (final entry in cases.entries) {
    testWidgets('idleHint in ${entry.key}', (tester) async {
      await tester.pumpWidget(UhfApp(locale: Locale(entry.key), home: const _Hint()));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  test('supported locales are en, fr and tr', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      {'en', 'fr', 'tr'},
    );
  });
}
