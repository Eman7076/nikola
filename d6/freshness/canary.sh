#!/usr/bin/env bash
# D6.4 — Spock recall / index freshness canary
# Author: Nikola (Court Contract 001)
#
# Measures mtime age of a Court-configured signal path (file or directory).
# Writes a one-line status file for court.oneBell.sourceFiles fan-in.
# Does NOT read soul/memory contents — only filesystem mtime (and existence).
#
# Env (set by the systemd unit / NixOS module):
#   COURT_FRESHNESS_SIGNAL   — absolute path whose mtime is the freshness signal (required)
#   COURT_FRESHNESS_MAX_AGE  — max age in seconds before STALE (required, positive int)
#   COURT_FRESHNESS_STATUS   — output status file path for one-bell (required)
#
# Status line (single line, one-bell collapses newlines anyway):
#   FRESH signal=<path> age=<N>s max=<M>s
#   STALE signal=<path> age=<N>s max=<M>s
#   MISSING signal=<path> status=absent max=<M>s
#
# Exit: 0 on FRESH; nonzero on STALE/MISSING (oneshot ActiveState visible) after
# still writing the status file so fan-in sees fail-closed evidence.

set -euo pipefail

signal="${COURT_FRESHNESS_SIGNAL:?COURT_FRESHNESS_SIGNAL is required}"
max_age="${COURT_FRESHNESS_MAX_AGE:?COURT_FRESHNESS_MAX_AGE is required}"
status_out="${COURT_FRESHNESS_STATUS:?COURT_FRESHNESS_STATUS is required}"

if ! [[ "$max_age" =~ ^[0-9]+$ ]] || ((max_age < 1)); then
  echo "court-freshness-canary: COURT_FRESHNESS_MAX_AGE must be a positive integer (got: $max_age)" >&2
  exit 2
fi

mkdir -p "$(dirname "$status_out")"

write_status() {
  local line="$1"
  # Atomic-ish replace so one-bell never reads a half-written line.
  local tmp
  tmp="$(mktemp "${status_out}.XXXXXX")"
  printf '%s\n' "$line" >"$tmp"
  mv -f "$tmp" "$status_out"
}

now="$(date +%s)"

if [[ ! -e "$signal" ]]; then
  line="MISSING signal=${signal} status=absent max=${max_age}s"
  write_status "$line"
  echo "court-freshness-canary: $line"
  exit 1
fi

# File or directory: both expose mtime via stat. Do not open/read contents.
mtime="$(stat -c %Y "$signal" 2>/dev/null || true)"
if [[ -z "$mtime" ]] || ! [[ "$mtime" =~ ^[0-9]+$ ]]; then
  line="MISSING signal=${signal} status=unreadable max=${max_age}s"
  write_status "$line"
  echo "court-freshness-canary: $line"
  exit 1
fi

age=$((now - mtime))
# Clock skew / future mtime → treat as age 0 (fresh), not negative STALE.
if ((age < 0)); then
  age=0
fi

if ((age > max_age)); then
  line="STALE signal=${signal} age=${age}s max=${max_age}s"
  write_status "$line"
  echo "court-freshness-canary: $line"
  exit 1
fi

line="FRESH signal=${signal} age=${age}s max=${max_age}s"
write_status "$line"
echo "court-freshness-canary: $line"
exit 0
