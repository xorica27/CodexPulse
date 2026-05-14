#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/CodexPulse.app"
ZIP_PATH="$DIST_DIR/CodexPulse-macos-arm64.zip"

if [[ ! -d "$APP_DIR" ]]; then
  "$ROOT_DIR/scripts/build-release.sh"
fi

rm -f "$ZIP_PATH"
(
  cd "$DIST_DIR"
  /usr/bin/zip -qry -X "$ZIP_PATH" "CodexPulse.app"
)

echo "Packaged $ZIP_PATH"
