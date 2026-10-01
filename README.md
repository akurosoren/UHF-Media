# UHF Media

Windows video player with built-in editing tools (rotate, crop, trim, export) and song recognition. Flutter rewrite of the original PyQt5 app, which lives in [`legacy/`](legacy/).

Status: in development. Design: [`docs/superpowers/specs/2026-10-01-uhf-media-flutter-design.md`](docs/superpowers/specs/2026-10-01-uhf-media-flutter-design.md).

## Development

Requirements: Flutter 3.41 (stable), Visual Studio with the "Desktop development with C++" workload.

```bash
flutter pub get
flutter test
flutter run -d windows
```
