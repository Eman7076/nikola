# D6.2.1 proof log (Spock)

**Author:** Nikola · **Host:** Nikola Grok Bot VM (nested KVM often hostile) · **Propose-only** (no Court host ops)

Timestamps below are **America/Chicago (CDT, UTC-5)** unless a tool printed UTC.

## GUESS numbers in this revision

| Knob | GUESS value |
|------|-------------|
| `heartbeatTimeoutSec` | **30** |
| `TimeoutStartSec` | **heartbeatTimeoutSec + 15** (= 45 with default) |
| `clockSkewSec` | **60** (age < -60 → CLOCK skew) |
| `user` | `court-one-bell` |
| (unchanged) `staleAfterSec` | 300 |
| (unchanged) `sourceFailingRuns` | 3 |
| (unchanged) `interval` / `onBootSec` | `2min` / `30s` |

## 1. Pure script — `bash d6/one-bell/test-watch.sh`

Ran **2026-09-25 15:21:21 CDT**. Full stdout also in `proof/test-watch.out`.

```
ok fresh stays silent (two ticks)
court-one-bell: 2026-09-25 15:21:21 court-one-bell FEEDER stale age=360s
ok stale once then silent
court-one-bell: 2026-09-25 15:21:21 court-one-bell FEEDER stale age=360s
court-one-bell: 2026-09-25 15:21:21 court-one-bell FEEDER fresh
ok recovery (stale→fresh) once
court-one-bell: 2026-09-25 15:21:21 court-one-bell FEEDER unreachable: cmd_exit=1
court-one-bell: 2026-09-25 15:21:21 court-one-bell FEEDER fresh
ok unreachable once (+ recovery)
court-one-bell: 2026-09-25 15:21:21 court-one-bell SOURCE igris-note failing fails=3
court-one-bell: 2026-09-25 15:21:21 court-one-bell SOURCE igris-note ok
ok failing source once (+ recovery)
court-one-bell: 2026-09-25 15:21:21 court-one-bell FEEDER unreachable: invalid_json
ok invalid JSON → unreachable
court-one-bell: 2026-09-25 15:21:21 court-one-bell FEEDER unreachable: timeout
ok heartbeat timeout → one unreachable (timeout), script exits
court-one-bell: 2026-09-25 15:21:25 court-one-bell CLOCK skew 86s
court-one-bell: 2026-09-25 15:21:25 court-one-bell CLOCK ok
ok clock skew enter/leave (change-only)
d6-one-bell watch script proof: all cases passed
```

**FACT:** timeout case (`sleep 60` + timeout **2**) produced **one** `FEEDER unreachable: timeout` line and the script **exited** (no hang).

## 2. Flake check — `nix build -L .#checks.x86_64-linux.d6-one-bell-script`

Ran **2026-09-25 15:21:39–15:21:45 CDT**. EXIT 0. Full log: `proof/nix-script.out`.

Same cases passed inside the derivation (nix build sandbox clock showed ~20:21 UTC on log lines).

## 3. Flake check — `nix build -L .#checks.x86_64-linux.d6-one-bell-eval`

Ran **2026-09-25 15:21:48–15:21:56 CDT**. EXIT 0. Full log: `proof/nix-eval.out`.

Asserts: no `Persistent=true`, `Type=oneshot`, interval/onBootSec, **`User=court-one-bell`**, **`TimeoutStartSec=45`**, env `COURT_ONE_BELL_HEARTBEAT_TIMEOUT_SEC=30`, user exists.

## 4. Flake check — `nix build -L .#checks.x86_64-linux.d6-one-bell` (nixosTest)

Attempted **2026-09-25 15:22:00 CDT** with wall-clock **`timeout 150s`** (Spock: do not wait 3600s). Full log: `proof/nix-nixosTest.out`.

**FACT: hung / did not finish within 150s on this nested-KVM-hostile VM.**

What did run before kill:

- Evaluated/built machine system, test driver, started vlan
- Reached: `machine: starting vm` → `mke2fs 1.47.2`
- Then wall timeout fired → `error: interrupted by the user` → EXIT **124**
- Message recorded: *nixosTest did not complete within 150s wall clock (likely nested KVM hang or slow VM start). Killed; do not wait 3600s.*

**Re-run on Court rig** (virt that can boot the VM):

```bash
nix build -L .#checks.x86_64-linux.d6-one-bell
```

Script + eval are green on Nikola’s VM; that is the proof Spock asked for when nixosTest cannot run here.
