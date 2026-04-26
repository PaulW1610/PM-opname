#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "TestFlight credentials instellen (.env.testflight)"

read "apple_id?Apple ID e-mail: "
if [[ -z "${apple_id// }" ]]; then
  echo "Apple ID is verplicht."
  exit 1
fi

read -s "app_password?App-specifiek wachtwoord: "
echo
if [[ -z "${app_password// }" ]]; then
  echo "App-specifiek wachtwoord is verplicht."
  exit 1
fi

# Apple app-specifieke wachtwoorden zijn 16 letters, vaak getoond als xxxx-xxxx-xxxx-xxxx.
# We normaliseren invoer zodat streepjes/spaties niet uitmaken.
normalized_password="${app_password//[- ]/}"
if [[ ! "$normalized_password" =~ ^[A-Za-z]{16}$ ]]; then
  echo "Ongeldig app-specifiek wachtwoordformaat."
  echo "Gebruik een Apple app-specifiek wachtwoord van 16 letters (streepjes/spaties mogen)."
  exit 1
fi

cat > .env.testflight <<EOF
APPLE_ID="$apple_id"
APP_SPECIFIC_PASSWORD="$normalized_password"
EOF

chmod 600 .env.testflight

echo "✅ .env.testflight opgeslagen met rechten 600"
echo "Volgende stap: ./tool/build_testflight.sh --upload"
