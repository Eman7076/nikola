#!/usr/bin/env bash
# D6.4 — pure canary unit proof (no QEMU, no NixOS).
# Proves: fresh → FRESH+exit0; old mtime → STALE+exit1; missing → MISSING+exit1.
# Author: Nikola (Court Contract 001)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CANARY="${ROOT}/canary.sh"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

signal="${WORKDIR}/signal.stamp"
status="${WORKDIR}/freshness.status"
max_age=60

run_canary() {
  COURT_FRESHNESS_SIGNAL="$signal" \
    COURT_FRESHNESS_MAX_AGE="$max_age" \
    COURT_FRESHNESS_STATUS="$status" \
    bash "$CANARY"
}

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# --- fresh file → FRESH ---
touch "$signal"
set +e
out="$(run_canary 2>&1)"
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "fresh: expected exit 0, got $rc ($out)"
grep -q '^FRESH ' "$status" || fail "fresh: status missing FRESH line: $(cat "$status")"
grep -q "max=${max_age}s" "$status" || fail "fresh: missing max=: $(cat "$status")"
echo "ok fresh → $(cat "$status")"

# --- old mtime → STALE ---
touch -d '2 hours ago' "$signal"
set +e
out="$(run_canary 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "stale: expected nonzero exit, got 0 ($out)"
grep -q '^STALE ' "$status" || fail "stale: status missing STALE line: $(cat "$status")"
grep -q 'age=' "$status" || fail "stale: missing age=: $(cat "$status")"
echo "ok stale → $(cat "$status")"

# --- missing → MISSING (status still written) ---
rm -f "$signal"
set +e
out="$(run_canary 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "missing: expected nonzero exit, got 0 ($out)"
grep -q '^MISSING ' "$status" || fail "missing: status missing MISSING line: $(cat "$status")"
grep -q 'status=absent' "$status" || fail "missing: missing status=absent: $(cat "$status")"
echo "ok missing → $(cat "$status")"

# --- directory mtime also works ---
sigdir="${WORKDIR}/signal.dir"
mkdir -p "$sigdir"
touch "$sigdir"
set +e
out="$(
  COURT_FRESHNESS_SIGNAL="$sigdir" \
    COURT_FRESHNESS_MAX_AGE="$max_age" \
    COURT_FRESHNESS_STATUS="$status" \
    bash "$CANARY" 2>&1
)"
rc=$?
set -e
[[ "$rc" -eq 0 ]] || fail "dir-fresh: expected exit 0, got $rc ($out)"
grep -q '^FRESH ' "$status" || fail "dir-fresh: expected FRESH: $(cat "$status")"
echo "ok dir-fresh → $(cat "$status")"

echo "d6-freshness canary script proof: all cases passed"
