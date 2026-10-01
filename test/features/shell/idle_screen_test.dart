import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';
import 'package:uhf_media/features/shell/idle_screen.dart';

IdleSignalPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is IdleSignalPainter),
  );
  return paint.painter! as IdleSignalPainter;
}

void main() {
  testWidgets('shows the logo and the localized hint', (tester) async {
    await tester.pumpWidget(const UhfApp(locale: Locale('fr')));
    await tester.pump();
    expect(find.byType(IdleScreen), findsOneWidget);
    expect(find.text('Glisse une vidéo ici · Ctrl+O'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('last signal bar blinks every 500 ms', (tester) async {
    await tester.pumpWidget(const UhfApp());
    await tester.pump();
    expect(_painter(tester).barVisible, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).barVisible, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).barVisible, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  test('painter repaints only when the blink state changes', () {
    final on = IdleSignalPainter(barVisible: true);
    expect(on.shouldRepaint(IdleSignalPainter(barVisible: true)), isFalse);
    expect(on.shouldRepaint(IdleSignalPainter(barVisible: false)), isTrue);
  });
}
