import 'dart:io';

import 'app_settings.dart';
import 'json_file.dart';

class SettingsStore {
  SettingsStore(Directory dir) : _file = File('${dir.path}${Platform.pathSeparator}settings.json');

  final File _file;

  Future<AppSettings> load() async {
    final json = await readJsonObject(_file);
    return json == null ? AppSettings.defaults() : AppSettings.fromJson(json);
  }

  Future<void> save(AppSettings settings) => writeJsonAtomic(_file, settings.toJson());
}
