# D6.2.1 — One-bell watcher (external bus heartbeat on controller)

**Court Contract 001 · Deliverable D6.2** (implements D6 pitch idea 2; **revised 2026-09-25**, **D6.2.1 Spock review fixes**)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

**Serves:** **controller** (was **window** until 2026-09-25); Spock’s ark; Eli’s “watcher of the watcher” ask.

**Hard lines:**

- Eli: **`Persistent=true` is never set** on these units.
- Nikola proposes only — **does not SSH/operate controller, conduit, or rig**. No alert-sink secrets/tokens in the flake.
- Module invents **no** host, key, or heartbeat path — Court supplies `heartbeatCommand`.
- Watcher runs as dedicated system user (**not root**); Court gives that user its own ssh identity.

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

### D6.2.1 (Spock blocking review on 7b93682)

| Fix | Detail |
|-----|--------|
| Heartbeat timeout | `heartbeatTimeoutSec` (**GUESS default 30**); wrap cmd in coreutils `timeout`; exit **124** → UNREACHABLE detail **timeout** (change-only). Same bound on `alertCommand`. |
| systemd TimeoutStartSec | **GUESS: `heartbeatTimeoutSec + 15`** so a wedged oneshot cannot block the timer forever. |
| Dedicated user | Option `user` default **`court-one-bell`**; `users.users` + group; `/var/lib/court-one-bell` owned by that user; service `User=` / `Group=`. Not root. |
| Clock skew | If age `< -clockSkewSec` (**GUESS default 60**), change-only `CLOCK skew <n>s` / leave → `CLOCK ok`. Documented GUESS. |
| Leave as-is | Source failing = `status=="failing"` AND `fails >= 3` double-gate with feeder (Spock note). |

---

## What landed in-repo

| Path | Role |
|------|------|
| [`one-bell/watch.sh`](./one-bell/watch.sh) | External heartbeat watcher: change-only log lines + timeout + skew |
| [`one-bell/module.nix`](./one-bell/module.nix) | NixOS module `court.oneBell.*` → oneshot + timer + user + tmpfiles |
| [`one-bell/test-watch.sh`](./one-bell/test-watch.sh) | Pure script proof (no QEMU) |
| [`one-bell/check-watch-script.nix`](./one-bell/check-watch-script.nix) | Flake check wrapping the pure proof |
| [`one-bell/eval-one-bell.nix`](./one-bell/eval-one-bell.nix) | Cheap eval check + assert no `Persistent=true` / Type=oneshot / User / TimeoutStartSec |
| [`one-bell/nixos-test.nix`](./one-bell/nixos-test.nix) | Full nixosTest with fake heartbeatCommand |
| [`one-bell/PROOF.md`](./one-bell/PROOF.md) | Captured proof outputs for Spock (script / eval / nixosTest attempt) |

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

**Why TimeoutStartSec:** without a bound, a hung `ssh`/`cat` keeps the oneshot “activating” forever → timer cannot re-fire → no UNREACHABLE. `timeout(1)` on the heartbeat (and alert) plus `TimeoutStartSec = heartbeatTimeoutSec + 15` (GUESS) closes that hole.

---

## Module options (Court fills real command)

```nix
imports = [ /path/to/nikola/d6/one-bell/module.nix ];

court.oneBell = {
  enable = true;

  # REQUIRED when enable — Court supplies; module invents no host/key/path.
  # Example shape only (not a real Court string):
  heartbeatCommand = "ssh court-rig cat /var/lib/…/heartbeat.json";

  heartbeatTimeoutSec = 30;  # GUESS — hung ssh/disk → UNREACHABLE timeout
  staleAfterSec = 300;       # GUESS — Spock: “say 5 min”
  sourceFailingRuns = 3;     # GUESS — align feeder three-run HEALTH
  clockSkewSec = 60;         # GUESS — age < -60 → CLOCK skew line
  interval = "2min";         # GUESS — Spock: every ~2 min
  onBootSec = "30s";         # GUESS
  user = "court-one-bell";   # dedicated system user (not root)
  logPath = "/var/lib/court-one-bell/watch.log";
  statePath = "/var/lib/court-one-bell/watch.state";

  # Optional. Empty = log only. Court owns the alert sink; no tokens here.
  # Also bounded by heartbeatTimeoutSec.
  alertCommand = "";
  # e.g. alertCommand = "/var/lib/court/bin/one-bell-alert";  # Court-written
};
```

