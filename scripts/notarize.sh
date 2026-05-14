#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Notarization is intentionally not required for CodexPulse v0.1.

Future public releases can add Developer ID notarization here once these
environment variables are available:

  APPLE_ID
  APPLE_TEAM_ID
  APPLE_APP_SPECIFIC_PASSWORD

Suggested flow:
  1. Sign CodexPulse.app with Developer ID Application.
  2. Zip the app.
  3. Submit with:
     xcrun notarytool submit dist/CodexPulse-macos-arm64.zip \
       --apple-id "$APPLE_ID" \
       --team-id "$APPLE_TEAM_ID" \
       --password "$APPLE_APP_SPECIFIC_PASSWORD" \
       --wait
  4. Staple with:
     xcrun stapler staple dist/CodexPulse.app
EOF
