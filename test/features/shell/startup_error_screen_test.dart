import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';
import 'package:uhf_media/features/shell/startup_error_screen.dart';

void main() {
  testWidgets('startup errors are shown with their detail (final review)', (tester) async {
    await tester.pumpWidget(const UhfApp(
      locale: Locale('fr'),
      home: StartupErrorScreen(detail: 'libmpv-2.dll introuvable'),
    ));
    await tester.pumpAndSettle();
    expect(find.text("UHF Media n'a pas pu démarrer."), findsOneWidget);
    expect(find.text('libmpv-2.dll introuvable'), findsOneWidget);
  });
}
