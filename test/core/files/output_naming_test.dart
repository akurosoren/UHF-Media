import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/files/output_naming.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

void main() {
  bool none(String _) => false;

  test('mp4 family keeps its extension', () {
    expect(isMp4Family(r'C:\a\b.MP4'), isTrue);
    expect(isMp4Family(r'C:\a\b.mov'), isTrue);
    expect(isMp4Family(r'C:\a\b.m4v'), isTrue);
    expect(isMp4Family(r'C:\a\b.webm'), isFalse);
  });

  test('suffix order is crop, rotation, trim', () {
    expect(
      exportOutputPath(r'C:\v\clip.mp4', crop: true, rotation: Rotation.cw90, trim: true, exists: none),
      r'C:\v\clip_crop_rot90_trim.mp4',
    );
    expect(
      exportOutputPath(r'C:\v\clip.MOV', crop: false, rotation: Rotation.half, trim: false, exists: none),
      r'C:\v\clip_rot180.MOV',
    );
  });

  test('other containers become mkv', () {
    expect(
      exportOutputPath(r'C:\v\clip.webm', crop: false, rotation: Rotation.ccw90, trim: false, exists: none),
      r'C:\v\clip_rot270.mkv',
    );
    expect(
      exportOutputPath(r'C:\v\clip', crop: true, rotation: Rotation.none, trim: false, exists: none),
      r'C:\v\clip_crop.mkv',
    );
  });

  test('collisions get a numbered suffix', () {
    final taken = {r'C:\v\clip_trim.mkv', r'C:\v\clip_trim (1).mkv'};
    expect(
      exportOutputPath(r'C:\v\clip.avi', crop: false, rotation: Rotation.none, trim: true, exists: taken.contains),
      r'C:\v\clip_trim (2).mkv',
    );
  });
}
