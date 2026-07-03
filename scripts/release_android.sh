#!/usr/bin/env bash
# Build a signed Android App Bundle and upload to Google Play via Fastlane.
#
# Usage:
#   ./scripts/release_android.sh                    # build + upload to internal track
#   TRACK=beta ./scripts/release_android.sh         # upload to beta track
#   SKIP_BUILD=1 ./scripts/release_android.sh       # upload existing AAB only
#   BUILD_ONLY=1 ./scripts/release_android.sh       # build only, no upload
#
# Prerequisites:
#   - android/key.properties + upload keystore configured
#   - android/fastlane/play-store-key.json (see README)
#   - bundle install in android/ (first time)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TRACK="${TRACK:-internal}"
RELEASE_STATUS="${RELEASE_STATUS:-completed}"

cd "$ROOT_DIR/android"

if ! command -v bundle >/dev/null 2>&1; then
  echo "Error: bundler not found. Install Ruby, then: gem install bundler"
  exit 1
fi

if [[ ! -f fastlane/play-store-key.json ]]; then
  echo "Error: missing android/fastlane/play-store-key.json"
  echo "Copy fastlane/play-store-key.json.example and add your Play Console service account key."
  echo "See README → Publish to Google Play Store → Fastlane setup."
  exit 1
fi

bundle check >/dev/null 2>&1 || bundle install

if [[ "${BUILD_ONLY:-}" == "1" ]]; then
  echo "==> Building release app bundle..."
  bundle exec fastlane android build
  echo ""
  echo "Done. AAB: build/app/outputs/bundle/release/app-release.aab"
  exit 0
fi

if [[ "${SKIP_BUILD:-}" == "1" ]]; then
  echo "==> Uploading to Play Store (track: $TRACK)..."
  bundle exec fastlane android upload track:"$TRACK" release_status:"$RELEASE_STATUS"
else
  echo "==> Building and uploading to Play Store (track: $TRACK)..."
  bundle exec fastlane android release track:"$TRACK" release_status:"$RELEASE_STATUS"
fi

echo ""
echo "Done. Check Play Console for the new release on track: $TRACK"
