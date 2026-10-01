import 'dart:io';

import 'package:path/path.dart' as p;

import 'json_file.dart';

class _Entry {
  _Entry(this.positionMs, this.updatedMs);
  int positionMs;
  int updatedMs;
}

class ResumeStore {
  ResumeStore(Directory dir, {DateTime Function()? now, this.maxEntries = 500})
    : _file = File('${dir.path}${Platform.pathSeparator}resume.json'),
      _now = now ?? DateTime.now;

  static const _minFromStart = Duration(seconds: 10);
  static const _minFromEnd = Duration(seconds: 30);

  final File _file;
  final DateTime Function() _now;
  final int maxEntries;
  final Map<String, _Entry> _entries = {};
  bool _dirty = false;

  int get length => _entries.length;

  static String _key(String path) => p.windows.normalize(path).toLowerCase();

  Future<void> load() async {
    _entries.clear();
    final json = await readJsonObject(_file);
    final entries = json?['entries'];
    if (entries is! Map<String, dynamic>) return;
    entries.forEach((key, value) {
      if (value is Map<String, dynamic> && value['pos_ms'] is int && value['updated'] is int) {
        _entries[key] = _Entry(value['pos_ms'] as int, value['updated'] as int);
      }
    });
    _trim();
  }

  Duration? resumePositionFor(String path, Duration duration) {
    final entry = _entries[_key(path)];
    if (entry == null) return null;
    final position = Duration(milliseconds: entry.positionMs);
    if (position <= _minFromStart || position >= duration - _minFromEnd) return null;
    return position;
  }

  void record(String path, Duration position) {
    _entries[_key(path)] = _Entry(position.inMilliseconds, _now().millisecondsSinceEpoch);
    _dirty = true;
    _trim();
  }

  void clear(String path) {
    if (_entries.remove(_key(path)) != null) _dirty = true;
  }

  void migrate(String oldPath, String newPath) {
    final entry = _entries.remove(_key(oldPath));
    if (entry != null) {
      _entries[_key(newPath)] = entry;
      _dirty = true;
    }
  }

  /// Writes resume.json, only when an entry changed since the last flush.
  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    await writeJsonAtomic(_file, {
      'version': 1,
      'entries': {
        for (final e in _entries.entries) e.key: {'pos_ms': e.value.positionMs, 'updated': e.value.updatedMs},
      },
    });
  }

  void _trim() {
    if (_entries.length <= maxEntries) return;
    final sorted = _entries.entries.toList()..sort((a, b) => a.value.updatedMs.compareTo(b.value.updatedMs));
    for (final e in sorted.take(_entries.length - maxEntries)) {
      _entries.remove(e.key);
    }
  }
}
