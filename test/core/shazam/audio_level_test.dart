import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhf_media/core/shazam/audio_level.dart';

void main() {
  test('digital silence and near-silence are silent', () {
    expect(isSilent(Int16List(16000)), isTrue);
    expect(isSilent(Int16List.fromList(List.filled(16000, 100))), isTrue);
  });

  test('a -10 dBFS tone is not silent', () {
    final tone = Int16List.fromList(
      List.generate(16000, (i) => (10362 * sin(2 * pi * 440 * i / 16000)).round()),
    );
    expect(isSilent(tone), isFalse);
  });

  test('empty input is silent', () {
    expect(isSilent(Int16List(0)), isTrue);
  });
}
