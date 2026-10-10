# Public release checklist

This checklist is for publishing YouTube Downloader 2.6.1 Beta on GitHub. It is a practical engineering checklist, not legal advice and not a guarantee against complaints or removal.

## Immediate action for the current public release

- [ ] Temporarily remove the DMG and ZIP binary assets from the GitHub release, or convert the release to a draft, until the corresponding-source package described below is available.
- [ ] Keep the source repository public while the binary release is being corrected.
- [ ] Replace `README NEW` and the short `README.md` with the complete `README.md` from this project.
- [ ] Publish the app source, build scripts, artwork source, and the license/notice files listed under **Repository files**.
- [ ] Correct `yt-delp` to `yt-dlp` in the repository description and `offical` to `official` in the release notes.

## Choose the license for the app code

The app's Swift code and artwork need an explicit licensing decision from the copyright owner. Do not copy a license into `LICENSE` until that decision is made.

- [ ] Choose an open-source license if other people may copy, modify, and redistribute the app. MIT is simple and permissive; GPL-3.0 is copyleft.
- [ ] If the project is only source-visible, state `Copyright (c) 2026 Noah Bloedel. All rights reserved.` and do not describe it as open source.
- [ ] Put the chosen terms in a root file named `LICENSE`.
- [ ] State clearly that bundled third-party tools retain their own licenses.

## Repository files

The public repository should contain, at minimum:

```text
README.md
LICENSE                         # chosen license for original app code/artwork
PUBLIC_RELEASE_CHECKLIST.md
SECURITY.md
PRIVACY.md
.gitignore
Sources/
  YouTubeDownloader.swift
Scripts/
  package-release.sh
  MakeIcon-OrangeCoral.swift
  MakeDMGBackground.swift
  make-dmg-layout.py
Assets/
  AppIcon-OrangeCoral.icns
  icon-1024-orange-coral.png
  installer-background-final.png
  DS_Store.template
ThirdParty/
  THIRD_PARTY_NOTICES.md
  Licenses/
    GPL-3.0.txt
    FFmpeg-COPYING.GPLv3.txt
    yt-dlp-THIRD_PARTY_LICENSES.txt
```

Do not publish old app bundles, test downloads, `.DS_Store` files, temporary caches, signing certificates, Apple credentials, GitHub tokens, or notarization profiles.

## Binary-release files

Every GitHub release that provides a DMG or ZIP should also provide:

```text
YouTube-Downloader-2.6.1-Beta.dmg
SHA256SUMS.txt
THIRD_PARTY_NOTICES.md
YouTube-Downloader-2.6.1-Beta-source.zip
yt-dlp-2026.08.19-corresponding-source.zip
ffmpeg-9.0.2-corresponding-source.zip
```

The two corresponding-source archives must match the exact binaries in the DMG. A project homepage or a link to a moving branch is not enough for a reproducible record.

### yt-dlp corresponding-source archive

Include:

- the exact yt-dlp 2026.08.19 source release;
- source for every component included in the `yt-dlp_macos` PyInstaller executable;
- its `THIRD_PARTY_LICENSES.txt` and GPL-3.0-or-later license text;
- the exact build scripts, dependency versions, patches, and instructions needed to recreate that executable;
- a manifest mapping the distributed binary's SHA-256 to the source archive.

The upstream yt-dlp release says its PyInstaller executables contain GPLv3-or-later code and the combined executable is GPLv3-or-later. Obtain the exact source/build bundle from upstream if it is not already published as one complete archive.

### FFmpeg corresponding-source archive

Include:

- FFmpeg 9.0.2 source;
- the exact Martin Riedl build-script commit used for build `1789931890_9.0.2`;
- source for the exact linked versions of libx264, libx265, libmp3lame, and every other non-system library compiled into the binary;
- all patches, configuration options, build scripts, and installation instructions;
- GPL license texts and the FFmpeg notices;
- a manifest mapping the distributed `ffmpeg` and `ffprobe` SHA-256 values to the source archive.

Do not publish the current FFmpeg binary release until the exact build commit and complete dependency source can be identified and archived.

## Product naming and description

- [ ] Consider renaming the app to a neutral name such as `Media Downloader & Converter` to reduce possible confusion with YouTube or Google branding.
- [ ] Do not use YouTube's logo or imply endorsement, affiliation, or certification.
- [ ] Add this sentence near the top of the README and release notes: `This independent project is not affiliated with, endorsed by, or sponsored by YouTube or Google.`
- [ ] Describe the intended use as downloading media the user created, owns, or has permission to download.
- [ ] Do not claim that the app makes every download lawful. A disclaimer does not override copyright law or a website's terms.

## Privacy and security

- [ ] Keep `PRIVACY.md` accurate. Update it before adding analytics, crash reporting, accounts, or telemetry.
- [ ] Keep `SECURITY.md` current and provide a private reporting route before the project attracts users.
- [ ] Pin every downloaded build dependency by version and cryptographic digest.
- [ ] Generate `SHA256SUMS.txt` for every release asset.
- [ ] Build from a clean checkout and confirm the build script does not depend on an older `.app` bundle.
- [ ] Inspect the final app bundle and DMG for tokens, usernames, test media, absolute local paths, and private keys.

## macOS distribution

- [ ] Enroll in the Apple Developer Program.
- [ ] Sign the app and every bundled executable with a Developer ID Application certificate and hardened runtime.
- [ ] Sign the final distribution as required by Apple's current process.
- [ ] Submit the release to Apple's notary service and staple the notarization ticket to the app/DMG.
- [ ] Verify the signature, notarization, Gatekeeper assessment, and a fresh-machine install before publishing.

Signing and notarization improve install trust. They do not resolve copyright, trademark, website-terms, or open-source-license issues.

## Release procedure

1. Build from a clean clone using only the checked-in scripts.
2. Record the app version, source commit, dependency versions, download URLs, and SHA-256 values.
3. Create and inspect the two complete corresponding-source archives.
4. Build, sign, notarize, and staple the app and DMG.
5. Generate `SHA256SUMS.txt` for the DMG and all source archives.
6. Test on a clean supported macOS installation.
7. Upload the DMG, checksum file, notices, app source archive, and both corresponding-source archives to the same GitHub release.
8. Put direct source links beside the binary download in the release notes.
9. Retain an offline copy of every published binary, source archive, checksum, build log, and signing/notarization result.
10. Repeat the process for every binary release; do not point a new binary at an old source bundle.

## Current 2.6.1 blockers

- The public repository does not currently expose the complete app source/build tree.
- The current packaging script begins by copying the 2.4.7 app bundle, so it is not a clean reproducible build.
- The exact corresponding source and build materials for the bundled yt-dlp PyInstaller executable have not been archived with the release.
- The exact Martin Riedl FFmpeg build commit and the source of all compiled-in dependencies have not been archived with the release.
- The app is ad hoc signed and is not notarized.
- The owner has not yet selected explicit license terms for the original Swift code and artwork.

Until these are resolved, the safest public state is a source-only repository without downloadable app binaries.
