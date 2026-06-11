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
misses=0
consecutive_misses=0
# devicectl-processquery is soms flaky; pas falen na meerdere missers op rij.
MAX_CONSECUTIVE_MISSES="${MAX_CONSECUTIVE_MISSES:-4}"
end_epoch=$(( $(date +%s) + DURATION_SECONDS ))

while [[ $(date +%s) -lt $end_epoch ]]; do
  if xcrun devicectl device info processes --device "$DEVICE_ID" --filter "executablePath CONTAINS 'Runner.app/Runner'" 2>/dev/null | grep -q "Runner.app/Runner"; then
    checks=$((checks + 1))
    consecutive_misses=0
  else
    misses=$((misses + 1))
    consecutive_misses=$((consecutive_misses + 1))
    echo "Health-check miste ($consecutive_misses/$MAX_CONSECUTIVE_MISSES op rij)."
    if [[ $consecutive_misses -ge $MAX_CONSECUTIVE_MISSES ]]; then
      echo "❌ Camera stabiliteitstest gefaald: app-proces ${consecutive_misses}x op rij niet gevonden (waarschijnlijke crash)."
      echo "   checks=$checks totale-missers=$misses"
      exit 1
    fi
  fi
  sleep 3
done

echo "✅ Camera stabiliteitstest geslaagd: ${checks} health-checks, ${misses} losse misser(s) (flaky query), geen crash."
exit 0
