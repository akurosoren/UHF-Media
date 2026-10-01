import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/files/media_files.dart';

void main() {
  test('subtitle files are recognised by extension, any case', () {
    expect(isSubtitleFile(r'C:\v\film.SRT'), isTrue);
    expect(isSubtitleFile(r'C:\v\film.ass'), isTrue);
    expect(isSubtitleFile(r'C:\v\film.vtt'), isTrue);
    expect(isSubtitleFile(r'C:\v\film.mkv'), isFalse);
  });

  test('media files cover video and audio', () {
    expect(isMediaFile(r'C:\v\clip.MKV'), isTrue);
    expect(isMediaFile(r'C:\m\song.flac'), isTrue);
    expect(isMediaFile(r'C:\v\notes.txt'), isFalse);
    expect(mediaExtensions, containsAll(['mp4', 'webm', 'mp3', 'opus']));
  });

  test('screenshot names are timestamped', () {
    expect(screenshotFileName(DateTime(2026, 10, 1, 9, 5, 7)), 'UHF_20261001_090507.png');
  });
}
