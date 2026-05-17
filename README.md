# CodexPulse

A small macOS menu bar app for keeping an eye on your Codex rate limits.

CodexPulse sits in the top bar and shows your current 5-hour and weekly Codex quota remaining, so you can glance at it without opening the Codex app settings menu.

CodexPulse works best when the official Codex app is installed, opened, and signed in on the same Mac. It reads the local Codex app helper for live quota data, then falls back to recent cached data if Codex is temporarily unavailable.

![CodexPulse icon](docs/codexpulse-icon.png)

## What It Shows

- 5-hour limit remaining
- Weekly limit remaining
- Reset time or reset date
- Current Codex plan type
- A stale/cached state when Codex is temporarily unavailable

You can choose how compact the top-bar display should be:

- Both: `5h 91% W 90%`
- 5h only: `5h 91%`
- Weekly only: `W 90%`

## Install

Before installing CodexPulse, install and open the official Codex app at least once. CodexPulse depends on the local Codex app helper for the most accurate live rate-limit data.

1. Download `CodexPulse-macos-arm64.dmg` from the latest GitHub release.
2. Open the DMG.
3. Drag `CodexPulse.app` into `Applications`.
4. Open it once.

The zip artifact, `CodexPulse-macos-arm64.zip`, is still available for manual installs or troubleshooting.

Because this early release is ad-hoc signed, macOS may block the first launch. If that happens, right-click `CodexPulse.app`, choose **Open**, then confirm. After that, it opens normally.

## Using CodexPulse

After launch, CodexPulse appears in your macOS menu bar as a small pulse-cloud icon with your selected quota text beside it.

If Codex is not installed, not signed in, or has not produced rate-limit data yet, CodexPulse will explain that in the menu instead of guessing.

Open the menu to:

- refresh the value immediately
- open Preferences
- turn Launch at Login on or off
- check when each limit resets
- check for updates
- quit the app

## Preferences

CodexPulse includes a small Preferences window for the things you may want to tune:

- choose whether the top bar shows both windows, 5h only, or weekly only
- show remaining percent, used percent, or both
- switch the app language between System, English, Simplified Chinese, and Traditional Chinese
- refresh every 30 seconds, 60 seconds, or 5 minutes
- opt in to low-limit and stale-data notifications
- review Diagnostics with source, cache, last refresh, and last error details

Notifications are off by default. If you enable them, macOS will ask for permission the first time.

## Language Support

CodexPulse includes English, Simplified Chinese, and Traditional Chinese. By default it follows your macOS language preference, and you can override the language from Preferences when you want to test or use another language.

The menu bar text stays intentionally compact, while menus, Preferences, About, notifications, and empty states are ready to translate through the bundled `.lproj` resources.

## Privacy

CodexPulse runs locally on your Mac.

It reads your Codex rate-limit information from the local Codex app helper and does not send your data anywhere. If Codex is not available for a moment, CodexPulse shows the last successful reading and marks it as cached/stale in the menu.

## License

CodexPulse is released under the MIT License. See `LICENSE` for details.

## Requirements

- macOS 13 or newer
- Apple Silicon Mac
- The official Codex app installed at `/Applications/Codex.app`
- Codex opened and signed in at least once on the same Mac

## For Developers

Build and package locally:

```sh
swift test
scripts/build-release.sh
scripts/package-dmg.sh
scripts/package-zip.sh
```

The app bundle, DMG, and zip are created in `dist/`.

Optional notarization support can be added later through `scripts/notarize.sh` once a Developer ID certificate is available.
