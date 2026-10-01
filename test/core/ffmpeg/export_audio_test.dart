import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/ffmpeg/export_command_builder.dart';
import 'package:uhf_media/core/ffmpeg/export_plan.dart';
import 'package:uhf_media/core/ffmpeg/probe_result.dart';
import 'package:uhf_media/core/geometry/rotation.dart';

ProbeResult _probe(List<AudioStreamInfo> audio) => ProbeResult(
      videoBitRate: null,
      fieldOrder: FieldOrder.progressive,
      frameRate: '25/1',
      bitDepth: 8,
      duration: const Duration(minutes: 10),
      subtitles: const [],
      audioStreams: audio,
    );

String _audioCodec(String output, List<AudioStreamInfo> audio, {int? audioFfIndex, TrimRange? trim}) {
  final args = ExportCommandBuilder.build(
    ExportPlan(
      inputPath: r'C:\v\in.m2ts',
      outputPath: output,
      rotation: Rotation.cw90,
      audioFfIndex: audioFfIndex,
      trim: trim,
    ),
    _probe(audio),
  ).args;
  return args[args.indexOf('-c:a') + 1];
}

void main() {
  const lpcm = AudioStreamInfo(index: 1, codec: 'pcm_bluray');
  const ac3 = AudioStreamInfo(index: 2, codec: 'ac3');

  test('mkv output re-encodes the selected Blu-ray LPCM track to FLAC', () {
    expect(_audioCodec(r'C:\v\in_rot90.mkv', [lpcm, ac3], audioFfIndex: 1), 'flac');
  });

  test('mkv output copies other codecs', () {
    expect(_audioCodec(r'C:\v\in_rot90.mkv', [lpcm, ac3], audioFfIndex: 2), 'copy');
  });

  test('without an ff-index the first audio stream decides', () {
    expect(_audioCodec(r'C:\v\in_rot90.mkv', [lpcm]), 'flac');
  });

  test('mov output keeps camera PCM as is', () {
    expect(_audioCodec(r'C:\v\in_rot90.mov', [const AudioStreamInfo(index: 1, codec: 'pcm_s16le')]), 'copy');
  });

  // With -ss before -i, a copied audio stream starts at the keyframe before
  // the cut while the video starts at the cut: re-encode to keep them together.
  const trim = TrimRange(Duration(seconds: 10), Duration(seconds: 20));

  test('a trim re-encodes the audio to AAC (manual check finding)', () {
    expect(_audioCodec(r'C:\v\in_rot90_trim.mkv', [lpcm, ac3], audioFfIndex: 2, trim: trim), 'aac');
    expect(
      _audioCodec(r'C:\v\in_rot90_trim.mov', [const AudioStreamInfo(index: 1, codec: 'pcm_s16le')], trim: trim),
      'aac',
    );
  });

  test('a trim of LPCM into mkv still uses FLAC', () {
    expect(_audioCodec(r'C:\v\in_rot90_trim.mkv', [lpcm], audioFfIndex: 1, trim: trim), 'flac');
  });
}
