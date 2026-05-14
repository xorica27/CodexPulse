#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/CodexPulse.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

swift build -c release --arch arm64

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/arm64-apple-macosx/release/CodexPulse" "$MACOS_DIR/CodexPulse"
cp "Sources/CodexPulse/Info.plist" "$CONTENTS_DIR/Info.plist"

chmod +x "$MACOS_DIR/CodexPulse"

/usr/bin/codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
