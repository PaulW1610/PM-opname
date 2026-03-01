#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 && "$1" != -* ]]; then
  DEVICE_ID="$1"
  shift
else
  DEVICE_ID="$(flutter devices --machine | python3 -c 'import json,sys; d=json.load(sys.stdin); ios=[x.get("id") for x in d if x.get("targetPlatform") == "ios"]; print(ios[0] if ios else "")')"
fi

DURATION_SECONDS="${1:-180}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Geen iPhone gevonden. Verbind je iPhone en vertrouw deze Mac."
  exit 1
fi

echo "Start app op iPhone..."
./tool/launch_ios_only.sh "$DEVICE_ID" >/dev/null

echo ""
echo "Camera stress-test gestart voor ${DURATION_SECONDS}s."
echo "Voer nu in de app handmatig uit:"
echo "1) Open camera scherm"
echo "2) Wissel camera 10x"
echo "3) Zet zaklamp 10x aan/uit"
echo "4) Maak 10+ foto's met verschillende labels"
echo "5) Ga terug en open camera scherm opnieuw (3x)"
echo ""

checks=0
failures=0
end_epoch=$(( $(date +%s) + DURATION_SECONDS ))

while [[ $(date +%s) -lt $end_epoch ]]; do
  if xcrun devicectl device info processes --device "$DEVICE_ID" --filter "executablePath CONTAINS 'Runner.app/Runner'" | grep -q "Runner.app/Runner"; then
    checks=$((checks + 1))
  else
    failures=$((failures + 1))
    echo "Runner proces niet gevonden tijdens test."
    break
  fi
  sleep 3
done

if [[ $failures -eq 0 ]]; then
  echo "✅ Camera stabiliteitstest geslaagd: ${checks} health-checks zonder proces-uitval."
  exit 0
fi

echo "❌ Camera stabiliteitstest gefaald."
exit 1
