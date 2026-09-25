# D6.2 — One-bell watcher (external bus heartbeat on controller)

**Court Contract 001 · Deliverable D6.2** (implements D6 pitch idea 2; **revised 2026-09-25**)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

**Serves:** **controller** (was **window** until 2026-09-25); Spock’s ark; Eli’s “watcher of the watcher” ask.

**Hard lines:**

- Eli: **`Persistent=true` is never set** on these units.
- Nikola proposes only — **does not SSH/operate controller, conduit, or rig**. No alert-sink secrets/tokens in the flake.
- Module invents **no** host, key, or heartbeat path — Court supplies `heartbeatCommand`.

---

## What changed (Spock FACT 2026-09-25)

The **one bus is LIVE on the rig** (not controller). Feeder: cron every minute, flock, ~0.7 s. Stream lines: `<YYYY-MM-DD> <HH:MM:SS> <source> <text>`. Heartbeat JSON rewritten atomically each run:

```json
{"feeder_last_run": 1790329620.85,
 "sources": {"igris-note": {"status": "ok", "fails": 0, "last_ok": 1790329620.85, "last_error": ""},
             "igris-log":  {"status": "ok", "fails": 0, "last_ok": 1790329620.85, "last_error": ""}}}
```

`feeder_last_run` = Unix seconds (float ok). `status` = `ok` or `failing`.

Spock’s session tails the stream and flags feeder stale after 180 s — but if the **rig dies**, that watch dies with it. **D6.2’s real job:** watcher of the watcher on **controller**, noticing from OUTSIDE.

**Old D6.2** (local file fan-in → append-only stream for a dead-man) is **superseded**. Archived at [`one-bell/archive/fan-in.sh.superseded-2026-09-25`](./one-bell/archive/fan-in.sh.superseded-2026-09-25). D6.4 freshness canary’s “add status file to `sourceFiles`” wiring no longer applies to one-bell; Court can still run the canary status file as its own signal.

---

## What landed in-repo

| Path | Role |
|------|------|
| [`one-bell/watch.sh`](./one-bell/watch.sh) | External heartbeat watcher: change-only log lines |
| [`one-bell/module.nix`](./one-bell/module.nix) | NixOS module `court.oneBell.*` → oneshot + timer + tmpfiles |
| [`one-bell/test-watch.sh`](./one-bell/test-watch.sh) | Pure script proof (no QEMU) |
| [`one-bell/check-watch-script.nix`](./one-bell/check-watch-script.nix) | Flake check wrapping the pure proof |
| [`one-bell/eval-one-bell.nix`](./one-bell/eval-one-bell.nix) | Cheap eval check + assert no `Persistent=true` / Type=oneshot |
| [`one-bell/nixos-test.nix`](./one-bell/nixos-test.nix) | Full nixosTest with fake heartbeatCommand |

Flake checks (same names kept for wiring continuity):

- `checks.x86_64-linux.d6-one-bell-script` — pure script (run on Nikola’s VM)
- `checks.x86_64-linux.d6-one-bell-eval` — eval (run on Nikola’s VM)
- `checks.x86_64-linux.d6-one-bell` — nixosTest; **re-run on the Court rig** if nested KVM dies here

---

## Timer shape (why OnBootSec + OnUnitActiveSec)

`court-one-bell.timer` uses:

- `OnBootSec` (default **`30s` GUESS**) — first tick soon after boot
- `OnUnitActiveSec` (option `interval`, default **`2min` GUESS** — Spock: every ~2 min) — re-arm after each oneshot

**`Persistent=` is omitted** (never `true`).

**Why not OnCalendar + Persistent=true:** after suspend/AFK, Persistent would fire a catch-up burst. Eli forbids Persistent. Staleness is measured from `feeder_last_run` in the heartbeat JSON, not from a Persistent backlog.

---

## Module options (Court fills real command)

