#!/usr/bin/env bash
# D6.2 — Court one-bell fan-in (feeds existing dead-man/sentinel; is not a second watchdog).
# Author: Nikola (Court Contract 001)
#
# Reads Court-configured source *files*. Each source contributes one status line.
# Missing/unreadable source → fail-closed measurable MISSING line (never silent skip).
# Appends one stamped block to the stream file. Optional debounce skips identical payloads.
#
# Env (set by the systemd unit / NixOS module):
#   COURT_ONE_BELL_STREAM         — path to the append-only stream (required)
#   COURT_ONE_BELL_SOURCES_FILE   — newline-separated absolute source paths (preferred)
#   COURT_ONE_BELL_SOURCES        — NUL-separated source paths (alternate; tests)
#   COURT_ONE_BELL_DEBOUNCE_SEC   — if >0 and core payload identical to last, skip append (default 0)
#
# Exit: 0 after writing a record (including all-MISSING). Nonzero only on stream I/O
# hard failure so the oneshot is observable in the journal.

set -euo pipefail

stream="${COURT_ONE_BELL_STREAM:?COURT_ONE_BELL_STREAM is required}"
debounce_sec="${COURT_ONE_BELL_DEBOUNCE_SEC:-0}"

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "$(dirname "$stream")"

core_file="$(mktemp)"
block_file="$(mktemp)"
trap 'rm -f "$core_file" "$block_file"' EXIT

ok=0
missing=0

process_source() {
  local src="$1"
  [[ -z "$src" ]] && return 0
  if [[ -f "$src" && -r "$src" ]]; then
    local line
    line="$(tr '\n\r' '  ' <"$src" | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "$line" ]]; then
      line="(empty)"
    fi
    printf 'OK source=%s line=%s\n' "$src" "$line" >>"$core_file"
    ok=$((ok + 1))
  else
    printf 'MISSING source=%s status=absent\n' "$src" >>"$core_file"
    missing=$((missing + 1))
  fi
}

if [[ -n "${COURT_ONE_BELL_SOURCES_FILE:-}" ]]; then
  if [[ -f "$COURT_ONE_BELL_SOURCES_FILE" ]]; then
    while IFS= read -r src || [[ -n "$src" ]]; do
      # Skip blank lines and comment lines.
      [[ -z "$src" || "$src" =~ ^# ]] && continue
      process_source "$src"
    done <"$COURT_ONE_BELL_SOURCES_FILE"
  else
    # Sources file itself missing → fail-closed measurable line (not silent).
    printf 'MISSING source=%s status=sources-file-absent\n' "$COURT_ONE_BELL_SOURCES_FILE" >>"$core_file"
    missing=$((missing + 1))
  fi
elif [[ -n "${COURT_ONE_BELL_SOURCES:-}" ]]; then
  while IFS= read -r -d '' src; do
    process_source "$src"
  done < <(printf '%s' "$COURT_ONE_BELL_SOURCES")
fi

{
  printf '%s BEGIN ok=%s missing=%s\n' "$ts" "$ok" "$missing"
  cat "$core_file"
  printf '%s END ok=%s missing=%s\n' "$ts" "$ok" "$missing"
} >"$block_file"

new_core="$(cat "$core_file")"

if [[ "$debounce_sec" =~ ^[0-9]+$ ]] && ((debounce_sec > 0)) && [[ -f "$stream" ]]; then
  old_core="$(
    awk '
      /^[0-9]{4}-[0-9]{2}-[0-9]{2}T.* BEGIN / { buf = ""; capturing = 1; next }
      capturing && /^[0-9]{4}-[0-9]{2}-[0-9]{2}T.* END / {
        last = buf; capturing = 0; next
      }
      capturing { buf = buf $0 "\n" }
      END { printf "%s", last }
    ' "$stream"
  )"
  if [[ -n "$old_core" && "$new_core" == "$old_core" ]]; then
    last_mtime="$(stat -c %Y "$stream" 2>/dev/null || echo 0)"
    now="$(date +%s)"
    age=$((now - last_mtime))
    if ((age < debounce_sec)); then
      echo "court-one-bell: debounced identical payload (age=${age}s < ${debounce_sec}s)"
      exit 0
    fi
  fi
fi

cat "$block_file" >>"$stream"
echo "court-one-bell: wrote stream=$stream ok=$ok missing=$missing"
exit 0
