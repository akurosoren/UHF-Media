import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/media/pan_mode.dart';
import 'package:uhf_media/core/media/track_info.dart';

const _json = '''
[
  {"id": 1, "type": "video", "ff-index": 0, "selected": true, "codec": "h264"},
  {"id": 1, "type": "audio", "ff-index": 1, "selected": true, "lang": "fre", "title": "VF 5.1"},
  {"id": 2, "type": "audio", "ff-index": 2, "lang": "eng"},
  {"id": 1, "type": "sub", "ff-index": 3, "lang": "eng"},
  {"id": 2, "type": "sub", "external": true, "title": "film.srt"},
  {"id": 3, "type": "sub"},
  {"type": "audio"},
  {"id": "x", "type": "audio"},
  {"id": 9, "type": "attachment"}
]
''';

void main() {
  test('parses video, audio and subtitle tracks', () {
    final tracks = parseTrackList(_json);
    expect(tracks.length, 6);
    expect(tracks.where((t) => t.type == TrackType.audio).map((t) => t.id), [1, 2]);
    final video = tracks.first;
    expect(video.type, TrackType.video);
    expect(video.ffIndex, 0);
    expect(video.selected, isTrue);
    expect(video.codec, 'h264');
  });

  test('external subtitles have no ff-index', () {
    final ext = parseTrackList(_json).firstWhere((t) => t.external);
    expect(ext.type, TrackType.subtitle);
    expect(ext.ffIndex, isNull);
  });

  test('label joins title and upper-case language', () {
    final tracks = parseTrackList(_json);
    expect(tracks[1].label, 'VF 5.1 · FRE');
    expect(tracks[2].label, 'ENG');
    expect(tracks[4].label, 'film.srt');
    expect(tracks[5].label, isNull);
  });

  test('invalid JSON and non-lists give an empty list', () {
    expect(parseTrackList('not json'), isEmpty);
    expect(parseTrackList('{"id": 1}'), isEmpty);
    expect(parseTrackList(''), isEmpty);
  });

  test('pan modes map to mpv audio filters', () {
    expect(PanMode.stereo.audioFilter, '');
    expect(PanMode.left.audioFilter, 'lavfi=[pan=stereo|c0=c0|c1=c0]');
    expect(PanMode.right.audioFilter, 'lavfi=[pan=stereo|c0=c1|c1=c1]');
  });
}
