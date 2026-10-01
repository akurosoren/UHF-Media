// Shazam fingerprinting, ported from shazamio-core
// (src/fingerprinting/algorithm.rs, MIT License).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'signature_format.dart';

abstract final class SignatureGenerator {
  static DecodedSignature fromPcm16kMono(Int16List samples) {
    final state = _State();
    final chunkCount = samples.length ~/ 128;
    for (var c = 0; c < chunkCount; c++) {
      state.doFft(samples, c * 128);
      state.doPeakSpreading();
      state.numSpreadFftsDone++;
      if (state.numSpreadFftsDone >= 46) state.doPeakRecognition();
    }
    return DecodedSignature(sampleRateHz: 16000, numberSamples: samples.length, peaks: state.peaks);
  }
}

// numpy.hanning(2050)[1:-1], the window shazamio-core tabulates.
final Float64List _hanning = Float64List.fromList(
  List.generate(2048, (i) => 0.5 - 0.5 * math.cos(2 * math.pi * (i + 1) / 2049)),
);

const _neighborOffsets = [-10, -7, -4, -3, 1, 2, 5, 8];
const _otherOffsets = [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249];

class _State {
  final Int16List ring = Int16List(2048);
  int ringIndex = 0;
  final Float64List reordered = Float64List(2048);
  final List<Float32List> fftOutputs = List.generate(256, (_) => Float32List(1025));
  int fftOutputsIndex = 0;
  final List<Float32List> spreadOutputs = List.generate(256, (_) => Float32List(1025));
  int spreadOutputsIndex = 0;
  int numSpreadFftsDone = 0;
  final FFT fft = FFT(2048);
  final Map<FrequencyBand, List<FrequencyPeak>> peaks = {};

  void doFft(Int16List samples, int start) {
    for (var i = 0; i < 128; i++) {
      ring[ringIndex + i] = samples[start + i];
    }
    ringIndex = (ringIndex + 128) & 2047;

    for (var i = 0; i < 2048; i++) {
      reordered[i] = ring[(i + ringIndex) & 2047] * _hanning[i];
    }

    final spectrum = fft.realFft(reordered);
    final out = fftOutputs[fftOutputsIndex];
    for (var i = 0; i <= 1024; i++) {
      final c = spectrum[i];
      final v = (c.x * c.x + c.y * c.y) / (1 << 17);
      out[i] = v > 1e-10 ? v : 1e-10;
    }
    fftOutputsIndex = (fftOutputsIndex + 1) & 255;
  }

  void doPeakSpreading() {
    final latest = fftOutputs[(fftOutputsIndex - 1) & 255];
    final spread = spreadOutputs[spreadOutputsIndex];
    spread.setAll(0, latest);
    for (var p = 0; p <= 1022; p++) {
      spread[p] = math.max(spread[p], math.max(spread[p + 1], spread[p + 2]));
    }
    final copy = Float32List.fromList(spread);
    for (final former in const [1, 3, 6]) {
      final target = spreadOutputs[(spreadOutputsIndex - former) & 255];
      for (var p = 0; p <= 1024; p++) {
        if (copy[p] > target[p]) target[p] = copy[p];
      }
    }
    spreadOutputsIndex = (spreadOutputsIndex + 1) & 255;
  }

  static double _magnitude(double v) => math.max(math.log(v), 1 / 64) * 1477.3 + 6144.0;

  void doPeakRecognition() {
    final fft46 = fftOutputs[(fftOutputsIndex - 46) & 255];
    final fft49 = spreadOutputs[(spreadOutputsIndex - 49) & 255];

    for (var bin = 10; bin <= 1014; bin++) {
      final v = fft46[bin];
      if (v < 1 / 64 || v < fft49[bin - 1]) continue;

      var maxNeighbor = 0.0;
      for (final o in _neighborOffsets) {
        maxNeighbor = math.max(maxNeighbor, fft49[bin + o]);
      }
      if (v <= maxNeighbor) continue;

      var maxOther = maxNeighbor;
      for (final o in _otherOffsets) {
        maxOther = math.max(maxOther, spreadOutputs[(spreadOutputsIndex + o) & 255][bin - 1]);
      }
      if (v <= maxOther) continue;

      final passNumber = numSpreadFftsDone - 46;
      final magnitude = _magnitude(v);
      final before = _magnitude(fft46[bin - 1]);
      final after = _magnitude(fft46[bin + 1]);
      final variation1 = magnitude * 2 - before - after;
      final variation2 = (after - before) * 32 / variation1;
      final correctedBin = (bin * 64 + _toI32(variation2)) & 0xFFFF;
      final frequencyHz = correctedBin * (16000 / 2 / 1024 / 64);

      final band = switch (frequencyHz.toInt()) {
        >= 250 && <= 519 => FrequencyBand.b250_520,
        >= 520 && <= 1449 => FrequencyBand.b520_1450,
        >= 1450 && <= 3499 => FrequencyBand.b1450_3500,
        >= 3500 && <= 5500 => FrequencyBand.b3500_5500,
        _ => null,
      };
      if (band == null) continue;

      (peaks[band] ??= []).add(FrequencyPeak(
        fftPassNumber: passNumber,
        peakMagnitude: magnitude.clamp(0, 65535).toInt(),
        correctedPeakFrequencyBin: correctedBin,
      ));
    }
  }

  // Rust's `f32 as i32`: truncates toward zero, saturates, NaN becomes 0.
  static int _toI32(double v) {
    if (v.isNaN) return 0;
    if (v >= 2147483647) return 2147483647;
    if (v <= -2147483648) return -2147483648;
    return v.truncate();
  }
}
