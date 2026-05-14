# CodexPulse

CodexPulse is a tiny native macOS menu bar app for viewing Codex rate-limit windows.

It reads the current Codex account limits from the local Codex app-server API and shows remaining quota for the 5-hour and weekly windows. It does not send data anywhere.

## Features

- Native macOS menu bar app.
- Display modes: both windows, 5h only, or weekly only.
- Manual refresh and 60-second automatic refresh.
- Last-known-good cache if Codex is temporarily unavailable.
- Optional launch-at-login toggle.

## Build

```sh
swift test
scripts/build-release.sh
```

The built app will be at:

```text
dist/CodexPulse.app
```

## Package For GitHub

```sh
scripts/package-zip.sh
```

The release zip will be created under `dist/`.

## Install

Download the zip, unzip it, and move `CodexPulse.app` to `/Applications`.

This v1 build is ad-hoc signed because no Developer ID signing identity is required. macOS may show a warning on first launch. If that happens, right-click `CodexPulse.app`, choose **Open**, then confirm.

## Notes

CodexPulse depends on the local Codex app binary at:

```text
/Applications/Codex.app/Contents/Resources/codex
```

If Codex changes its internal app-server API in a future release, CodexPulse will fall back to its cached last-known value and local Codex logs when possible.
