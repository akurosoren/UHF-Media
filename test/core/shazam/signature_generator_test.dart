import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/shazam/signature_format.dart';
import 'package:uhf_media/core/shazam/signature_generator.dart';

import '../../support/wav.dart';

typedef _Peak = ({FrequencyBand band, int pass, int bin});

List<_Peak> _flatten(DecodedSignature s) => [
      for (final e in s.peaks.entries)
        for (final p in e.value) (band: e.key, pass: p.fftPassNumber, bin: p.correctedPeakFrequencyBin),
    ];

double _matchedShare(List<_Peak> from, List<_Peak> against) {
  if (from.isEmpty) return 1;
  var matched = 0;
  for (final a in from) {
    final hit = against.any((b) => b.band == a.band && (b.pass - a.pass).abs() <= 1 && (b.bin - a.bin).abs() <= 64);
    if (hit) matched++;
  }
  return matched / from.length;
}

void main() {
  for (final name in ['chord', 'noisy', 'sweep']) {
    test('peaks of "$name" match shazamio-core within tolerance', () {
      final pcm = readPcm16Wav('test/fixtures/shazam/$name.wav');
      final ours = SignatureGenerator.fromPcm16kMono(pcm);
      final theirs = DecodedSignature.fromDataUri(
        File('test/fixtures/shazam/$name.uri').readAsStringSync().trim(),
      );

      expect(ours.sampleRateHz, 16000);
      expect(ours.numberSamples, theirs.numberSamples);

      final a = _flatten(ours);
      final b = _flatten(theirs);
      expect(b.length, greaterThan(10), reason: 'fixture should contain peaks');
      expect(_matchedShare(a, b), greaterThanOrEqualTo(0.9), reason: 'precision ${a.length} vs ${b.length}');
      expect(_matchedShare(b, a), greaterThanOrEqualTo(0.9), reason: 'recall ${a.length} vs ${b.length}');
    });
  }

  test('peaks are sorted by pass number so the signature encodes', () {
    final pcm = readPcm16Wav('test/fixtures/shazam/chord.wav');
    final sig = SignatureGenerator.fromPcm16kMono(pcm);
    for (final list in sig.peaks.values) {
      for (var i = 1; i < list.length; i++) {
        expect(list[i].fftPassNumber, greaterThanOrEqualTo(list[i - 1].fftPassNumber));
      }
    }
    expect(() => sig.encode(), returnsNormally);
  });

  test('audio shorter than 46 blocks yields no peaks and still encodes (review focus 3)', () {
    final sig = SignatureGenerator.fromPcm16kMono(Int16List(1000));
    expect(sig.numberSamples, 1000);
    expect(sig.peaks.values.expand((p) => p), isEmpty);
    expect(sig.encode().length, 56);
  });

  test('digital silence yields no peaks', () {
    final sig = SignatureGenerator.fromPcm16kMono(Int16List(16000 * 3));
    expect(sig.peaks.values.expand((p) => p), isEmpty);
  });
}
