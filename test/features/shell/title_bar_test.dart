import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/features/shell/title_bar.dart';

import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeWindowHost host;
  late ShellController shell;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_title_');
    host = FakeWindowHost();
    shell = ShellController(host, SettingsController(SettingsStore(dir), AppSettings.defaults()));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('shows the file name and runs the window buttons', (tester) async {
    var opened = false;
    await tester.pumpWidget(harness(TitleBar(shell: shell, fileName: 'clip.mkv', onOpen: () => opened = true)));
    expect(find.text('clip.mkv'), findsOneWidget);

    await tester.tap(find.byTooltip('Open (Ctrl+O)'));
    await tester.tap(find.byTooltip('Minimize'));
    await tester.tap(find.byTooltip('Maximize'));
    await tester.tap(find.byTooltip('Always on top (Ctrl+T)'));
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(opened, isTrue);
    expect(host.calls, ['minimize', 'maximize', 'top true', 'close']);
    // Always-on-top is persisted through the debounced settings save.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('dragging the middle moves the window, double-click maximizes', (tester) async {
    await tester.pumpWidget(harness(TitleBar(shell: shell, fileName: 'clip.mkv', onOpen: () {})));
    await tester.drag(find.text('clip.mkv'), const Offset(40, 0));
    expect(host.calls, contains('drag'));
    host.calls.clear();
    await tester.tap(find.text('clip.mkv'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('clip.mkv'));
    await tester.pumpAndSettle();
    expect(host.calls, ['maximize']);
  });

  testWidgets('bar is 30 px high', (tester) async {
    await tester.pumpWidget(harness(Align(
      alignment: Alignment.topCenter,
      child: TitleBar(shell: shell, fileName: null, onOpen: () {}),
    )));
    expect(tester.getSize(find.byType(TitleBar)).height, TitleBar.height);
  });
}
