import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/ui/icons.dart';
import 'package:uhf_media/ui/theme.dart';
import 'package:uhf_media/ui/toast.dart';
import 'package:uhf_media/ui/tokens.dart';
import 'package:uhf_media/ui/uhf_icon_button.dart';
import 'package:uhf_media/ui/uhf_menu.dart';

import '../support/harness.dart';

void main() {
  testWidgets('icon button taps, shows its tooltip and never takes focus', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(Center(
      child: UhfIconButton(icon: UhfIcons.play_arrow, tooltip: 'Play', onPressed: () => taps++),
    )));
    await tester.tap(find.byType(UhfIconButton));
    expect(taps, 1);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isNot(isA<UhfIconButton>()));
  });

  testWidgets('active icon button uses the signal colour', (tester) async {
    await tester.pumpWidget(harness(Center(
      child: UhfIconButton(icon: UhfIcons.push_pin, tooltip: 'Pin', onPressed: () {}, active: true),
    )));
    expect(tester.widget<Icon>(find.byType(Icon)).color, UhfColors.signal);
  });

  testWidgets('menu opens, shows a check mark and runs the selected entry', (tester) async {
    String? picked;
    await tester.pumpWidget(harness(Center(
      child: UhfMenuButton(
        icon: UhfIcons.subtitles,
        tooltip: 'Subtitles',
        entries: [
          UhfMenuEntry(label: 'Off', checked: true, onSelected: () => picked = 'off'),
          UhfMenuEntry(label: 'ENG', checked: false, onSelected: () => picked = 'eng'),
        ],
      ),
    )));
    await tester.tap(find.byType(UhfIconButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(UhfIcons.check), findsOneWidget);
    await tester.tap(find.text('ENG'));
    await tester.pumpAndSettle();
    expect(picked, 'eng');
    expect(find.text('Off'), findsNothing);
  });

  testWidgets('toast shows, runs its action and hides after its delay', (tester) async {
    final toasts = ToastController();
    var restarted = false;
    await tester.pumpWidget(harness(Stack(children: [ToastHost(controller: toasts)])));

    toasts.show('Resumed at 00:41:12', actionLabel: 'Restart', onAction: () => restarted = true);
    await tester.pump();
    expect(find.text('Resumed at 00:41:12'), findsOneWidget);
    await tester.tap(find.text('Restart'));
    await tester.pump(UhfDurations.base);
    expect(restarted, isTrue);
    expect(toasts.current, isNull);

    toasts.show('Screenshot saved');
    await tester.pump();
    await tester.pump(UhfDurations.toast);
    await tester.pumpAndSettle();
    expect(find.text('Screenshot saved'), findsNothing);
  });

  test('theme styles menus and sliders flat', () {
    final theme = buildUhfTheme();
    expect(theme.menuTheme.style!.backgroundColor!.resolve({}), UhfColors.raised);
    expect(theme.menuTheme.style!.elevation!.resolve({}), 0);
    expect(theme.sliderTheme.trackHeight, 2);
  });
}
