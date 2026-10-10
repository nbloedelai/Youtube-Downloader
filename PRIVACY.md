# Privacy

YouTube Downloader runs locally on the user's Mac. Version 2.6.4 Beta does not include analytics, advertising, accounts, or developer-operated telemetry.

During one-time setup, the app contacts GitHub to find and download the current official `yt-dlp_macos` release, and contacts the configured FFmpeg binary provider to download pinned FFmpeg and FFprobe archives. The app verifies SHA-256 fingerprints before installing the tools. These services receive normal network information such as the user's IP address and request metadata under their own privacy policies.

When the user starts a media download, the locally installed tools connect to the media host selected by the user. The app does not send the selected URL or resulting media to the app developer.

Installed tools are stored under:

```text
~/Library/Application Support/YouTube Downloader/Tools
```

Downloaded and converted media is written only to the folder selected by the user. This document must be updated before adding analytics, crash reporting, accounts, remote logging, or other collection of user data.
