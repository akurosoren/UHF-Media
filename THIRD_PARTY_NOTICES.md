# Third-party notices

UHF Media bundles or depends on the following software.

| Component | Use | License |
| --- | --- | --- |
| [FFmpeg](https://ffmpeg.org) 8.1.2 (`ffmpeg.exe`, `ffprobe.exe`) with [x264](https://www.videolan.org/developers/x264.html) | Probing, export, audio extraction | GPL v2 or later |
| [libmpv](https://mpv.io) | Playback | GPL v2 or later / LGPL v2.1 or later (build dependent) |
| [media_kit](https://github.com/media-kit/media-kit) | Flutter bindings to libmpv | MIT |
| Flutter and its packages (`window_manager`, `file_picker`, `desktop_drop`, `win32`, `http`, `fftea`, ...) | App framework | BSD-3-Clause / MIT |
| [IBM Plex Sans and Mono](https://github.com/IBM/plex) | Fonts | SIL OFL 1.1 |
| [Material Symbols](https://github.com/google/material-design-icons) (21 glyphs, subset) | Icons | Apache 2.0 |

## FFmpeg source

The bundled FFmpeg is built from the unmodified source `ffmpeg-8.1.2.tar.xz` published at <https://ffmpeg.org/releases/>, with the exact configuration in [`tool/build_ffmpeg.sh`](tool/build_ffmpeg.sh). That script and the upstream source are the corresponding source for the binaries, as the GPL requires.
