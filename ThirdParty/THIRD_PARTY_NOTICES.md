# Third-party tools bundled with YouTube Downloader 2.6.1 Beta

This personal beta contains separate command-line executables in `Contents/Resources/Tools`.
The Swift app launches them as child processes and does not link their libraries into the app binary.

## yt-dlp 2026.08.19

- File: `yt-dlp` (renamed from the official `yt-dlp_macos` asset)
- Project: https://github.com/yt-dlp/yt-dlp
- Release: https://github.com/yt-dlp/yt-dlp/releases/tag/2026.08.19
- Original SHA-256: `0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202`
- Architectures: arm64 and x86_64
- Upstream states that its PyInstaller executables contain GPLv3-or-later code and that the combined executable is GPLv3-or-later. See `yt-dlp-THIRD_PARTY_LICENSES.txt` and `GPL-3.0.txt` in this directory.

## FFmpeg and FFprobe 9.0.2

- Files: `ffmpeg`, `ffprobe`
- Project: https://ffmpeg.org/
- Source release: https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz
- Binary provider: https://ffmpeg.martin-riedl.de/
- Build scripts: https://git.martin-riedl.de/ffmpeg/build-script
- FFmpeg archive SHA-256: `c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924`
- FFprobe archive SHA-256: `fcbe839537485eaee7a7a8bc5cbc0f90d53617e80943e8a5b2e31cb851197ea6`
- Architecture in this beta: arm64
- Minimum OS encoded in these two binaries: macOS 12.0
- The binaries report a GPLv3 configuration, including libx264, libx265, and libmp3lame. See `FFmpeg-COPYING.GPLv3.txt`.

These third-party binaries are included for personal beta testing. Before public distribution, preserve the exact corresponding source and build materials required by their licenses and complete signing and notarization review.
