#!/usr/bin/env bash
# D6.2 — Court one-bell bus heartbeat watcher (revised 2026-09-25)
# Author: Nikola (Court Contract 001)
#
# Watcher-of-the-watcher on **controller**: polls a Court-supplied heartbeatCommand
# that prints the rig feeder's heartbeat JSON. Emits change-only lines to a local
# log. Does NOT invent hosts/keys/paths; does NOT ship alert sinks/tokens.
#
# Old job (local file fan-in → stream for dead-man) is superseded: the one bus
# lives on the rig; Spock's session tails it there, but if the rig dies that
# watch dies with it. This module notices from OUTSIDE (controller).
#
# Env (set by the systemd unit / NixOS module / tests):
#   COURT_ONE_BELL_HEARTBEAT_CMD     — shell command printing heartbeat JSON (required)
#   COURT_ONE_BELL_STALE_AFTER_SEC   — GUESS default 300 (Spock: "say 5 min")
#   COURT_ONE_BELL_SOURCE_FAILING_RUNS — GUESS default 3 (align feeder HEALTH)
#   COURT_ONE_BELL_LOG_PATH          — change-only log on controller
#   COURT_ONE_BELL_STATE_PATH        — last emitted conditions (for change detect)
#   COURT_ONE_BELL_ALERT_CMD         — optional; if non-empty, run once per change
#                                      with COURT_ONE_BELL_EVENT set to the log line
#
# Heartbeat JSON shape (FACT from Spock 2026-09-25):
#   {"feeder_last_run": <unix float>,
#    "sources": {"name": {"status":"ok"|"failing","fails":N,"last_ok":...,"last_error":""}}}
#
# Exit: 0 after a successful tick (including UNREACHABLE / STALE — those are
# measured conditions, not script failures). Nonzero only on hard misconfig
# (missing required env) so the oneshot is observable.

set -euo pipefail

heartbeat_cmd="${COURT_ONE_BELL_HEARTBEAT_CMD:?COURT_ONE_BELL_HEARTBEAT_CMD is required}"
# GUESS: Spock said “say 5 min” for feeder stale from outside.
stale_after_sec="${COURT_ONE_BELL_STALE_AFTER_SEC:-300}"
# GUESS: align with feeder’s three-run HEALTH before treating a source as failing.
source_failing_runs="${COURT_ONE_BELL_SOURCE_FAILING_RUNS:-3}"
log_path="${COURT_ONE_BELL_LOG_PATH:?COURT_ONE_BELL_LOG_PATH is required}"
state_path="${COURT_ONE_BELL_STATE_PATH:?COURT_ONE_BELL_STATE_PATH is required}"
alert_cmd="${COURT_ONE_BELL_ALERT_CMD:-}"

if ! [[ "$stale_after_sec" =~ ^[0-9]+$ ]] || ((stale_after_sec < 1)); then
  echo "court-one-bell: COURT_ONE_BELL_STALE_AFTER_SEC must be a positive integer" >&2
  exit 2
fi
if ! [[ "$source_failing_runs" =~ ^[0-9]+$ ]] || ((source_failing_runs < 1)); then
  echo "court-one-bell: COURT_ONE_BELL_SOURCE_FAILING_RUNS must be a positive integer" >&2
  exit 2
fi

mkdir -p "$(dirname "$log_path")" "$(dirname "$state_path")"

now="$(date +%s)"
ts="$(date +"%Y-%m-%d %H:%M:%S")"

# --- fetch heartbeat ---
hb_tmp="$(mktemp)"
hb_err="$(mktemp)"
trap 'rm -f "$hb_tmp" "$hb_err"' EXIT

overall="UNREACHABLE"
overall_detail="unknown"
declare -A src_status=()

set +e
# shellcheck disable=SC2086
bash -c "$heartbeat_cmd" >"$hb_tmp" 2>"$hb_err"
hb_rc=$?
set -e

hb_body="$(cat "$hb_tmp" 2>/dev/null || true)"
hb_err_body="$(tr '\n' ' ' <"$hb_err" | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//')"

if ((hb_rc != 0)); then
  overall="UNREACHABLE"
  overall_detail="cmd_exit=${hb_rc}${hb_err_body:+ msg=${hb_err_body}}"
elif [[ -z "${hb_body//[[:space:]]/}" ]]; then
  overall="UNREACHABLE"
  overall_detail="empty_stdout"
elif ! echo "$hb_body" | jq -e . >/dev/null 2>&1; then
  overall="UNREACHABLE"
  overall_detail="invalid_json"
elif ! echo "$hb_body" | jq -e 'has("feeder_last_run")' >/dev/null 2>&1; then
  overall="UNREACHABLE"
  overall_detail="missing_feeder_last_run"
