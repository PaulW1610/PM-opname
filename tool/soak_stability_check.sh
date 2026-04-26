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

DURATION_SECONDS="${1:-1800}"
CHECK_INTERVAL_SECONDS="${2:-5}"
MAX_RELAUNCHES="${3:-3}"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Geen iPhone gevonden. Verbind je iPhone en vertrouw deze Mac."
  exit 1
fi

BUNDLE_ID="$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER =' ios/Runner.xcodeproj/project.pbxproj | sed -E 's/.*= ([^;]+);/\1/')"
if [[ -z "$BUNDLE_ID" ]]; then
  echo "Kon bundle-id niet bepalen."
  exit 1
fi

LOG_DIR="$ROOT_DIR/build/soak_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/soak_$(date +%Y%m%d_%H%M%S).log"

log() {
  local msg="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $msg" | tee -a "$LOG_FILE"
}

is_runner_alive() {
  xcrun devicectl device info processes --device "$DEVICE_ID" --filter "executablePath CONTAINS 'Runner.app/Runner'" | grep -q "Runner.app/Runner"
}

log "Soak test start: duration=${DURATION_SECONDS}s interval=${CHECK_INTERVAL_SECONDS}s max_relaunches=${MAX_RELAUNCHES}"
log "Device: $DEVICE_ID"
log "Bundle: $BUNDLE_ID"

if ! ./tool/start_ios.sh "$DEVICE_ID" --allow-reinstall >/dev/null 2>&1; then
  log "Start via start_ios.sh mislukt. Controleer of het toestel ontgrendeld is en het profiel vertrouwd is."
  exit 1
fi

end_epoch=$(( $(date +%s) + DURATION_SECONDS ))
checks=0
relaunches=0
failures=0

while [[ $(date +%s) -lt $end_epoch ]]; do
  if is_runner_alive; then
    checks=$((checks + 1))
  else
    failures=$((failures + 1))
    log "Runner proces niet gevonden, relaunch poging $((relaunches + 1))/$MAX_RELAUNCHES"

    if [[ $relaunches -ge $MAX_RELAUNCHES ]]; then
      log "Max relaunches bereikt. Soak test faalt."
      break
    fi

    if ./tool/launch_ios_only.sh "$DEVICE_ID" >/dev/null 2>&1; then
      relaunches=$((relaunches + 1))
      sleep 2
      if is_runner_alive; then
        log "Relaunch geslaagd."
      else
        log "Relaunch uitgevoerd maar Runner blijft down."
        failures=$((failures + 1))
        break
      fi
    else
      log "Relaunch mislukt (mogelijk lock state / signing trust)."
      failures=$((failures + 1))
      break
    fi
  fi

  sleep "$CHECK_INTERVAL_SECONDS"
done

if [[ $failures -eq 0 ]]; then
  log "✅ Soak test geslaagd: checks=$checks relaunches=$relaunches failures=$failures"
  log "Logbestand: $LOG_FILE"
  exit 0
fi

log "❌ Soak test gefaald: checks=$checks relaunches=$relaunches failures=$failures"
log "Logbestand: $LOG_FILE"
exit 1