```nix
imports = [ /path/to/nikola/d6/one-bell/module.nix ];

court.oneBell = {
  enable = true;

  # REQUIRED when enable — Court supplies; module invents no host/key/path.
  # Example shape only (not a real Court string):
  heartbeatCommand = "ssh court-rig cat /var/lib/…/heartbeat.json";

  staleAfterSec = 300;       # GUESS — Spock: “say 5 min”
  sourceFailingRuns = 3;     # GUESS — align feeder three-run HEALTH
  interval = "2min";         # GUESS — Spock: every ~2 min
  onBootSec = "30s";         # GUESS
  logPath = "/var/lib/court-one-bell/watch.log";
  statePath = "/var/lib/court-one-bell/watch.state";

  # Optional. Empty = log only. Court owns the alert sink; no tokens here.
  alertCommand = "";
  # e.g. alertCommand = "/var/lib/court/bin/one-bell-alert";  # Court-written
};
```

### What Court must supply

| Option | Who | Notes |
|--------|-----|--------|
| `heartbeatCommand` | **Court** | Shell command printing heartbeat JSON on stdout (ssh or other). |
| `alertCommand` | **Court** (optional) | If set, run once per change with `COURT_ONE_BELL_EVENT` = log line. Nikola does not write this. |

No ntfy tokens, SMTP creds, or other alert secrets belong in this flake.

---

## Watcher logic (each tick)

1. Run `heartbeatCommand`. Nonzero / empty / invalid JSON → overall **UNREACHABLE**.
2. Else parse `feeder_last_run`. If `now - feeder_last_run > staleAfterSec` → **STALE**; else **FRESH**.
3. For each `sources` entry: `status == "failing"` **and** `fails >= sourceFailingRuns` → that source is failing.
4. Compare to `statePath`; **emit a line ONLY on CHANGE**. Fresh that stays fresh = **silent**. Stale that stays stale = silent after first line.
5. Append change lines to `logPath`. If `alertCommand` non-empty, run it once per emitted change.

### Log format (Nikola proposal)

```
YYYY-MM-DD HH:MM:SS court-one-bell FEEDER stale age=361s
YYYY-MM-DD HH:MM:SS court-one-bell FEEDER fresh
YYYY-MM-DD HH:MM:SS court-one-bell FEEDER unreachable: cmd_exit=1
YYYY-MM-DD HH:MM:SS court-one-bell SOURCE igris-note failing fails=3
YYYY-MM-DD HH:MM:SS court-one-bell SOURCE igris-note ok
```

---

## GUESS thresholds (Nikola proposal — Court may retune)

| Knob | Default | Why labeled GUESS |
|------|---------|-------------------|
| `interval` | `2min` | Spock said every ~2 min |
| `onBootSec` | `30s` | First tick soon after boot |
| `staleAfterSec` | `300` | Spock said “say 5 min” (outside watch; Spock’s on-rig tail uses 180 s) |
| `sourceFailingRuns` | `3` | Align feeder’s three-run HEALTH |

---

## How Court applies (Nikola does not apply)

1. Enable `court.oneBell` on **controller** with a real `heartbeatCommand` that can reach the rig heartbeat JSON (Court owns mesh/ssh).
2. Optionally set `alertCommand` to a Court-owned hook (no secrets in this flake).
3. Confirm: forced `systemctl start court-one-bell.service` with a fresh heartbeat → silent log; deliberate stale `feeder_last_run` → one `FEEDER stale` line; second tick still stale → silent; kill reachability → `FEEDER unreachable`.
4. Confirm: `systemctl cat court-one-bell.timer` has **no** `Persistent=true`.
5. Do **not** treat this as a second on-rig dead-man — it is the outside watch when the rig (and Spock’s session) is gone.

---

## Verify

```bash
# Pure script (expected green on Nikola VM):
bash d6/one-bell/test-watch.sh
# or:
nix build -L .#checks.x86_64-linux.d6-one-bell-script

# Eval (expected green on Nikola VM):
nix build -L .#checks.x86_64-linux.d6-one-bell-eval

# Full nixosTest — re-run on Court rig if nested KVM hangs here:
nix build -L .#checks.x86_64-linux.d6-one-bell
```

Do **not** wait hours on hung QEMU on this VM.

---

## Still waits (not this deliverable)

- **C002.1** rehearsal (Ventoy/Porteus stick) — Court hands
- **D6.1** controller LUKS live apply — Court hands; Nikola does not operate controller

---

## Non-goals

- Writing the alert sink / tokens / phone-home.
- Inventing ssh hosts, keys, or heartbeat paths.
- Replacing Spock’s on-rig stream tail (this complements it from outside).
- Operating controller / conduit / rig.
