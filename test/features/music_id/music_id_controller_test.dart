import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/app_settings.dart';
import 'package:uhf_media/core/settings/resume_store.dart';
import 'package:uhf_media/core/settings/settings_store.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/system/music_recognizer.dart';
import 'package:uhf_media/features/music_id/music_id_controller.dart';
import 'package:uhf_media/features/player/player_controller.dart';
import 'package:uhf_media/features/settings/settings_controller.dart';

import '../../support/fake_media_engine.dart';
import '../../support/fake_music_identifier.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _found = MusicFound(RecognitionResult(title: 'Gülümse', artist: 'Sezen Aksu'));

void main() {
  late Directory dir;
  late FakeMediaEngine engine;
  late PlayerController player;
  late FakeMusicIdentifier identifier;
  late List<String> renames;
  late List<MusicEvent> events;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_music_');
    engine = FakeMediaEngine();
    identifier = FakeMusicIdentifier();
    renames = [];
    events = [];
    player = PlayerController(
      engine: engine,
      resume: ResumeStore(dir),
      fileExists: (_) => true,
      renameFile: (from, to) async => renames.add('$from>$to'),
    );
  });
  tearDown(() async {
    for (var i = 0;; i++) {
      try {
        dir.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (i == 50) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  MusicIdController make({bool autoRename = false}) {
    final settings = SettingsController(SettingsStore(dir), AppSettings.defaults().copyWith(autoRename: autoRename));
    final c = MusicIdController(player: player, identifier: identifier, settings: settings, exists: (_) => false);
    c.events.listen(events.add);
    return c;
  }

  Future<void> openAt(String path, Duration position) async {
    await player.open(path);
    engine.emitDuration(const Duration(minutes: 4));
    engine.emitPosition(position);
    await settle();
  }

  test('identify listens at the position and shows the card', () async {
    final c = make();
    await openAt(r'C:\m\track01.mp3', const Duration(seconds: 75));
    final done = c.identify();
    await settle();
    expect(c.busy, isTrue);
    expect(identifier.calls, [r'C:\m\track01.mp3@75']);
    expect(events.single, isA<MusicListeningEvent>());
    identifier.pending!.complete(_found);
    await done;
    await settle();
    expect(c.busy, isFalse);
    expect(c.card!.text, 'Sezen Aksu - Gülümse');
    expect(renames, isEmpty);
  });

  test('a second identify while listening is ignored', () async {
    final c = make();
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    final done = c.identify();
    await settle();
    await c.identify();
    await settle();
    expect(identifier.calls, hasLength(1));
    identifier.pending!.complete(const MusicNotFound());
    await done;
    await settle();
  });

  test('automatic rename, then undo', () async {
    final c = make(autoRename: true);
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    final done = c.identify();
    await settle();
    identifier.pending!.complete(_found);
    await done;
    await settle();
    expect(renames, [r'C:\m\track01.mp3>C:\m\Sezen Aksu - Gülümse.mp3']);
    expect(player.fileName, 'Sezen Aksu - Gülümse.mp3');
    expect(c.card!.renamedFrom, r'C:\m\track01.mp3');
    expect(events.last, isA<MusicRenamedEvent>().having((e) => e.name, 'name', 'Sezen Aksu - Gülümse.mp3'));

    await c.undoRename();
    expect(renames.last, r'C:\m\Sezen Aksu - Gülümse.mp3>C:\m\track01.mp3');
    expect(player.fileName, 'track01.mp3');
    expect(c.card!.renamedFrom, isNull);
  });

  test('not found and failures leave the file alone', () async {
    final c = make(autoRename: true);
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    var done = c.identify();
    await settle();
    identifier.pending!.complete(const MusicNotFound());
    await done;
    await settle();
    expect(events.last, isA<MusicNotFoundEvent>());
    done = c.identify();
    await settle();
    identifier.pending!.complete(const MusicFailed('offline'));
    await done;
    await settle();
    expect(events.last, isA<MusicFailedEvent>());
    expect(c.card, isNull);
    expect(renames, isEmpty);
  });

  test('a result for a file closed in the meantime never renames the new one (review focus 5)', () async {
    final c = make(autoRename: true);
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    final done = c.identify();
    await settle();
    await player.open(r'C:\m\other.mp3');
    identifier.pending!.complete(_found);
    await done;
    await settle();
    expect(c.card!.path, r'C:\m\track01.mp3');
    await c.renameToResult();
    expect(renames, isEmpty);
    expect(player.fileName, 'other.mp3');
  });

  test('without ffmpeg the event names the expected folder', () async {
    identifier.isAvailable = false;
    final c = make();
    await openAt(r'C:\m\track01.mp3', Duration.zero);
    await c.identify();
    await settle();
    expect(events.single, isA<MusicUnavailableEvent>().having((e) => e.folder, 'folder', r'C:\App'));
    expect(identifier.calls, isEmpty);
  });
}