else
  feeder_last_run="$(echo "$hb_body" | jq -r '.feeder_last_run')"
  # Accept int or float Unix seconds.
  if ! [[ "$feeder_last_run" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    overall="UNREACHABLE"
    overall_detail="bad_feeder_last_run=${feeder_last_run}"
  else
    # Bash arithmetic truncates float; age in whole seconds is fine for thresholds.
    feeder_sec="${feeder_last_run%%.*}"
    age=$((now - feeder_sec))
    if ((age < 0)); then
      age=0
    fi
    if ((age > stale_after_sec)); then
      overall="STALE"
      overall_detail="age=${age}s"
    else
      overall="FRESH"
      overall_detail="age=${age}s"
    fi

    # Per-source failing: status=="failing" AND fails >= sourceFailingRuns (GUESS).
    while IFS=$'\t' read -r name status fails; do
      [[ -z "$name" || "$name" == "null" ]] && continue
      fails_n=0
      if [[ "$fails" =~ ^[0-9]+$ ]]; then
        fails_n="$fails"
      fi
      if [[ "$status" == "failing" ]] && ((fails_n >= source_failing_runs)); then
        src_status["$name"]="failing"
      else
        src_status["$name"]="ok"
      fi
    done < <(echo "$hb_body" | jq -r '
      (.sources // {}) | to_entries[] |
      [.key, (.value.status // "unknown"), (.value.fails // 0 | tostring)] | @tsv
    ')
  fi
fi

# --- load previous state ---
prev_overall=""
declare -A prev_src=()
if [[ -f "$state_path" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    if [[ "$line" =~ ^overall=(.*)$ ]]; then
      prev_overall="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^source:([^=]+)=(.*)$ ]]; then
      prev_src["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done <"$state_path"
fi

emit() {
  local event="$1"
  local line="${ts} court-one-bell ${event}"
  printf '%s\n' "$line" >>"$log_path"
  echo "court-one-bell: $line"
  if [[ -n "$alert_cmd" ]]; then
    set +e
    COURT_ONE_BELL_EVENT="$line" bash -c "$alert_cmd"
    set -e
  fi
}

# --- overall change ---
if [[ "$overall" != "$prev_overall" ]]; then
  case "$overall" in
    FRESH)
      # Emit only on recovery (stale→fresh or unreachable→fresh).
      # Initial FRESH (empty prev) and fresh→fresh stay silent (Nikola proposal / test contract).
      if [[ "$prev_overall" == "STALE" || "$prev_overall" == "UNREACHABLE" ]]; then
        emit "FEEDER fresh"
      fi
      ;;
    STALE)
      emit "FEEDER stale ${overall_detail}"
      ;;
    UNREACHABLE)
      emit "FEEDER unreachable: ${overall_detail}"
      ;;
  esac
fi
# Same overall → silent (stale stays stale, fresh stays fresh, unreachable stays).

# --- source changes (only when heartbeat was parseable; skip noise on UNREACHABLE) ---
if [[ "$overall" != "UNREACHABLE" ]]; then
  # Newly failing / recovered
  for name in "${!src_status[@]}"; do
    cur="${src_status[$name]}"
    prev="${prev_src[$name]:-}"
    if [[ "$cur" != "$prev" ]]; then
      if [[ "$cur" == "failing" ]]; then
        fails_n="$(echo "$hb_body" | jq -r --arg n "$name" '(.sources[$n].fails // 0 | tostring)')"
        emit "SOURCE ${name} failing fails=${fails_n}"
      else
        # Recovered, or first sighting as ok. Spec: "source newly failing, source recovered".
        # First sighting as ok with empty prev: treat as silent baseline (like fresh stays fresh)
        # unless prev was failing. If prev empty and ok → silent.
        if [[ "$prev" == "failing" ]]; then
          emit "SOURCE ${name} ok"
        fi
      fi
    fi
  done
  # Sources that vanished from heartbeat while previously failing → recovered? treat as ok emit.
  for name in "${!prev_src[@]}"; do
    if [[ -z "${src_status[$name]:-}" && "${prev_src[$name]}" == "failing" ]]; then
      emit "SOURCE ${name} ok"
    fi
  done
fi

# --- write state atomically ---
state_tmp="$(mktemp "${state_path}.XXXXXX")"
{
  printf 'overall=%s\n' "$overall"
  # Stable key order for nicer diffs.
  if ((${#src_status[@]} > 0)); then
    for name in $(printf '%s\n' "${!src_status[@]}" | sort); do
      printf 'source:%s=%s\n' "$name" "${src_status[$name]}"
    done
  fi
} >"$state_tmp"
mv -f "$state_tmp" "$state_path"

exit 0
