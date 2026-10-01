import 'dart:async';

import 'package:uhf_media/core/system/music_recognizer.dart';

class FakeMusicIdentifier implements MusicIdentifier {
  bool isAvailable = true;
  final calls = <String>[];
  Completer<MusicOutcome>? pending;

  @override
  bool get available => isAvailable;

  @override
  String get expectedFolder => r'C:\App';

  @override
  Future<MusicOutcome> identify(String path, Duration at) {
    calls.add('$path@${at.inSeconds}');
    final completer = Completer<MusicOutcome>();
    pending = completer;
    return completer.future;
  }
}
