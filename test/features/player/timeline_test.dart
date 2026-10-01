import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/features/player/timeline.dart';

import '../../support/harness.dart';

Widget _timeline({required Duration duration, required ValueChanged<Duration> onSeek}) => harness(
      Center(
        child: SizedBox(
          width: 400,
          child: Timeline(position: Duration.zero, duration: duration, onSeek: onSeek),
        ),
      ),
    );

void main() {
  testWidgets('tapping seeks to the matching time', (tester) async {
    Duration? seeked;
    await tester.pumpWidget(_timeline(duration: const Duration(minutes: 100), onSeek: (d) => seeked = d));
    final box = tester.getRect(find.byType(Timeline));
    await tester.tapAt(Offset(box.left + box.width * 0.25, box.center.dy));
    expect(seeked!.inSeconds, closeTo(const Duration(minutes: 25).inSeconds, 2));
  });

  testWidgets('dragging seeks once, on release', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_timeline(duration: const Duration(minutes: 10), onSeek: seeks.add));
    final box = tester.getRect(find.byType(Timeline));
    final gesture = await tester.startGesture(Offset(box.left + 40, box.center.dy));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.moveBy(const Offset(60, 0));
    expect(seeks, isEmpty);
    await gesture.up();
    expect(seeks.length, 1);
    expect(seeks.single.inSeconds, closeTo(const Duration(minutes: 5).inSeconds, 3));
  });

  testWidgets('unknown duration never seeks (review focus 4)', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(_timeline(duration: Duration.zero, onSeek: seeks.add));
    await tester.tap(find.byType(Timeline));
    expect(seeks, isEmpty);
  });

  testWidgets('hovering shows the time under the pointer', (tester) async {
    await tester.pumpWidget(_timeline(duration: const Duration(hours: 1), onSeek: (_) {}));
    final box = tester.getRect(find.byType(Timeline));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(Offset(box.left + box.width / 2, box.center.dy));
    await tester.pump();
    expect(find.text('00:30:00'), findsOneWidget);
    await mouse.removePointer();
  });
}
