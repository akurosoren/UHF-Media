import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/app/uhf_app.dart';

void main() {
  testWidgets('UhfApp builds a MaterialApp titled UHF Media', (tester) async {
    await tester.pumpWidget(const UhfApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'UHF Media');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
