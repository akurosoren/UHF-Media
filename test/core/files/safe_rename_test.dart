import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/files/safe_rename.dart';

void main() {
  bool none(String _) => false;

  test('sanitizeFileStem removes forbidden characters and trailing dots', () {
    expect(sanitizeFileStem(r'AC/DC: Back <In> "Black"?*|\ '), 'ACDC Back In Black');
    expect(sanitizeFileStem('Song...'), 'Song');
    expect(sanitizeFileStem('Tab\tName'), 'TabName');
  });

  test('builds Artist - Title with the original extension', () {
    expect(
      renameTarget(r'C:\m\track01.mp3', 'Sezen Aksu', 'Gülümse', exists: none),
      r'C:\m\Sezen Aksu - Gülümse.mp3',
    );
  });

  test('collisions get (1), (2)', () {
    final taken = {r'C:\m\A - B.mkv', r'C:\m\A - B (1).mkv'};
    expect(renameTarget(r'C:\m\x.mkv', 'A', 'B', exists: taken.contains), r'C:\m\A - B (2).mkv');
  });

  test('same name, ignoring case, means no rename', () {
    expect(renameTarget(r'C:\m\a - b.mp3', 'A', 'B', exists: (_) => true), isNull);
  });

  test('empty name after cleaning means no rename', () {
    expect(renameTarget(r'C:\m\x.mp3', '???', '', exists: none), isNull);
  });
}
