# HuluMedia

A single-file Windows video player/editor built on the mpv engine, with
rotate + crop + ffmpeg-based export. Comes with a PyQt5 UI, a dark theme,
and a custom (frameless) window.

## Features

- **Playback**: mpv-based, wide codec/container support
- Audio track selection, subtitle selection + live size/position adjustment
- Screenshot capture (saved to Desktop)
- Fullscreen (double-click on video, or shortcut)
- **Rotate**: 90° clockwise, 90° counter-clockwise, 180° (upside-down) - live preview
- **Crop**: draggable/resizable crop box over the video, live output resolution + aspect ratio display
- **Export**: applies crop + rotate in a single ffmpeg pass, matching the source bitrate; automatically uses a GPU encoder (NVENC/QSV/AMF) when available, silently falling back to CPU (libx264) if none is found or if the GPU path fails
- Automatically rewinds to the start when a video finishes
- Drag & drop to open a video or subtitle (.srt) file
- Can be launched directly by double-clicking a video file (Windows file association)
- Custom window chrome: draggable title bar, edge resizing, minimize/maximize/close, an **always-on-top** toggle
- Dark gray theme

## Keyboard & Mouse Shortcuts

| Action | Shortcut |
|---|---|
| Play / Pause | Spacebar |
| Seek 3s forward / back | Right / Left arrow |
| Volume | Mouse wheel over the video |
| Toggle fullscreen | Double-click on the video |
| Exit fullscreen | Esc |
| Maximize / restore window | Double-click the title bar |

## Requirements

- Python 3.9+
- `pip install PyQt5 mpv`
- **libmpv** (`libmpv-2.dll`) - available from:
  https://sourceforge.net/projects/mpv-player-windows/files/libmpv/
- **ffmpeg + ffprobe** (only needed for the "Export" feature; without them
  playback still works, only export is disabled)

## Running From Source

```
pip install PyQt5 mpv
python video_studio_player.py
```

Place `libmpv-2.dll`, `ffmpeg.exe`, and `ffprobe.exe` in the same folder as
`video_studio_player.py`.

## Building an .exe (PyInstaller)

> PyInstaller does not cross-compile - these steps must be run on a Windows
> machine.

```
pip install pyinstaller
python -m PyInstaller --onedir --windowed --name HuluMedia video_studio_player.py
```

This produces a `dist\HuluMedia\` folder. On PyInstaller 6+, dependencies are
placed in a `dist\HuluMedia\_internal\` subfolder. Copy these three files
**into that folder**:

- `libmpv-2.dll`
- `ffmpeg.exe`
- `ffprobe.exe`

(If unsure, copying them into both `_internal` and the folder next to
`HuluMedia.exe` is harmless.)

`dist\HuluMedia\HuluMedia.exe` is the executable.

### Important: move the whole folder, not just the .exe

The `--onedir` build depends on the `_internal` folder sitting next to the
`.exe`. If you copy **only the `.exe`** somewhere else (without
`_internal`), the app will crash on launch with:

```
OSError: Cannot find mpv-1.dll, mpv-2.dll or libmpv-2.dll in your system %PATH%
```

For a portable link, create a **shortcut** (.lnk) to the `.exe` instead of
moving the `.exe` itself, and move the shortcut wherever you like.

### Windows file association (open by double-clicking a video)

Right-click a video file → **Open with** → **Choose another app** → **Look
for another app on this PC** → select `dist\HuluMedia\HuluMedia.exe`
**directly from its original location** (not a copied/moved instance).

## Known Limitations

- Some icons in the top bar (📂 💾 🔊 💬) come from Windows' color emoji font
  and don't pick up the dark theme's text color - they render in their own
  native colors. Plain symbol-based icons (↻ ↺ ⤾ ⛶ ⚙) do turn white.
- Hardware-accelerated video decoding is disabled (`hwdec=no`). This is a
  deliberate choice to work around an issue where hardware decoding fails to
  display video when mpv is embedded in a Qt widget on Windows; the
  trade-off is somewhat higher CPU usage.
- Window dragging/resizing uses `QWindow.startSystemMove()` /
  `startSystemResize()` (requires Qt 5.15+).
