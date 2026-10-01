import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/files/safe_rename.dart';
import '../../core/system/music_recognizer.dart';
import '../player/player_controller.dart';
import '../settings/settings_controller.dart';

sealed class MusicEvent {
  const MusicEvent();
}

class MusicListeningEvent extends MusicEvent {
  const MusicListeningEvent();
}

class MusicNotFoundEvent extends MusicEvent {
  const MusicNotFoundEvent();
}

class MusicFailedEvent extends MusicEvent {
  const MusicFailedEvent();
}

class MusicRenamedEvent extends MusicEvent {
  const MusicRenamedEvent(this.name);
  final String name;
}

class MusicRenameFailedEvent extends MusicEvent {
  const MusicRenameFailedEvent();
}

class MusicUnavailableEvent extends MusicEvent {
  const MusicUnavailableEvent(this.folder);
  final String folder;
}

class MusicCard {
  const MusicCard({required this.path, required this.artist, required this.title, this.renamedFrom});

  /// The identified file, under its current name.
  final String path;
  final String artist;
  final String title;

  /// Previous name after a rename, for Undo.
  final String? renamedFrom;

  String get text => '$artist - $title';
}

class MusicIdController extends ChangeNotifier {
  MusicIdController({
    required PlayerController player,
    required MusicIdentifier identifier,
    required SettingsController settings,
    bool Function(String path)? exists,
  })  : _player = player,
        _identifier = identifier,
        _settings = settings,
        _exists = exists ?? ((path) => File(path).existsSync());

  final PlayerController _player;
  final MusicIdentifier _identifier;
  final SettingsController _settings;
  final bool Function(String path) _exists;
  final _events = StreamController<MusicEvent>.broadcast();
  bool _busy = false;
  MusicCard? _card;

  bool get busy => _busy;
  MusicCard? get card => _card;
  Stream<MusicEvent> get events => _events.stream;

  Future<void> identify() async {
    final path = _player.path;
    if (_busy || path == null) return;
    if (!_identifier.available) {
      _events.add(MusicUnavailableEvent(_identifier.expectedFolder));
      return;
    }
    _busy = true;
    _card = null;
    notifyListeners();
    _events.add(const MusicListeningEvent());
    final MusicOutcome outcome;
    try {
      outcome = await _identifier.identify(path, _player.position);
    } finally {
      _busy = false;
    }
    switch (outcome) {
      case MusicFound(:final result):
        _card = MusicCard(path: path, artist: result.artist, title: result.title);
        notifyListeners();
        if (_settings.value.autoRename) await renameToResult();
      case MusicNotFound():
        _events.add(const MusicNotFoundEvent());
        notifyListeners();
      case MusicFailed():
        _events.add(const MusicFailedEvent());
        notifyListeners();
    }
  }

  /// Renames the identified file to "Artist - Title.ext" while it plays.
  Future<void> renameToResult() async {
    final card = _card;
    if (card == null || card.renamedFrom != null || _player.path != card.path) return;
    final target = renameTarget(card.path, card.artist, card.title, exists: _exists);
    if (target == null) return;
    if (await _player.renameOpenFile(target)) {
      _card = MusicCard(path: target, artist: card.artist, title: card.title, renamedFrom: card.path);
      _events.add(MusicRenamedEvent(p.windows.basename(target)));
    } else {
      _events.add(const MusicRenameFailedEvent());
    }
    notifyListeners();
  }

  Future<void> undoRename() async {
    final card = _card;
    final from = card?.renamedFrom;
    if (card == null || from == null || _player.path != card.path) return;
    if (await _player.renameOpenFile(from)) {
      _card = MusicCard(path: from, artist: card.artist, title: card.title);
    } else {
      _events.add(const MusicRenameFailedEvent());
    }
    notifyListeners();
  }

  void dismiss() {
    _card = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_events.close());
    super.dispose();
  }
}
