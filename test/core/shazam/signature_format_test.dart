import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/shazam/crc32.dart';
import 'package:uhf_media/core/shazam/signature_format.dart';

void main() {
  test('crc32 matches the zlib check value', () {
    expect(crc32('123456789'.codeUnits), 0xCBF43926);
    expect(crc32(const []), 0);
  });

  test('encode then decode round-trips peaks, including a pass gap of 255+', () {
    final sig = DecodedSignature(
      sampleRateHz: 16000,
      numberSamples: 128000,
      peaks: {
        FrequencyBand.b520_1450: const [
          FrequencyPeak(fftPassNumber: 3, peakMagnitude: 9000, correctedPeakFrequencyBin: 5000),
          FrequencyPeak(fftPassNumber: 3, peakMagnitude: 8000, correctedPeakFrequencyBin: 6000),
          FrequencyPeak(fftPassNumber: 400, peakMagnitude: 7000, correctedPeakFrequencyBin: 7000),
        ],
        FrequencyBand.b250_520: const [
          FrequencyPeak(fftPassNumber: 10, peakMagnitude: 6500, correctedPeakFrequencyBin: 2000),
        ],
      },
    );
    final bytes = sig.encode();
    expect(bytes.length % 4, 0);
    final back = DecodedSignature.decode(bytes);
    expect(back.sampleRateHz, 16000);
    expect(back.numberSamples, 128000);
    expect(back.sampleMs, 8000);
    expect(back.peaks[FrequencyBand.b520_1450]!.map((p) => p.fftPassNumber), [3, 3, 400]);
    expect(back.peaks[FrequencyBand.b250_520]!.single.correctedPeakFrequencyBin, 2000);
    expect(back.encode(), bytes);
  });

  test('an empty signature encodes to the 56-byte header', () {
    final sig = DecodedSignature(sampleRateHz: 16000, numberSamples: 1000, peaks: const {});
    final bytes = sig.encode();
    expect(bytes.length, 56);
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(0, Endian.little), 0xcafe2580);
    expect(data.getUint32(28, Endian.little), 3 << 27);
    expect(data.getUint32(40, Endian.little), 1000 + 3840);
  });

  test('a corrupted payload fails the CRC check', () {
    final bytes = DecodedSignature(sampleRateHz: 16000, numberSamples: 1000, peaks: const {}).encode();
    bytes[20] ^= 0xff;
    expect(() => DecodedSignature.decode(bytes), throwsFormatException);
  });

  for (final name in ['chord', 'noisy', 'sweep']) {
    test('shazamio-core signature "$name" decodes and re-encodes byte for byte', () {
      final uri = File('test/fixtures/shazam/$name.uri').readAsStringSync().trim();
      final sig = DecodedSignature.fromDataUri(uri);
      expect(sig.sampleRateHz, 16000);
      expect(sig.peaks.values.expand((p) => p), isNotEmpty);
      expect(sig.toDataUri(), uri);
    });
  }
}
