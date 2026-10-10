# Public release checklist

This checklist applies to version 2.6.4 and later while the public DMG does not contain yt-dlp, FFmpeg, or FFprobe executables.

- Build from a clean checkout using `Scripts/package-release.sh`.
- Confirm `Contents/Resources` contains notices and artwork but no `Tools` directory or third-party executables.
- Confirm the first-launch setup downloads tools directly from the documented project sources.
- Confirm the current yt-dlp asset supplies a SHA-256 digest and all fixed FFmpeg/FFprobe hashes match.
- Type-check the Swift source and verify the app's code signature.
- Verify the DMG with `hdiutil verify`.
- Generate and publish `SHA256SUMS` for the DMG and source archive.
- Upload the matching source archive, notices, release notes, and DMG to the same GitHub prerelease.
- Clearly label unsigned builds and provide the System Settings → Privacy & Security → Open Anyway instructions.
- Keep the independent-project and responsible-use notices in the README and release notes.
- Test the one-time setup and one download on a clean supported macOS account before release.

Developer ID signing and Apple notarization are recommended before calling a release stable. This checklist is practical project guidance, not legal advice.
