#!/usr/bin/env bash
# C002.1 — pure stick-check proof (no QEMU, no network).
# Builds a fake stick from manifest.example.txt; asserts pass + missing-file fail.
# Author: Nikola (Court Contract 002)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CHECK="${ROOT}/check-stick.sh"
EXAMPLE="${ROOT}/manifest.example.txt"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -x "$CHECK" || -f "$CHECK" ]] || fail "check-stick.sh missing"
[[ -s "$EXAMPLE" ]] || fail "manifest.example.txt missing"

# --- Case 1: complete fake stick from example → exit 0 ---
STICK="${WORKDIR}/stick-ok"
mkdir -p "$STICK"

# Create every path listed in the example (files non-empty; dirs exist).
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%$'\r'}"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  [[ "$line" == /* || "$line" == *..* ]] && fail "example has unsafe path: $line"

  target="$STICK/$line"
  # Heuristic: ISO / .txt / .sh / FLAKE_PIN / manifest → files; else if ends without
  # extension and no slash-file pattern from example, treat known dirs.
  case "$line" in
    */ | ISOs | court-recovery | court-recovery/backups)
      mkdir -p "$target"
      ;;
    *.iso | *.txt | *.sh | */FLAKE_PIN.txt | */manifest.txt | */README.txt | */check-stick.sh)
      mkdir -p "$(dirname "$target")"
      # Placeholder non-empty content (not real ISOs / souls)
      printf 'placeholder for %s\n' "$line" >"$target"
      ;;
    *)
      # Default: if path has a final component with a dot, file; else directory
      base="$(basename "$line")"
      if [[ "$base" == *.* ]]; then
        mkdir -p "$(dirname "$target")"
        printf 'placeholder for %s\n' "$line" >"$target"
      else
        mkdir -p "$target"
      fi
      ;;
  esac
done <"$EXAMPLE"

# Manifest on the stick must list the same relative paths; copy example into place.
mkdir -p "$STICK/court-recovery"
cp "$EXAMPLE" "$STICK/court-recovery/manifest.txt"
# Ensure check script path exists as listed
cp "$CHECK" "$STICK/court-recovery/check-stick.sh"
chmod +x "$STICK/court-recovery/check-stick.sh"

# Valid FLAKE_PIN (40 hex)
cat >"$STICK/court-recovery/FLAKE_PIN.txt" <<'PIN'
repo=Eman7076/nikola
rev=0123456789abcdef0123456789abcdef01234567
date=2026-09-24
recorded_by=Nikola-test
notes=fake pin for c002 stick check only
PIN

# Re-touch ISO placeholders if example listed them (already created above).
set +e
out="$(bash "$CHECK" "$STICK" 2>&1)"
rc=$?
set -e
echo "$out"
[[ "$rc" -eq 0 ]] || fail "complete stick: expected exit 0, got $rc"
echo "$out" | grep -q '^summary: ok=' || fail "complete stick: missing summary"
echo "ok complete-stick → exit 0"

# --- Case 2: missing required file → exit nonzero ---
STICK2="${WORKDIR}/stick-missing"
cp -a "$STICK" "$STICK2"
# Remove one listed ISO so checker fails
rm -f "$STICK2/ISOs/PLACEHOLDER-porteus-or-live.iso"
set +e
out2="$(bash "$CHECK" "$STICK2" 2>&1)"
rc2=$?
set -e
echo "$out2"
[[ "$rc2" -ne 0 ]] || fail "missing-file: expected nonzero exit, got 0"
echo "$out2" | grep -q 'MISSING' || fail "missing-file: expected MISSING line"
echo "ok missing-file → exit $rc2"

# --- Case 3: bad FLAKE_PIN rev format → fail ---
STICK3="${WORKDIR}/stick-badpin"
cp -a "$STICK" "$STICK3"
cat >"$STICK3/court-recovery/FLAKE_PIN.txt" <<'BAD'
repo=Eman7076/nikola
rev=not-a-real-sha
date=2026-09-24
recorded_by=Nikola-test
BAD
set +e
out3="$(bash "$CHECK" "$STICK3" 2>&1)"
rc3=$?
set -e
echo "$out3"
[[ "$rc3" -ne 0 ]] || fail "bad-pin: expected nonzero exit, got 0"
echo "$out3" | grep -qi 'FLAKE_PIN' || fail "bad-pin: expected FLAKE_PIN complaint"
echo "ok bad-flake-pin → exit $rc3"

# --- Case 4: no args → usage exit 2 ---
set +e
bash "$CHECK" >/dev/null 2>&1
rc4=$?
set -e
[[ "$rc4" -eq 2 ]] || fail "usage: expected exit 2, got $rc4"
echo "ok usage → exit 2"

echo "c002 stick-check proof: all cases passed"
