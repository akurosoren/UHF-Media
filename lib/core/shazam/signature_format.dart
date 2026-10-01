// Binary Shazam signature format, ported from shazamio-core
// (src/fingerprinting/signature_format.rs, MIT License).

import 'dart:convert';
import 'dart:typed_data';

import 'crc32.dart';

enum FrequencyBand { b250_520, b520_1450, b1450_3500, b3500_5500 }

class FrequencyPeak {
  const FrequencyPeak({
    required this.fftPassNumber,
    required this.peakMagnitude,
    required this.correctedPeakFrequencyBin,
  });

  final int fftPassNumber;
  final int peakMagnitude;
  final int correctedPeakFrequencyBin;
}

const _dataUriPrefix = 'data:audio/vnd.shazam.sig;base64,';
const _magic1 = 0xcafe2580;
const _magic2 = 0x94119c00;
const _sampleRateIds = {8000: 1, 11025: 2, 16000: 3, 32000: 4, 44100: 5, 48000: 6};

class DecodedSignature {
  DecodedSignature({required this.sampleRateHz, required this.numberSamples, required this.peaks});

  final int sampleRateHz;
  final int numberSamples;
  final Map<FrequencyBand, List<FrequencyPeak>> peaks;

  int get sampleMs => numberSamples * 1000 ~/ sampleRateHz;

  // sample_rate * 0.24, computed in integers to avoid float rounding.
  static int _extraSamples(int sampleRateHz) => sampleRateHz * 24 ~/ 100;

  Uint8List encode() {
    final rateId = _sampleRateIds[sampleRateHz];
    if (rateId == null) throw ArgumentError.value(sampleRateHz, 'sampleRateHz', 'unsupported');

    final out = BytesBuilder();
    void u32(int v) => out.add((ByteData(4)..setUint32(0, v & 0xFFFFFFFF, Endian.little)).buffer.asUint8List());

    u32(_magic1);
    u32(0); // crc32, patched below
    u32(0); // size minus header, patched below
    u32(_magic2);
    u32(0);
    u32(0);
    u32(0);
    u32(rateId << 27);
    u32(0);
    u32(0);
    u32(numberSamples + _extraSamples(sampleRateHz));
    u32((15 << 19) + 0x40000);
    u32(0x40000000);
    u32(0); // size minus header, patched below

    final bands = peaks.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    for (final band in bands) {
      final buf = BytesBuilder();
      var pass = 0;
      for (final peak in peaks[band]!) {
        if (peak.fftPassNumber < pass) {
          throw StateError('peaks must be sorted by fft pass number');
        }
        if (peak.fftPassNumber - pass >= 255) {
          buf.addByte(0xff);
          buf.add((ByteData(4)..setUint32(0, peak.fftPassNumber, Endian.little)).buffer.asUint8List());
          pass = peak.fftPassNumber;
        }
        buf.addByte(peak.fftPassNumber - pass);
        buf.add((ByteData(4)
              ..setUint16(0, peak.peakMagnitude, Endian.little)
              ..setUint16(2, peak.correctedPeakFrequencyBin, Endian.little))
            .buffer
            .asUint8List());
        pass = peak.fftPassNumber;
      }
      final bytes = buf.takeBytes();
      u32(0x60030040 + band.index);
      u32(bytes.length);
      out.add(bytes);
      final padding = (4 - bytes.length % 4) % 4;
      for (var i = 0; i < padding; i++) {
        out.addByte(0);
      }
    }

    final result = out.takeBytes();
    final view = ByteData.sublistView(result);
    view.setUint32(8, result.length - 48, Endian.little);
    view.setUint32(52, result.length - 48, Endian.little);
    view.setUint32(4, crc32(Uint8List.sublistView(result, 8)), Endian.little);
    return result;
  }

  String toDataUri() => '$_dataUriPrefix${base64.encode(encode())}';

  static DecodedSignature fromDataUri(String uri) {
    if (!uri.startsWith(_dataUriPrefix)) throw const FormatException('not a Shazam signature data URI');
    return decode(base64.decode(uri.substring(_dataUriPrefix.length)));
  }

  static DecodedSignature decode(Uint8List bytes) {
    if (bytes.length < 56) throw const FormatException('signature too short');
    final data = ByteData.sublistView(bytes);
    int u32(int offset) => data.getUint32(offset, Endian.little);

    if (u32(0) != _magic1 || u32(12) != _magic2) throw const FormatException('bad signature magic');
    if (u32(8) != bytes.length - 48) throw const FormatException('bad signature size');
    if (u32(4) != crc32(Uint8List.sublistView(bytes, 8))) throw const FormatException('bad signature CRC');

    final rateId = u32(28) >> 27;
    final sampleRate = _sampleRateIds.entries
        .firstWhere((e) => e.value == rateId, orElse: () => throw const FormatException('bad sample rate id'))
        .key;
    final numberSamples = u32(40) - _extraSamples(sampleRate);

    final peaks = <FrequencyBand, List<FrequencyPeak>>{};
    var offset = 56;
    while (offset + 8 <= bytes.length) {
      final bandId = u32(offset) - 0x60030040;
      final size = u32(offset + 4);
      offset += 8;
      if (bandId < 0 || bandId >= FrequencyBand.values.length || offset + size > bytes.length) {
        throw const FormatException('bad frequency band block');
      }
      final list = <FrequencyPeak>[];
      final end = offset + size;
      var pass = 0;
      var i = offset;
      while (i < end) {
        final offsetByte = bytes[i++];
        if (offsetByte == 0xff) {
          pass = data.getUint32(i, Endian.little);
          i += 4;
          continue;
        }
        pass += offsetByte;
        list.add(FrequencyPeak(
          fftPassNumber: pass,
          peakMagnitude: data.getUint16(i, Endian.little),
          correctedPeakFrequencyBin: data.getUint16(i + 2, Endian.little),
        ));
        i += 4;
      }
      peaks[FrequencyBand.values[bandId]] = list;
      offset = end + (4 - size % 4) % 4;
    }
    return DecodedSignature(sampleRateHz: sampleRate, numberSamples: numberSamples, peaks: peaks);
  }
}
