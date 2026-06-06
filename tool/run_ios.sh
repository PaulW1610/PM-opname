#!/usr/bin/env zsh

set -euo pipefail
export COPYFILE_DISABLE=1

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

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

mkdir -p build/ios/Debug-iphoneos
mkdir -p build/ios/Release-iphoneos
mkdir -p build/ios/Profile-iphoneos
mkdir -p build/ios/iphoneos

DART_DEFINES=()
if [[ -f "$ROOT_DIR/tool/dart_defines.json" ]]; then
  DART_DEFINES+=("--dart-define-from-file=$ROOT_DIR/tool/dart_defines.json")
else
  echo "⚠️  tool/dart_defines.json ontbreekt – API-keys (BAG/Dropbox) zijn leeg."
  echo "    Kopieer tool/dart_defines.example.json naar tool/dart_defines.json en vul je keys in."
fi

run_flutter() {
  find ios -name '._*' -type f -delete || true
  find build -name '._*' -type f -delete || true
  find "$HOME/.pub-cache" -name '._*' -type f -delete || true
  if [[ -d ios/Pods ]]; then
    find ios/Pods -name '._*' -type f -delete || true
  fi
  flutter run -d "$DEVICE_ID" "${DART_DEFINES[@]}" "$@"
}

echo "Starten op iPhone device: $DEVICE_ID"
if ! run_flutter "$@"; then
  echo "Eerste start mislukt, opnieuw proberen met iOS build-map workaround..."
  mkdir -p build/ios/Debug-iphoneos
  mkdir -p build/ios/Release-iphoneos
  mkdir -p build/ios/Profile-iphoneos
  mkdir -p build/ios/iphoneos
  run_flutter "$@"
fi
