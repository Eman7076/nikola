#!/usr/bin/env bash
# C002.1 — verify required recovery-stick paths are present (no network, no secrets).
# Usage: check-stick.sh <mounted-stick-root>
# Manifest: $STICK/court-recovery/manifest.txt or $COURT_RECOVERY_MANIFEST
# Author: Nikola (Court Contract 002) — Court runs against real stick; VM uses fake tree.

set -euo pipefail

usage() {
  echo "Usage: $0 <mounted-stick-root>" >&2
  echo "  Reads manifest at <root>/court-recovery/manifest.txt" >&2
  echo "  or path in COURT_RECOVERY_MANIFEST." >&2
  exit 2
}

if [[ "${1:-}" == "" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

STICK_ROOT="${1%/}"
if [[ ! -d "$STICK_ROOT" ]]; then
  echo "MISSING stick-root (not a directory): $STICK_ROOT" >&2
  exit 1
fi

MANIFEST="${COURT_RECOVERY_MANIFEST:-$STICK_ROOT/court-recovery/manifest.txt}"
if [[ ! -f "$MANIFEST" ]]; then
  echo "MISSING manifest: $MANIFEST" >&2
  exit 1
fi
if [[ ! -s "$MANIFEST" ]]; then
  echo "MISSING manifest (empty file): $MANIFEST" >&2
  exit 1
fi

ok=0
missing=0

# Optional FLAKE_PIN.txt format check when that path is present on the stick.
check_flake_pin() {
  local pin="$1"
  [[ -f "$pin" ]] || return 0
  if grep -qE '^rev=[0-9a-fA-F]{40}$' "$pin"; then
    echo "OK    FLAKE_PIN rev= format: $pin"
    return 0
  fi
  # Present but wrong format → fail-closed (Court should fix before claiming ready).
  echo "MISSING FLAKE_PIN rev=<40 hex> line: $pin" >&2
  return 1
}

while IFS= read -r raw || [[ -n "$raw" ]]; do
  # Trim CR; skip blanks and comments
  line="${raw%$'\r'}"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  # Trim leading/trailing whitespace
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue

  # Reject absolute paths and .. traversal — stick-relative only
  if [[ "$line" == /* || "$line" == *..* ]]; then
    echo "MISSING unsafe path in manifest (must be relative, no ..): $line" >&2
    missing=$((missing + 1))
    continue
  fi

  target="$STICK_ROOT/$line"

  if [[ -d "$target" ]]; then
    echo "OK    dir  $line"
    ok=$((ok + 1))
  elif [[ -f "$target" ]]; then
    if [[ -s "$target" ]]; then
      echo "OK    file $line"
      ok=$((ok + 1))
    else
      echo "MISSING empty file: $line" >&2
      missing=$((missing + 1))
    fi
  else
    echo "MISSING $line" >&2
    missing=$((missing + 1))
  fi
done < "$MANIFEST"

# If FLAKE_PIN.txt exists under court-recovery, validate rev= line.
PIN_CANDIDATE="$STICK_ROOT/court-recovery/FLAKE_PIN.txt"
if [[ -e "$PIN_CANDIDATE" ]]; then
  if check_flake_pin "$PIN_CANDIDATE"; then
    :
  else
    missing=$((missing + 1))
  fi
fi

echo "summary: ok=$ok missing=$missing manifest=$MANIFEST"
if [[ "$missing" -ne 0 ]]; then
  exit 1
fi
exit 0
