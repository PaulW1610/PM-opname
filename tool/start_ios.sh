#!/usr/bin/env zsh

set -euo pipefail
export COPYFILE_DISABLE=1

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

find ios -name '._*' -type f -delete || true
find build -name '._*' -type f -delete || true
find "$HOME/.pub-cache" -name '._*' -type f -delete || true
if [[ -d ios/Pods ]]; then
  find ios/Pods -name '._*' -type f -delete || true
fi

ALLOW_REINSTALL=false
FORCE_REINSTALL=false
PASSTHROUGH_ARGS=()

if [[ $# -gt 0 && "$1" != -* ]]; then
  DEVICE_ID="$1"
  shift
else
  DEVICE_ID="$(flutter devices --machine | python3 -c 'import json,sys; d=json.load(sys.stdin); ios=[x.get("id") for x in d if x.get("targetPlatform") == "ios"]; print(ios[0] if ios else "")')"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-reinstall)
      ALLOW_REINSTALL=true
      ;;
    --force-reinstall)
      FORCE_REINSTALL=true
      ;;
    *)
      PASSTHROUGH_ARGS+=("$1")
      ;;
  esac
  shift
done

if [[ -z "$DEVICE_ID" ]]; then
  echo "Geen iPhone gevonden. Verbind je iPhone en vertrouw deze Mac."
  exit 1
fi

BUNDLE_ID="$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER =' ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/')"

if [[ -z "$BUNDLE_ID" ]]; then
  echo "Kon bundle-id niet bepalen."
  exit 1
fi

if [[ "$FORCE_REINSTALL" != true ]]; then
  echo "Stap 1/3: launch-only poging..."
  if ./tool/launch_ios_only.sh "$DEVICE_ID" "${PASSTHROUGH_ARGS[@]}"; then
    sleep 2
    if xcrun devicectl device info processes --device "$DEVICE_ID" --filter "executablePath CONTAINS 'Runner.app/Runner'" | grep -q "Runner.app/Runner"; then
      echo "✅ App draait op iPhone (launch-only)."
      exit 0
    fi
  fi
else
  echo "Stap 1/3: launch-only overgeslagen (force reinstall)."
fi

if [[ "$ALLOW_REINSTALL" != true ]]; then
  echo "⚠️ Launch-only start niet gelukt."
  echo "Safe mode staat aan: geen herinstallatie uitgevoerd."
  echo "Run opnieuw met: ./tool/start_ios.sh $DEVICE_ID --allow-reinstall"
  exit 1
fi

echo "Stap 2/3: fallback naar release build + install..."
xcrun devicectl device uninstall app --device "$DEVICE_ID" "$BUNDLE_ID" >/tmp/start_ios_uninstall.log 2>&1 || true
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination "id=$DEVICE_ID" -allowProvisioningUpdates build >/tmp/start_ios_xcodebuild.log 2>&1 || {
  echo "Release build mislukt. Zie /tmp/start_ios_xcodebuild.log"
  exit 1
}

APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/Build/Products/Release-iphoneos/Runner.app' | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Release app niet gevonden na build."
  exit 1
fi

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" >/tmp/start_ios_install.log 2>&1 || {
  echo "Installeren van release app mislukt. Zie /tmp/start_ios_install.log"
  exit 1
}

xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID" >/tmp/start_ios_launch.log 2>&1 || {
  echo "Launch van release app mislukt. Zie /tmp/start_ios_launch.log"
  if grep -qi "not been explicitly trusted by the user\|invalid code signature\|inadequate entitlements" /tmp/start_ios_launch.log; then
    echo "➡️ iOS blokkeert de app door trust/signing-instellingen."
    echo "   1) Ontgrendel iPhone"
    echo "   2) Ga naar Instellingen > Algemeen > VPN en apparaatbeheer"
    echo "   3) Vertrouw het ontwikkelaarsprofiel van deze Mac/Apple ID"
    echo "   4) Open de app 1x handmatig op de iPhone"
    echo "   5) Run daarna opnieuw: ./tool/start_ios.sh --allow-reinstall"
  fi
  exit 1
}

echo "Stap 3/3: controleer of proces draait..."
sleep 2
if xcrun devicectl device info processes --device "$DEVICE_ID" --filter "executablePath CONTAINS 'Runner.app/Runner'" | grep -q "Runner.app/Runner"; then
  echo "✅ App draait op iPhone."
  exit 0
fi

echo "❌ App draait niet. Ontgrendel iPhone, open de app handmatig één keer en probeer opnieuw."
exit 1
