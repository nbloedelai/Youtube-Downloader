# Privacy

YouTube Downloader runs locally on the user's Mac. Version 2.6.1 Beta does not include analytics, advertising, accounts, or developer-operated telemetry.

When the user starts a download, the app launches bundled command-line tools that connect to the media host selected by the user. When the user checks for a yt-dlp update, the app connects to GitHub's public API and downloads the selected official release asset. Those services receive normal network information such as the user's IP address and request metadata under their own privacy policies.

The app stores an updated yt-dlp executable and its version under:

```text
~/Library/Application Support/YouTube Downloader/Tools
```

Downloaded and converted media is written only to the folder selected by the user. The app does not upload those files to the developer.

This document must be updated before adding analytics, crash reporting, accounts, remote logging, or any other collection of user data.
