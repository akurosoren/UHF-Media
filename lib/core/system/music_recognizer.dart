import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../shazam/audio_level.dart';
import '../shazam/shazam_client.dart';
import '../shazam/signature_format.dart';
import '../shazam/signature_generator.dart';
import '../util/time_format.dart';

/// Top-level so the isolate closure captures only the samples.
Future<DecodedSignature> _signatureOf(Int16List samples) =>
    Isolate.run(() => SignatureGenerator.fromPcm16kMono(samples));

typedef BytesRunner = Future<(int, Uint8List)> Function(String executable, List<String> arguments);

Future<(int, Uint8List)> _runForBytes(String executable, List<String> arguments) async {
  final r = await Process.run(executable, arguments, stdoutEncoding: null, stderrEncoding: null);
  final out = r.stdout;
  return (r.exitCode, out is Uint8List ? out : Uint8List.fromList(out as List<int>));
}

/// Signed 16-bit little-endian samples, as `ffmpeg -f s16le` writes them.
Int16List pcm16FromBytes(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final samples = Int16List(bytes.length ~/ 2);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = data.getInt16(i * 2, Endian.little);
  }
  return samples;
}

sealed class MusicOutcome {
  const MusicOutcome();
}

class MusicFound extends MusicOutcome {
  const MusicFound(this.result);
  final RecognitionResult result;
}

class MusicNotFound extends MusicOutcome {
  const MusicNotFound();
}

class MusicFailed extends MusicOutcome {
  const MusicFailed(this.reason);
  final String reason;
}

abstract interface class MusicIdentifier {
  bool get available;
  String get expectedFolder;
  Future<MusicOutcome> identify(String path, Duration at);
}

class MusicRecognizer implements MusicIdentifier {
  MusicRecognizer({
    required String? ffmpegPath,
    required this.expectedFolder,
    required ShazamClient client,
    BytesRunner? run,
  })  : _ffmpeg = ffmpegPath,
        _client = client,
        _run = run ?? _runForBytes;

  final String? _ffmpeg;
  final ShazamClient _client;
  final BytesRunner _run;

  @override
  final String expectedFolder;

  @override
  bool get available => _ffmpeg != null;

  /// 10 s from [at], already 16 kHz mono 16-bit: no resampling in Dart.
  static List<String> extractArgs(String path, Duration at) => [
        '-v', 'error', '-ss', formatSeconds3(at), '-t', '10', '-i', path,
        '-ac', '1', '-ar', '16000', '-f', 's16le', '-',
      ];

  @override
  Future<MusicOutcome> identify(String path, Duration at) async {
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return const MusicFailed('ffmpeg.exe not found');
    (int, Uint8List) extracted;
    try {
      extracted = await _run(ffmpeg, extractArgs(path, at));
    } on ProcessException catch (e) {
      return MusicFailed(e.message);
    }
    final (code, bytes) = extracted;
    if (code != 0 || bytes.length < 2) return const MusicFailed('no audio could be read');
    final samples = pcm16FromBytes(bytes);
    if (isSilent(samples)) return const MusicNotFound();
    try {
      final signature = await _signatureOf(samples);
      final result = await _client.recognize(signature);
      return result == null ? const MusicNotFound() : MusicFound(result);
    } on ShazamException catch (e) {
      return MusicFailed(e.message);
    }
  }
}
