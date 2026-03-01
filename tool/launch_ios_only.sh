#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun niet gevonden. Installeer Xcode command line tools."
  exit 1
fi

if [[ $# -gt 0 && "$1" != -* ]]; then
  DEVICE_ID="$1"
  shift
else
  DEVICE_ID="$(flutter devices --machine | python3 -c 'import json,sys; d=json.load(sys.stdin); ios=[x.get("id") for x in d if x.get("targetPlatform") == "ios"]; print(ios[0] if ios else "")')"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "Geen iPhone gevonden. Verbind je iPhone en vertrouw deze Mac."
  exit 1
fi

DEFAULT_BUNDLE_ID="$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER =' ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/')"
BUNDLE_ID="${BUNDLE_ID:-$DEFAULT_BUNDLE_ID}"

if [[ -z "$BUNDLE_ID" ]]; then
  echo "Kon bundle-id niet bepalen. Zet BUNDLE_ID handmatig."
  exit 1
fi

echo "Launch app op iPhone device: $DEVICE_ID"
echo "Bundle ID: $BUNDLE_ID"

LOCK_STATE="$(xcrun devicectl device info lockState --device "$DEVICE_ID" 2>/dev/null || true)"
if [[ "$LOCK_STATE" == *"passcodeRequired: true"* || "$LOCK_STATE" == *"unlockedSinceBoot: false"* ]]; then
  echo "iPhone is vergrendeld. Ontgrendel het toestel en probeer opnieuw."
  exit 1
fi

xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  "$BUNDLE_ID" \
  "$@"
