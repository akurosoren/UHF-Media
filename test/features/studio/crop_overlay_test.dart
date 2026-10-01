import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/geometry/geometry.dart';
import 'package:uhf_media/features/studio/crop_overlay.dart';

import '../../support/harness.dart';

void main() {
  late RatioRect crop;

  // Picture of 1000 x 500 px, crop at (100, 50) - (600, 300).
  Future<Offset Function(double x, double y)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    crop = const RatioRect(0.1, 0.1, 0.5, 0.5);
    await tester.pumpWidget(harness(Center(
      child: SizedBox(
        width: 1000,
        height: 500,
        child: StatefulBuilder(
          builder: (context, setState) => CropOverlay(
            crop: crop,
            lockRatio: null,
            label: '960 × 540 · 16:9',
            onChanged: (next) => setState(() => crop = next),
          ),
        ),
      ),
    )));
    final origin = tester.getTopLeft(find.byType(CropOverlay));
    return (x, y) => origin + Offset(x, y);
  }

  testWidgets('the bottom-right corner resizes the frame', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(600, 300), const Offset(100, 50));
    await tester.pump();
    expect(crop.width, closeTo(0.6, 1e-9));
    expect(crop.height, closeTo(0.6, 1e-9));
    expect(crop.left, closeTo(0.1, 1e-9));
  });

  testWidgets('dragging inside moves the frame', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(300, 150), const Offset(100, 50));
    await tester.pump();
    expect(crop.left, closeTo(0.2, 1e-9));
    expect(crop.top, closeTo(0.2, 1e-9));
    expect(crop.width, closeTo(0.5, 1e-9));
  });

  testWidgets('dragging outside the frame changes nothing', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(900, 450), const Offset(-100, -50));
    await tester.pump();
    expect(crop, const RatioRect(0.1, 0.1, 0.5, 0.5));
  });

  testWidgets('the output label is shown', (tester) async {
    await pump(tester);
    expect(find.text('960 × 540 · 16:9'), findsOneWidget);
  });
}
