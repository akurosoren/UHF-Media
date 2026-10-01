# UHF Media

Windows video player with built-in editing tools (rotate, crop, trim, export) and one-click song recognition. Flutter rewrite of the original PyQt5 app, which lives in [`legacy/`](legacy/).

## Download

Grab the latest `UHF-Media-<version>-win64.zip` from the [Releases](../../releases) page, unzip it anywhere and run `uhf_media.exe`. Keep the files of the folder together: `ffmpeg.exe` and `ffprobe.exe` are used for export and song recognition.

## Features

- Playback of video and audio (libmpv): subtitles, audio tracks, screenshots, resume where you left off, always on top.
- Studio (`E`): rotate (`R`), crop (`C`), trim (`I` / `O`) and export with `Ctrl+E`, using the GPU encoder when available (NVENC, Quick Sync, AMF).
- One-click song recognition (`Ctrl+I`), with optional automatic file renaming.
- Languages: English, French, Turkish.

## Development

Requirements: Flutter 3.41 (stable), Visual Studio with the "Desktop development with C++" workload.

```bash
flutter pub get
flutter test
flutter run -d windows
```

`ffmpeg.exe` and `ffprobe.exe` must sit next to the executable. `tool/build_ffmpeg.sh` builds the small static pair shipped in releases (MSYS2 MINGW64 shell); `tool/subset_icons.py` regenerates the icon font.

## License and third-party software

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
