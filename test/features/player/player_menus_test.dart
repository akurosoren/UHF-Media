import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/player/player_menus.dart';
import 'package:uhf_media/features/player/subtitle_settings_dialog.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';
import 'package:uhf_media/features/shell/shell_controller.dart';
import 'package:uhf_media/l10n/app_localizations_en.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_window_host.dart';
import '../../support/harness.dart';

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late SettingsController settings;
  late ShellController shell;
  final l = AppLocalizationsEn();

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('uhf_menus_');
    engine = FakeMediaEngine()
      ..tracks = const [
        TrackInfo(type: TrackType.audio, id: 1, language: 'fre', selected: true),
        TrackInfo(type: TrackType.audio, id: 2),
        TrackInfo(type: TrackType.subtitle, id: 4, language: 'eng'),
      ];
    player = PlayerController(engine: engine, resume: ResumeStore(dir), fileExists: (_) => true);
    settings = SettingsController(SettingsStore(dir), AppSettings.defaults());
    shell = ShellController(FakeWindowHost(), settings);
    await player.open(r'C:\v\a.mkv');
    await player.refreshTracks();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('audio entries show labels, numbered fallback and selection', () async {
    final entries = audioMenuEntries(player, l);
    expect(entries.map((e) => e.label), ['FRE', 'Track 2']);
    expect(entries.map((e) => e.checked), [true, false]);
    entries[1].onSelected!();
    await Future<void>.delayed(Duration.zero);
    expect(engine.calls, contains('aid 2'));
  });

  test('subtitle entries start with Off, checked when nothing is selected', () async {
    final entries = subtitleMenuEntries(player, l);
    expect(entries.map((e) => e.label), ['Off', 'ENG']);
    expect(entries.first.checked, isTrue);
    entries[1].onSelected!();
    await Future<void>.delayed(Duration.zero);
    expect(engine.calls, contains('sid 4'));
  });

  test('more menu toggles mono, always on top and language', () async {
    var opened = false;
    final entries = moreMenuEntries(
      player: player,
      shell: shell,
      settings: settings,
      l: l,
      onSubtitleSettings: () => opened = true,
    );
    expect(entries.map((e) => e.label), [
      'Screenshot',
      'Mono from left channel',
      'Mono from right channel',
      'Subtitle settings…',
      'Always on top (Ctrl+T)',
      'Language',
    ]);
    entries[1].onSelected!();
    await Future<void>.delayed(Duration.zero);
    expect(player.pan, PanMode.left);
    entries[3].onSelected!();
    expect(opened, isTrue);
    final languages = entries.last.children!;
    expect(languages.map((e) => e.label), ['System', 'English', 'Français', 'Türkçe']);
    languages[3].onSelected!();
    expect(settings.value.language, 'tr');
  });

  testWidgets('subtitle dialog previews live, cancel restores, apply keeps', (tester) async {
    await tester.pumpWidget(harness(Builder(
      builder: (context) => TextButton(
        onPressed: () => showSubtitleSettings(context, player),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Size'), findsOneWidget);

    engine.calls.clear();
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();
    expect(engine.calls.any((c) => c.startsWith('sub-scale ')), isTrue);
    expect(player.subtitleScale, 100);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(engine.calls.reversed.take(2), containsAll(['sub-scale 100', 'sub-pos 100']));
    expect(player.subtitleScale, 100);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(player.subtitleScale, greaterThan(100));
  });
}