### What Court must supply

| Option | Who | Notes |
|--------|-----|--------|
| `heartbeatCommand` | **Court** | Shell command printing heartbeat JSON on stdout (ssh or other). |
| ssh identity for `user` | **Court** | Dedicated user needs its own key/mesh identity — watcher must not need root. |
| `alertCommand` | **Court** (optional) | If set, run once per change with `COURT_ONE_BELL_EVENT` = log line. Nikola does not write this. |

No ntfy tokens, SMTP creds, or other alert secrets belong in this flake.

---

## Watcher logic (each tick)

1. Run `heartbeatCommand` under coreutils `timeout heartbeatTimeoutSec`. Exit **124** / nonzero / empty / invalid JSON → overall **UNREACHABLE** (124 → detail **timeout**).
2. Else parse `feeder_last_run`. If `now - feeder_last_run > staleAfterSec` → **STALE**; else **FRESH**.
3. If age `< -clockSkewSec` (**GUESS 60**): set clock-skew state; age still clamped to 0 for STALE/FRESH.
4. For each `sources` entry: `status == "failing"` **and** `fails >= sourceFailingRuns` → that source is failing (double-gate; leave as-is).
5. Compare to `statePath`; **emit a line ONLY on CHANGE**. Fresh that stays fresh = **silent**. Stale that stays stale = silent after first line. Clock skew enter/leave likewise change-only.
6. Append change lines to `logPath`. If `alertCommand` non-empty, run it once per emitted change (also under the same timeout).

### Log format (Nikola proposal)

```
YYYY-MM-DD HH:MM:SS court-one-bell FEEDER stale age=361s
YYYY-MM-DD HH:MM:SS court-one-bell FEEDER fresh
YYYY-MM-DD HH:MM:SS court-one-bell FEEDER unreachable: cmd_exit=1
YYYY-MM-DD HH:MM:SS court-one-bell FEEDER unreachable: timeout
YYYY-MM-DD HH:MM:SS court-one-bell SOURCE igris-note failing fails=3
YYYY-MM-DD HH:MM:SS court-one-bell SOURCE igris-note ok
YYYY-MM-DD HH:MM:SS court-one-bell CLOCK skew 90s
YYYY-MM-DD HH:MM:SS court-one-bell CLOCK ok
```

---

## GUESS thresholds (Nikola proposal — Court may retune)

| Knob | Default | Why labeled GUESS |
|------|---------|-------------------|
| `interval` | `2min` | Spock said every ~2 min |
| `onBootSec` | `30s` | First tick soon after boot |
| `staleAfterSec` | `300` | Spock said “say 5 min” (outside watch; Spock’s on-rig tail uses 180 s) |
| `sourceFailingRuns` | `3` | Align feeder’s three-run HEALTH |
| `heartbeatTimeoutSec` | `30` | Spock D6.2.1 — bound hung ssh/disk |
| `TimeoutStartSec` | `heartbeatTimeoutSec + 15` | Slightly above timeout(1); GUESS +15 |
| `clockSkewSec` | `60` | age `< -60` → CLOCK skew instead of silent clamp |
| `user` | `court-one-bell` | Dedicated non-root system user |

---

## How Court applies (Nikola does not apply)

1. Enable `court.oneBell` on **controller** with a real `heartbeatCommand` that can reach the rig heartbeat JSON (Court owns mesh/ssh). Give `court-one-bell` (or configured `user`) its own ssh identity.
2. Optionally set `alertCommand` to a Court-owned hook (no secrets in this flake).
3. Confirm: forced `systemctl start court-one-bell.service` with a fresh heartbeat → silent log; deliberate stale `feeder_last_run` → one `FEEDER stale` line; second tick still stale → silent; kill reachability → `FEEDER unreachable`; hung command past `heartbeatTimeoutSec` → `FEEDER unreachable: timeout` and oneshot **exits**.
4. Confirm: `systemctl cat court-one-bell.timer` has **no** `Persistent=true`; service has `User=court-one-bell` and `TimeoutStartSec=45` (with defaults).
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

Do **not** wait hours on hung QEMU on this VM. See [`one-bell/PROOF.md`](./one-bell/PROOF.md) for captured outputs.

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
