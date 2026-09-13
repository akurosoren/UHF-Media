# HuluMedia

A single-file Windows video player/editor built on the mpv engine, with
rotate, crop, trim, and ffmpeg-based export. PyQt5 UI, dark theme, custom
frameless window, single-instance behavior, and GPU-accelerated export with
automatic CPU fallback.

## Features

**Playback**
- mpv-based engine, wide codec/container support
- Audio track selection, subtitle selection + live size/position adjustment
- Automatic deinterlacing for interlaced sources
- Screenshot capture (saved to Desktop)
- Fullscreen (double-click the video, or a shortcut)
- Automatically rewinds to the start when a video finishes
- Drag & drop to open a video or subtitle (`.srt`) file
- Launch directly by double-clicking a video file (Windows file association)
- Single-instance: opening a second video re-uses the already-running window instead of starting a new process

**Editing / Export**
- **Rotate**: 90° clockwise, 90° counter-clockwise, 180° (upside-down) - live preview
- **Crop**: draggable/resizable crop box over the video, live output resolution + aspect ratio display
- **Trim**: pick a start/end range on the timeline and export only that clip
  - Turning trim on opens a 1-minute window starting exactly at the current playback position
  - Drag the handles for coarse adjustment, or use the `-1s`/`+1s` buttons for single-second precision
  - The video seeks live to match while you drag or nudge the handles
- **Export** applies crop + rotate + trim in a single ffmpeg pass:
  - Matches the source bitrate
  - Preserves interlacing when no rotation is applied; uses bob-deinterlacing automatically when rotating an interlaced source
  - Automatically uses a GPU encoder (NVENC / QSV / AMF) when available, and silently falls back to CPU (libx264) if none is found, if the source is 10-bit+ (HDR sources - H.264 hardware encoders generally can't handle this), or if the GPU attempt fails at runtime
  - Frame-accurate trim seeking (fast keyframe seek + accurate decode, not a full-file scan)
  - Cancelling an in-progress export is a no-op, not an error

**Window**
- Custom (frameless) window with a dark title bar
- Draggable from the title bar, resizable from the edges
- Minimize / maximize / close / always-on-top buttons
- Dark gray theme throughout

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
- **ffmpeg + ffprobe** (only needed for editing/export; without them playback
  still works, only export is disabled)

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
**into that folder** (copying them next to `HuluMedia.exe` as well is
harmless if you're not sure which location applies to your PyInstaller
version):

- `libmpv-2.dll`
- `ffmpeg.exe`
- `ffprobe.exe`

`dist\HuluMedia\HuluMedia.exe` is the executable.

### Important: move the whole folder, not just the .exe

The `--onedir` build depends on the `_internal` folder sitting next to the
`.exe`. If you copy **only the `.exe`** somewhere else, the app crashes on
launch with:

```
OSError: Cannot find mpv-1.dll, mpv-2.dll or libmpv-2.dll in your system %PATH%
```

For a portable link, create a **shortcut** (`.lnk`) to the `.exe` instead of
moving the `.exe` itself.

### Windows file association (open by double-clicking a video)

Right-click a video file → **Open with** → **Choose another app** → **Look
for another app on this PC** → select `dist\HuluMedia\HuluMedia.exe`
**directly from its original location** (not a copied/moved instance).

## Distributing a Build (e.g. via GitHub)

- The `dist\HuluMedia\` folder (PyQt5 + libmpv + ffmpeg bundled) will likely
  exceed GitHub's 100 MB per-file limit for a regular repository. Upload the
  zipped folder as a **GitHub Release asset** instead (limit is much higher
  there), rather than committing it to the repo.
- Unsigned PyInstaller executables commonly trigger a Windows SmartScreen
  "unknown publisher" warning, and are occasionally flagged by antivirus
  heuristics (a well-known false-positive pattern for PyInstaller binaries,
  not specific to this project). Users typically need to click "More info →
  Run anyway".
- ffmpeg and libmpv are GPL/LGPL-licensed. Since they're invoked as separate
  processes/libraries rather than statically linked into this codebase, this
  project's own license isn't dictated by theirs - but when redistributing
  their binaries, include their license/copyright notices alongside the zip
  (available from ffmpeg.org and mpv.io).

## Known Limitations

- Some icons in the top bar (📂 💾 🔊 💬) come from Windows' color emoji font
  and don't pick up the dark theme's text color - they render in their own
  native colors. Plain symbol-based icons (↻ ↺ ⤾ ⛶ ⚙) do turn white.
- Hardware-accelerated video *decoding* is disabled (`hwdec=no`). This is a
  deliberate choice to work around an issue where hardware decoding fails to
  display video when mpv is embedded in a Qt widget on Windows; the
  trade-off is somewhat higher CPU usage during playback. (This is unrelated
  to the GPU-accelerated *encoding* used during export, which is enabled
  automatically when available.)
- Window dragging/resizing uses `QWindow.startSystemMove()` /
  `startSystemResize()` (requires Qt 5.15+).
- HDR sources (10-bit, e.g. HDR10 HEVC) are exported to standard 8-bit H.264
  without tone-mapping; colors may look flat/washed out compared to a proper
  HDR-to-SDR conversion. Proper tone-mapping (e.g. via ffmpeg's `zscale`/
  `tonemap` filters) is not implemented.
