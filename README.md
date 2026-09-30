# SwiftLAME — Tonify's copy

This is the exact source of the SwiftLAME / LAME code shipped in **Tonify** (iOS),
published to meet the GNU LGPL v2.1 (see `LICENSE` and `Sources/LAME/COPYING`).

- **LAME** — libmp3lame 3.100, in `Sources/LAME`.
- **SwiftLAME** — Swift wrapper, a fork of [hidden-spectrum/SwiftLAME](https://github.com/hidden-spectrum/SwiftLAME)
  via tcwalther. Upstream README: [`README.upstream.md`](README.upstream.md).
- **Our changes:** every write is checked and a failed or short write throws
  (`SwiftLameError.couldNotWriteOutput`) instead of producing a truncated MP3; empty reads end the stream cleanly.
- The product is built as a **dynamic framework** (`type: .dynamic` in `Package.swift`), so it can be
  replaced with your own build, as LGPL §6 requires.

## FFmpeg

Tonify also links FFmpeg (LGPL, unmodified source) as a dynamic framework to decode files iOS cannot open.
The exact build options are in [`ffmpeg/build.sh`](ffmpeg/build.sh) and packaging in
[`ffmpeg/package.sh`](ffmpeg/package.sh); source: https://ffmpeg.org/download.html

## Relinking

Build this package (or your modified copy) as a dynamic framework and replace `SwiftLAME.framework`
inside the app bundle; for FFmpeg, run `ffmpeg/build.sh` with your source and replace the FFmpeg frameworks.

Contact: yaysoftltd+mp3_converter@gmail.com
