import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

import 'app/uhf_root.dart';
import 'core/files/media_files.dart';
import 'core/media/media_kit_engine.dart';
import 'core/settings/resume_store.dart';
import 'core/settings/settings_store.dart';
import 'core/system/ffmpeg_locator.dart';
import 'core/system/known_folders.dart';
import 'core/system/launch_args.dart';
import 'core/system/probe_service.dart';
import 'features/player/player_controller.dart';
import 'features/player/player_settings_binding.dart';
import 'features/settings/settings_controller.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/second_instance.dart';
import 'features/shell/shell_controller.dart';
import 'features/shell/window_manager_host.dart';
import 'ui/toast.dart';
import 'ui/tokens.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // A second launch (double-click on another video) hands its arguments to
  // this instance and exits.
  await WindowsSingleInstance.ensureSingleInstance(
    args,
    'uhf_media_single_instance',
    onSecondWindow: SecondInstance.deliver,
  );
  MediaKit.ensureInitialized();
  await windowManager.ensureInitialized();

  final dataDir = Directory(p.join(Platform.environment['APPDATA'] ?? Directory.systemTemp.path, 'UHF Media'));
  final settingsStore = SettingsStore(dataDir);
  final initial = await settingsStore.load();
  final resume = ResumeStore(dataDir);
  await resume.load();

  final settings = SettingsController(settingsStore, initial);
  await WindowManagerHost.configure(initial);
  final host = WindowManagerHost();

  final engine = MediaKitEngine();
  final locator = FfmpegLocator.forCurrentProcess();
  final folders = KnownFolders();
  final player = PlayerController(
    engine: engine,
    resume: resume,
    probe: ProbeService(locator.locate('ffprobe')),
    desktopDirectory: folders.desktop,
    initialVolume: initial.volume,
    initialMuted: initial.muted,
    initialSubtitleScale: initial.subtitleScale,
    initialSubtitlePos: initial.subtitlePos,
  );
  final shell = ShellController(host, settings);
  final toasts = ToastController();
  bindPlayerSettings(player, settings);

  host.onCloseRequested = () async {
    await player.saveResume();
    await settings.flush();
  };

  runApp(UhfRoot(
    settings: settings,
    home: AppShell(
      player: player,
      shell: shell,
      settings: settings,
      toasts: toasts,
      videoBuilder: (_) => Video(
        controller: engine.controller,
        controls: null,
        fill: UhfColors.ink,
        subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
      ),
      pickFile: (initialDirectory) async {
        final files = await FilePicker.pickFiles(
          initialDirectory: initialDirectory,
          type: FileType.custom,
          allowedExtensions: mediaExtensions,
        );
        return files.firstOrNull?.path;
      },
      revealFile: (path) => unawaited(revealInExplorer(path)),
    ),
  ));

  SecondInstance.listener = secondInstanceHandler(shell: shell, player: player);
  final initialFile = firstExistingFile(args);
  if (initialFile != null) unawaited(player.open(initialFile));
}
