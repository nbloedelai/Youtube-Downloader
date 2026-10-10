<div align="center">
  <img src="Assets/icon-1024-orange-coral.png" width="150" alt="YouTube Downloader app icon">

  # YouTube Downloader for macOS

  A native SwiftUI app for downloading videos you own or have permission to save, creating QuickTime-compatible files, and converting local videos without a trip to Terminal.

  **Current release: 2.6.1 Beta · Apple silicon · macOS 26 or later**
</div>

> This independent project is not affiliated with, endorsed by, or sponsored by YouTube or Google. Use it only for media you created, own, or have permission to download.

> [!IMPORTANT]
> This is an experimental personal project. The current public build is ad hoc signed and has not been notarized by Apple. Test it carefully and expect Gatekeeper to require **Open Anyway** when the DMG is downloaded from the internet.

## What it does

- Downloads a video as a QuickTime-compatible MP4.
- Extracts audio as an MP3 at 128, 192, or 320 kbps.
- Offers Fast, Balanced, and High Quality video conversion modes.
- Converts existing videos to H.264 MP4, HEVC MP4, or ProRes MOV.
- Shows download and conversion progress in the app.
- Bundles yt-dlp, FFmpeg, and FFprobe, so users do not need Homebrew or Terminal setup.
- Checks the official yt-dlp GitHub release for updates from the Settings tab.
- Verifies the SHA-256 digest published in GitHub release metadata before installing an yt-dlp update.
- Follows the system light or dark appearance.

## Installer preview

<div align="center">
  <img src="Assets/installer-background-final.png" width="660" alt="Orange and coral DMG installer artwork">
</div>

The planned DMG uses a compact Finder window with a branded orange and coral background.

## Download status

The public repository is currently **source-only**. The downloadable DMG has been temporarily removed while its third-party source packages, Developer ID signing, and Apple notarization are prepared.

When a public build is ready, it will appear on the repository's **Releases** page with checksums and matching source archives. You do not need to download anything yet.

## Download modes

### Video

| Mode | Encoder | Best for |
|---|---|---|
| Fast | Apple VideoToolbox when available | Quick conversions with lower CPU use |
| Balanced | Software H.264 | A balance of quality and file size |
| High Quality | Software H.264 | More detail when conversion time is less important |

Downloaded videos are converted to H.264 video with AAC audio in an MP4 container for broad QuickTime compatibility.

### Audio

| Quality | Suggested use |
|---|---|
| 128 kbps | Speech and smaller files |
| 192 kbps | General listening and podcasts |
| 320 kbps | Highest available MP3 setting |

The source audio limits the actual quality. Converting a low-quality source to 320 kbps cannot restore missing detail.

## QuickTime Converter

The converter tab accepts a local video and creates one of these formats:

- **H.264 MP4:** widest QuickTime compatibility.
- **HEVC MP4:** potentially smaller output for newer Macs.
- **ProRes MOV:** large editing-friendly files.

## yt-dlp updates

The Settings tab can check for new yt-dlp releases automatically or on demand.

Updates:

- Come only from the official [`yt-dlp/yt-dlp`](https://github.com/yt-dlp/yt-dlp) GitHub repository.
- Use the `yt-dlp_macos` release asset.
- Must match GitHub's published SHA-256 digest.
- Are stored under `~/Library/Application Support/YouTube Downloader/Tools`.
- Do not modify the signed application bundle.
- Can be removed with **Restore Built-in** when an updated copy is installed.

FFmpeg and FFprobe stay pinned to the tested versions shipped with the app.

## Building from source

The current build script targets Apple silicon and macOS 26:

```zsh
zsh Scripts/package-release.sh
```

The script:

1. Downloads the pinned third-party executables.
2. Verifies their SHA-256 checksums.
3. Compiles the SwiftUI application.
4. Bundles the tools and license notices.
5. Applies an ad hoc code signature.
6. Creates an app and ZIP in `dist/`.
7. Creates a SHA-256 checksum file for the ZIP.

The script automatically uses the macOS SDK installed with Xcode or the Xcode Command Line Tools. It does not require one hard-coded SDK folder.

The primary source file is [`Sources/YouTubeDownloader.swift`](Sources/YouTubeDownloader.swift).

## Bundled components

| Component | Version | Purpose |
|---|---:|---|
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | 2026.08.19 | Media retrieval |
| [FFmpeg](https://ffmpeg.org/) | 9.0.2 | Video and audio conversion |
| FFprobe | 9.0.2 | Media inspection |

See [`ThirdParty/THIRD_PARTY_NOTICES.md`](ThirdParty/THIRD_PARTY_NOTICES.md) and [`ThirdParty/Licenses`](ThirdParty/Licenses) for bundled license information.

Before publishing a binary release, complete every applicable item in [`PUBLIC_RELEASE_CHECKLIST.md`](PUBLIC_RELEASE_CHECKLIST.md). The bundled executables require exact corresponding source and build materials to remain available with the binaries.

> [!CAUTION]
> The bundled yt-dlp executable and current FFmpeg build include GPL-covered software. Before publishing binary releases, confirm that the repository and release process satisfy all corresponding-source, notice, and redistribution requirements. This README does not grant rights beyond the licenses of the project and its dependencies.

## Known limitations

- The current 2.6.1 build supports Apple silicon and requires macOS 26 or later.
- The app and DMG are not Developer ID signed or notarized.
- Intel and older macOS work remains experimental and is maintained separately.
- Website changes can temporarily break downloads until yt-dlp provides an update.
- Download and conversion speed depends on the source, network, selected quality, and Mac hardware.

## Responsible use

Use this app only for videos and audio you created, own, or have permission to download. You are responsible for following copyright law, the source website's terms, and any licenses attached to the media.

## Project status

This started as a small proof of concept and is still a learning project. Bug reports and careful testing are welcome, especially on clean macOS installations.
