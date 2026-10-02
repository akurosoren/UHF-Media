# UHF Media

Windows video player with built-in editing tools (rotate, crop, trim, export) and one-click song recognition. Flutter rewrite of the original PyQt5 app, which lives in [`legacy/`](legacy/).

## Download

Grab the latest `UHF-Media-<version>-portable.exe` from the [Releases](../../releases) page and run it: a single file, no installer. On first launch it unpacks itself to `%LOCALAPPDATA%\UHF-Media` (a couple of seconds), then starts instantly. Delete that folder to remove it. A `UHF-Media-<version>-win64.zip` with the plain folder is also provided.

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

`ffmpeg.exe` and `ffprobe.exe` must sit next to the executable. `tool/build_ffmpeg.sh` builds the small static pair shipped in releases (MSYS2 MINGW64 shell); `tool/subset_icons.py` regenerates the icon font, `tool/portable/build_portable.py` packs the single-file exe.

## License and third-party software

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
