import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/features/studio/trim_selection.dart';
import 'package:uhf_media/features/studio/trim_timeline.dart';

import '../../support/harness.dart';

Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  late TrimSelection selection;
  late List<Duration> previews;

  // 600 px for 600 s: one pixel per second.
  Future<Offset Function(double x)> pump(WidgetTester tester) async {
    selection = TrimSelection(start: s(120), end: s(240), duration: s(600));
    previews = [];
    await tester.pumpWidget(harness(Center(
      child: SizedBox(
        width: 600,
        child: StatefulBuilder(
          builder: (context, setState) => TrimTimeline(
            selection: selection,
            position: Duration.zero,
            onChanged: (next) => setState(() => selection = next),
            onPreview: previews.add,
          ),
        ),
      ),
    )));
    final origin = tester.getTopLeft(find.byType(TrimTimeline));
    return (x) => origin + Offset(x, TrimTimeline.height / 2);
  }

  testWidgets('dragging the start handle moves it and previews it', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(120), const Offset(30, 0));
    await tester.pump();
    expect(selection.start, s(150));
    expect(selection.end, s(240));
    expect(previews.last, s(150));
  });

  testWidgets('a click outside the range moves the nearest handle there', (tester) async {
    final at = await pump(tester);
    await tester.tapAt(at(500));
    await tester.pump();
    expect(selection.end, s(500));
    expect(previews.last, s(500));
  });

  testWidgets('dragging inside the range moves the whole range', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(180), const Offset(100, 0));
    await tester.pump();
    expect(selection.start, s(220));
    expect(selection.end, s(340));
    expect(previews.last, s(220));
  });

  testWidgets('the start handle stops at the minimal gap before the end', (tester) async {
    final at = await pump(tester);
    await tester.dragFrom(at(120), const Offset(300, 0));
    await tester.pump();
    expect(selection.start, s(237));
  });
}
