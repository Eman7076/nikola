#!/usr/bin/env bash
# D6.2.1 — pure watch.sh unit proof (no QEMU, no NixOS).
# Proves change-only emit: fresh silent, stale once, recovery once, unreachable once,
# failing source once, heartbeat timeout → UNREACHABLE timeout (exits), clock skew.
# Fake heartbeatCommand cats fixtures / fails / sleeps.
# Author: Nikola (Court Contract 001)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
WATCH="${ROOT}/watch.sh"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

log="${WORKDIR}/watch.log"
state="${WORKDIR}/watch.state"
fixtures="${WORKDIR}/fixtures"
mkdir -p "$fixtures"

# GUESS thresholds under test (same defaults as module).
STALE_AFTER=300
FAILING_RUNS=3
HB_TIMEOUT=30
CLOCK_SKEW=60

now="$(date +%s)"
fresh_ts="$now"
stale_ts=$((now - STALE_AFTER - 60))
# Future timestamp beyond clockSkewSec GUESS (60).
skew_ts=$((now + CLOCK_SKEW + 30))

cat >"${fixtures}/fresh.json" <<JSON
{"feeder_last_run": ${fresh_ts},
 "sources": {"igris-note": {"status": "ok", "fails": 0, "last_ok": ${fresh_ts}, "last_error": ""},
             "igris-log":  {"status": "ok", "fails": 0, "last_ok": ${fresh_ts}, "last_error": ""}}}
JSON

cat >"${fixtures}/stale.json" <<JSON
{"feeder_last_run": ${stale_ts},
 "sources": {"igris-note": {"status": "ok", "fails": 0, "last_ok": ${stale_ts}, "last_error": ""},
             "igris-log":  {"status": "ok", "fails": 0, "last_ok": ${stale_ts}, "last_error": ""}}}
JSON

cat >"${fixtures}/failing-source.json" <<JSON
{"feeder_last_run": ${fresh_ts},
 "sources": {"igris-note": {"status": "failing", "fails": 3, "last_ok": ${stale_ts}, "last_error": "boom"},
             "igris-log":  {"status": "ok", "fails": 0, "last_ok": ${fresh_ts}, "last_error": ""}}}
JSON

cat >"${fixtures}/skew.json" <<JSON
{"feeder_last_run": ${skew_ts},
 "sources": {"igris-note": {"status": "ok", "fails": 0, "last_ok": ${skew_ts}, "last_error": ""}}}
JSON

fail() {
  echo "FAIL: $*" >&2
  echo "--- log ---" >&2
  cat "$log" 2>/dev/null >&2 || true
  echo "--- state ---" >&2
  cat "$state" 2>/dev/null >&2 || true
  exit 1
}

run_watch() {
  local cmd="$1"
  local timeout_sec="${2:-$HB_TIMEOUT}"
  COURT_ONE_BELL_HEARTBEAT_CMD="$cmd" \
    COURT_ONE_BELL_HEARTBEAT_TIMEOUT_SEC="$timeout_sec" \
    COURT_ONE_BELL_STALE_AFTER_SEC="$STALE_AFTER" \
    COURT_ONE_BELL_SOURCE_FAILING_RUNS="$FAILING_RUNS" \
    COURT_ONE_BELL_CLOCK_SKEW_SEC="$CLOCK_SKEW" \
    COURT_ONE_BELL_LOG_PATH="$log" \
    COURT_ONE_BELL_STATE_PATH="$state" \
    COURT_ONE_BELL_ALERT_CMD="" \
    bash "$WATCH"
}

line_count() {
  if [[ -f "$log" ]]; then
    wc -l <"$log" | tr -d ' '
  else
    echo 0
  fi
}

# --- 1. fresh stays silent (two ticks) ---
rm -f "$log" "$state"
run_watch "cat ${fixtures}/fresh.json"
run_watch "cat ${fixtures}/fresh.json"
[[ "$(line_count)" -eq 0 ]] || fail "fresh×2: expected 0 log lines, got $(line_count)"
grep -q '^overall=FRESH$' "$state" || fail "fresh: state overall != FRESH"
echo "ok fresh stays silent (two ticks)"

# --- 2. stale once then silent on second stale tick ---
rm -f "$log" "$state"
run_watch "cat ${fixtures}/fresh.json"
run_watch "cat ${fixtures}/stale.json"
[[ "$(line_count)" -eq 1 ]] || fail "stale once: expected 1 line, got $(line_count)"
grep -q 'FEEDER stale age=' "$log" || fail "stale once: missing FEEDER stale line"
run_watch "cat ${fixtures}/stale.json"
[[ "$(line_count)" -eq 1 ]] || fail "stale×2: expected still 1 line, got $(line_count)"
echo "ok stale once then silent"

# --- 3. recovery (stale→fresh) once ---
rm -f "$log" "$state"
run_watch "cat ${fixtures}/stale.json"
[[ "$(line_count)" -eq 1 ]] || fail "recovery setup: expected 1 stale line"
run_watch "cat ${fixtures}/fresh.json"
[[ "$(line_count)" -eq 2 ]] || fail "recovery: expected 2 lines, got $(line_count)"
grep -q 'FEEDER fresh' "$log" || fail "recovery: missing FEEDER fresh"
run_watch "cat ${fixtures}/fresh.json"
[[ "$(line_count)" -eq 2 ]] || fail "recovery stay: expected still 2 lines"
echo "ok recovery (stale→fresh) once"

