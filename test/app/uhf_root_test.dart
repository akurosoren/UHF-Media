import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_root.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/l10n/app_localizations.dart';

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => Text(AppLocalizations.of(context).tooltipClose);
}

void main() {
  testWidgets('language follows the settings live', (tester) async {
    final dir = Directory.systemTemp.createTempSync('uhf_root_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final settings = SettingsController(SettingsStore(dir), AppSettings.defaults().copyWith(language: 'en'));
    await tester.pumpWidget(UhfRoot(settings: settings, home: const _Hint()));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);

    settings.update((s) => s.copyWith(language: 'tr'));
    await tester.pumpAndSettle();
    expect(find.text('Kapat'), findsOneWidget);
    // Let the debounced settings save fire before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });
}
