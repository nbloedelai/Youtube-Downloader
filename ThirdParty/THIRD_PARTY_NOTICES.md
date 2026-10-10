# Third-party tools used by YouTube Downloader 2.6.4 Beta

The downloadable application and DMG do not contain yt-dlp, FFmpeg, or FFprobe executables.

During optional one-time setup, the app downloads these separate command-line tools directly from the configured project sources, verifies their SHA-256 fingerprints, and stores them in the current user's Application Support folder. The Swift app launches the tools as child processes and does not link their libraries into the app binary.

## yt-dlp

- Project: https://github.com/yt-dlp/yt-dlp
- Download selected at setup: the current `yt-dlp_macos` release asset
- Verification: the SHA-256 digest published in the GitHub release metadata
- License information: https://github.com/yt-dlp/yt-dlp/blob/master/THIRD_PARTY_LICENSES.txt

The yt-dlp project states that its PyInstaller executables contain GPLv3-or-later code and that the combined executable is GPLv3-or-later.

## FFmpeg and FFprobe 9.0.2

- Project: https://ffmpeg.org/
- Binary provider: https://ffmpeg.martin-riedl.de/
- Build scripts: https://git.martin-riedl.de/ffmpeg/build-script
- Architecture: arm64
- FFmpeg archive SHA-256: `c8ed4c4e6978a03c485edbfe4e0a5dc2380f8a30bba5150531b31b094492d924`
- FFprobe archive SHA-256: `fcbe839537485eaee7a7a8bc5cbc0f90d53617e80943e8a5b2e31cb851197ea6`

The configured FFmpeg binaries report a GPLv3 build that includes GPL-covered components such as libx264 and libx265. The app provides links to the projects and license information but does not redistribute these executables in its DMG.
