import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/settings/resume_store.dart';

void main() {
  late Directory dir;
  var clock = DateTime(2026, 10, 1);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('uhf_resume_');
    clock = DateTime(2026, 10, 1);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ResumeStore store({int max = 500}) => ResumeStore(dir, now: () => clock, maxEntries: max);
  const movie = Duration(hours: 2);

  test('applies only between 10 s from the start and 30 s from the end', () async {
    final s = store()..record(r'C:\v\a.mkv', const Duration(minutes: 41));
    expect(s.resumePositionFor(r'C:\v\a.mkv', movie), const Duration(minutes: 41));

    s.record(r'C:\v\a.mkv', const Duration(seconds: 10));
    expect(s.resumePositionFor(r'C:\v\a.mkv', movie), isNull);

    s.record(r'C:\v\a.mkv', movie - const Duration(seconds: 30));
    expect(s.resumePositionFor(r'C:\v\a.mkv', movie), isNull);
  });

  test('keys ignore case and separators style', () async {
    final s = store()..record(r'C:\Videos\A.MKV', const Duration(minutes: 5));
    expect(s.resumePositionFor('c:/videos/a.mkv', movie), const Duration(minutes: 5));
  });

  test('flush writes nothing until something changed', () async {
    final s = store();
    await s.flush();
    expect(File('${dir.path}/resume.json').existsSync(), isFalse);
    s.record(r'C:.mkv', const Duration(minutes: 3));
    await s.flush();
    expect(File('${dir.path}/resume.json').existsSync(), isTrue);
  });

  test('a failed flush is retried by the next one', () async {
    final blocker = File('${dir.path}/blocker')..writeAsStringSync('');
    final s = ResumeStore(Directory('${blocker.path}/sub'))..record(r'C:\v\a.mkv', const Duration(minutes: 3));
    await expectLater(s.flush(), throwsA(isA<FileSystemException>()));
    blocker.deleteSync();
    await s.flush();
    expect(File('${blocker.path}/sub/resume.json').existsSync(), isTrue);
  });

  test('persists across instances', () async {
    final a = store()..record(r'C:\v\a.mkv', const Duration(minutes: 3));
    await a.flush();
    final b = store();
    await b.load();
    expect(b.resumePositionFor(r'C:\v\a.mkv', movie), const Duration(minutes: 3));
  });

  test('clear and migrate', () async {
    final s = store()..record(r'C:\v\old.mkv', const Duration(minutes: 3));
    s.migrate(r'C:\v\old.mkv', r'C:\v\Artist - Title.mkv');
    expect(s.resumePositionFor(r'C:\v\old.mkv', movie), isNull);
    expect(s.resumePositionFor(r'C:\v\Artist - Title.mkv', movie), const Duration(minutes: 3));
    s.clear(r'C:\v\Artist - Title.mkv');
    expect(s.resumePositionFor(r'C:\v\Artist - Title.mkv', movie), isNull);
  });

  test('keeps only the most recent entries', () async {
    final s = store(max: 3);
    for (var i = 0; i < 5; i++) {
      clock = clock.add(const Duration(minutes: 1));
      s.record('C:\\v\\$i.mkv', const Duration(minutes: 5));
    }
    expect(s.length, 3);
    expect(s.resumePositionFor(r'C:\v\0.mkv', movie), isNull);
    expect(s.resumePositionFor(r'C:\v\4.mkv', movie), const Duration(minutes: 5));
  });

  test('corrupted file starts empty (review focus 5)', () async {
    File('${dir.path}/resume.json').writeAsStringSync('garbage');
    final s = store();
    await s.load();
    expect(s.length, 0);
    expect(File('${dir.path}/resume.json.bak').existsSync(), isTrue);
  });
}
