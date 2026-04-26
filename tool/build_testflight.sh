#!/usr/bin/env zsh

set -euo pipefail
export COPYFILE_DISABLE=1

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

UPLOAD=false
CLEAN=false
BUILD_NAME=""
BUILD_NUMBER=""
APPLE_ID_ARG=""
APP_PASSWORD_ARG=""
ASC_KEY_ID_ARG=""
ASC_ISSUER_ID_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload)
      UPLOAD=true
      ;;
    --clean)
      CLEAN=true
      ;;
    --build-name)
      shift
      BUILD_NAME="${1:-}"
      ;;
    --build-number)
      shift
      BUILD_NUMBER="${1:-}"
      ;;
    --apple-id)
      shift
      APPLE_ID_ARG="${1:-}"
      ;;
    --app-password)
      shift
      APP_PASSWORD_ARG="${1:-}"
      ;;
    --asc-key-id)
      shift
      ASC_KEY_ID_ARG="${1:-}"
      ;;
    --asc-issuer-id)
      shift
      ASC_ISSUER_ID_ARG="${1:-}"
      ;;
    *)
      echo "Onbekende optie: $1"
      echo "Gebruik: ./tool/build_testflight.sh [--clean] [--upload] [--build-name x.y.z] [--build-number n]"
      exit 1
      ;;
  esac
  shift
done

if [[ -f "$ROOT_DIR/.env.testflight" ]]; then
  set -a
  source "$ROOT_DIR/.env.testflight"
  set +a
fi

if [[ -n "$APPLE_ID_ARG" ]]; then
  APPLE_ID="$APPLE_ID_ARG"
fi

if [[ -n "$APP_PASSWORD_ARG" ]]; then
  APP_SPECIFIC_PASSWORD="$APP_PASSWORD_ARG"
fi

if [[ -n "$ASC_KEY_ID_ARG" ]]; then
  ASC_API_KEY_ID="$ASC_KEY_ID_ARG"
fi

if [[ -n "$ASC_ISSUER_ID_ARG" ]]; then
  ASC_API_ISSUER_ID="$ASC_ISSUER_ID_ARG"
fi

echo "📦 TestFlight build voorbereiden..."

find ios -name '._*' -type f -delete || true
find build -name '._*' -type f -delete || true
find "$HOME/.pub-cache" -name '._*' -type f -delete || true

if [[ "$CLEAN" == true ]]; then
  echo "🧹 flutter clean"
  flutter clean
fi

flutter pub get

BUILD_ARGS=("--release" "--export-method" "app-store")

if [[ -n "$BUILD_NAME" ]]; then
  BUILD_ARGS+=("--build-name" "$BUILD_NAME")
fi

if [[ -n "$BUILD_NUMBER" ]]; then
  BUILD_ARGS+=("--build-number" "$BUILD_NUMBER")
fi

echo "🚀 flutter build ipa ${BUILD_ARGS[*]}"
flutter build ipa "${BUILD_ARGS[@]}"

IPA_PATH="$(find build/ios/ipa -maxdepth 1 -name '*.ipa' | head -n 1)"
if [[ -z "$IPA_PATH" ]]; then
  echo "❌ Geen .ipa gevonden in build/ios/ipa"
  exit 1
fi

echo "✅ IPA gebouwd: $IPA_PATH"

if [[ "$UPLOAD" != true ]]; then
  echo "ℹ️ Upload overgeslagen."
  echo "   Gebruik --upload om direct naar App Store Connect te uploaden."
  echo "   Of upload handmatig met Transporter.app"
  exit 0
fi

echo "☁️ Upload naar App Store Connect..."

if [[ -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
  xcrun altool \
    --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_API_KEY_ID" \
    --apiIssuer "$ASC_API_ISSUER_ID"
  echo "✅ Upload gestart via App Store Connect API key."
  exit 0
fi

if [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
  xcrun altool \
    --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --username "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD"
  echo "✅ Upload gestart via Apple ID + app-specifiek wachtwoord."
  exit 0
fi

echo "❌ Upload gevraagd, maar credentials ontbreken."
echo "Zet één van deze combinaties in je shell:"
echo "  1) ASC_API_KEY_ID + ASC_API_ISSUER_ID"
echo "  2) APPLE_ID + APP_SPECIFIC_PASSWORD"
echo "Of zet ze in: $ROOT_DIR/.env.testflight"
exit 1