# --- 4. unreachable once ---
rm -f "$log" "$state"
run_watch "cat ${fixtures}/fresh.json"
run_watch "false"
[[ "$(line_count)" -eq 1 ]] || fail "unreachable: expected 1 line, got $(line_count)"
grep -q 'FEEDER unreachable:' "$log" || fail "unreachable: missing line"
run_watch "false"
[[ "$(line_count)" -eq 1 ]] || fail "unreachable×2: expected still 1 line"
# recover from unreachable → fresh emits
run_watch "cat ${fixtures}/fresh.json"
[[ "$(line_count)" -eq 2 ]] || fail "unreachable recovery: expected 2 lines"
grep -q 'FEEDER fresh' "$log" || fail "unreachable recovery: missing FEEDER fresh"
echo "ok unreachable once (+ recovery)"

# --- 5. failing source once ---
rm -f "$log" "$state"
run_watch "cat ${fixtures}/fresh.json"
run_watch "cat ${fixtures}/failing-source.json"
[[ "$(line_count)" -eq 1 ]] || fail "failing source: expected 1 line, got $(line_count)"
grep -q 'SOURCE igris-note failing fails=3' "$log" || fail "failing source: missing SOURCE line: $(cat "$log")"
run_watch "cat ${fixtures}/failing-source.json"
[[ "$(line_count)" -eq 1 ]] || fail "failing source×2: expected still 1 line"
# recover source
run_watch "cat ${fixtures}/fresh.json"
[[ "$(line_count)" -eq 2 ]] || fail "source recovery: expected 2 lines"
grep -q 'SOURCE igris-note ok' "$log" || fail "source recovery: missing ok line"
echo "ok failing source once (+ recovery)"

# --- 6. invalid JSON → unreachable ---
rm -f "$log" "$state"
run_watch "printf 'not-json'"
[[ "$(line_count)" -eq 1 ]] || fail "invalid json: expected 1 line"
grep -q 'FEEDER unreachable:' "$log" || fail "invalid json: missing unreachable"
echo "ok invalid JSON → unreachable"

# --- 7. heartbeat timeout (sleep 60, timeout 2) → ONE unreachable mentioning timeout; script exits ---
# Spock D6.2.1 blocking ask.
rm -f "$log" "$state"
# Use a wall-clock bound so a hang fails the test instead of waiting forever.
timeout 15 bash -c '
  COURT_ONE_BELL_HEARTBEAT_CMD="sleep 60" \
    COURT_ONE_BELL_HEARTBEAT_TIMEOUT_SEC="2" \
    COURT_ONE_BELL_STALE_AFTER_SEC="'"$STALE_AFTER"'" \
    COURT_ONE_BELL_SOURCE_FAILING_RUNS="'"$FAILING_RUNS"'" \
    COURT_ONE_BELL_CLOCK_SKEW_SEC="'"$CLOCK_SKEW"'" \
    COURT_ONE_BELL_LOG_PATH="'"$log"'" \
    COURT_ONE_BELL_STATE_PATH="'"$state"'" \
    COURT_ONE_BELL_ALERT_CMD="" \
    bash "'"$WATCH"'"
' || {
  rc=$?
  if [[ $rc -eq 124 ]]; then
    fail "timeout test: watch.sh itself hung past 15s (inner timeout did not fire)"
  else
    fail "timeout test: watch.sh exited nonzero rc=$rc"
  fi
}
[[ "$(line_count)" -eq 1 ]] || fail "timeout: expected 1 line, got $(line_count): $(cat "$log" 2>/dev/null || true)"
grep -qi 'timeout' "$log" || fail "timeout: unreachable line must mention timeout: $(cat "$log")"
grep -q 'FEEDER unreachable:' "$log" || fail "timeout: missing FEEDER unreachable"
# Second tick still timed out → silent (change-only)
timeout 15 bash -c '
  COURT_ONE_BELL_HEARTBEAT_CMD="sleep 60" \
    COURT_ONE_BELL_HEARTBEAT_TIMEOUT_SEC="2" \
    COURT_ONE_BELL_STALE_AFTER_SEC="'"$STALE_AFTER"'" \
    COURT_ONE_BELL_SOURCE_FAILING_RUNS="'"$FAILING_RUNS"'" \
    COURT_ONE_BELL_CLOCK_SKEW_SEC="'"$CLOCK_SKEW"'" \
    COURT_ONE_BELL_LOG_PATH="'"$log"'" \
    COURT_ONE_BELL_STATE_PATH="'"$state"'" \
    COURT_ONE_BELL_ALERT_CMD="" \
    bash "'"$WATCH"'"
' || fail "timeout×2: watch.sh failed"
[[ "$(line_count)" -eq 1 ]] || fail "timeout×2: expected still 1 line, got $(line_count)"
echo "ok heartbeat timeout → one unreachable (timeout), script exits"

# --- 8. clock skew enter / leave (GUESS clockSkewSec=60) ---
rm -f "$log" "$state"
run_watch "cat ${fixtures}/fresh.json"
[[ "$(line_count)" -eq 0 ]] || fail "skew setup: expected 0 lines"
run_watch "cat ${fixtures}/skew.json"
[[ "$(line_count)" -eq 1 ]] || fail "skew enter: expected 1 line, got $(line_count): $(cat "$log")"
grep -qE 'CLOCK skew [0-9]+s' "$log" || fail "skew enter: missing CLOCK skew line: $(cat "$log")"
run_watch "cat ${fixtures}/skew.json"
[[ "$(line_count)" -eq 1 ]] || fail "skew stay: expected still 1 line"
run_watch "cat ${fixtures}/fresh.json"
[[ "$(line_count)" -eq 2 ]] || fail "skew leave: expected 2 lines, got $(line_count)"
grep -q 'CLOCK ok' "$log" || fail "skew leave: missing CLOCK ok"
echo "ok clock skew enter/leave (change-only)"

echo "d6-one-bell watch script proof: all cases passed"
