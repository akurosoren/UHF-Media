import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uhf_media/core/shazam/shazam_client.dart';
import 'package:uhf_media/core/system/music_recognizer.dart';

Uint8List _tone(double amplitude, {int seconds = 10}) {
  final data = ByteData(16000 * seconds * 2);
  for (var i = 0; i < 16000 * seconds; i++) {
    final v = (amplitude * 32767 * math.sin(2 * math.pi * 440 * i / 16000)).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  late int requests;
  setUp(() => requests = 0);

  ShazamClient client(http.Response response) => ShazamClient(
        client: MockClient((_) async {
          requests++;
          return response;
        }),
        random: math.Random(1),
      );

  final found = http.Response(
    jsonEncode({'track': {'title': 'Gülümse', 'subtitle': 'Sezen Aksu'}}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('extracts 10 s of 16 kHz mono PCM at the position, then asks Shazam', () async {
    late List<String> seen;
    final recognizer = MusicRecognizer(
      ffmpegPath: r'C:\App\ffmpeg.exe',
      expectedFolder: r'C:\App',
      client: client(found),
      run: (exe, args) async {
        expect(exe, r'C:\App\ffmpeg.exe');
        seen = args;
        return (0, _tone(0.5));
      },
    );
    final outcome = await recognizer.identify(r'C:\m\a b.mp3', const Duration(seconds: 75, milliseconds: 500));
    expect(seen, [
      '-v', 'error', '-ss', '75.500', '-t', '10', '-i', r'C:\m\a b.mp3',
      '-ac', '1', '-ar', '16000', '-f', 's16le', '-',
    ]);
    expect(outcome, isA<MusicFound>());
    final result = (outcome as MusicFound).result;
    expect(result.title, 'Gülümse');
    expect(result.artist, 'Sezen Aksu');
    expect(requests, 1);
  });

  test('silence is not sent', () async {
    final recognizer = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(found),
      run: (_, _) async => (0, Uint8List(320000)),
    );
    expect(await recognizer.identify('x.mp3', Duration.zero), isA<MusicNotFound>());
    expect(requests, 0);
  });

  test('no track in the answer is not found', () async {
    final recognizer = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(http.Response('{"matches": []}', 200)),
      run: (_, _) async => (0, _tone(0.5)),
    );
    expect(await recognizer.identify('x.mp3', Duration.zero), isA<MusicNotFound>());
  });

  test('ffmpeg errors and HTTP errors are failures', () async {
    final noAudio = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(found),
      run: (_, _) async => (1, Uint8List(0)),
    );
    expect(await noAudio.identify('x.mp3', Duration.zero), isA<MusicFailed>());
    final offline = MusicRecognizer(
      ffmpegPath: 'ffmpeg',
      expectedFolder: '',
      client: client(http.Response('down', 503)),
      run: (_, _) async => (0, _tone(0.5)),
    );
    expect(await offline.identify('x.mp3', Duration.zero), isA<MusicFailed>());
  });

  test('without ffmpeg the recognizer is unavailable', () async {
    final r = MusicRecognizer(ffmpegPath: null, expectedFolder: r'C:\App', client: client(found));
    expect(r.available, isFalse);
    expect(await r.identify('x.mp3', Duration.zero), isA<MusicFailed>());
  });

  test('PCM bytes are read little-endian, a trailing odd byte is dropped', () {
    final samples = pcm16FromBytes(Uint8List.fromList([0x01, 0x00, 0xff, 0x7f, 0x00, 0x80, 0x07]));
    expect(samples, [1, 32767, -32768]);
  });
}
