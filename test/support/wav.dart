import 'dart:io';
import 'dart:typed_data';

/// Reads the samples of a 16-bit PCM WAV file.
Int16List readPcm16Wav(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      final samples = Int16List(size ~/ 2);
      for (var i = 0; i < samples.length; i++) {
        samples[i] = data.getInt16(offset + 8 + i * 2, Endian.little);
      }
      return samples;
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw FormatException('no data chunk in $path');
}
