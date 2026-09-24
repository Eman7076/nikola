# D6.4 — Spock recall / index freshness canary

**Court Contract 001 · Deliverable D6.4** (implements D6 pitch idea 4; preferred before idea 3)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

**Serves:** Spock; window (always-on bell ringer); the house’s “12-day-stale index nobody noticed” failure mode.

**Hard lines:**

- Eli: **`Persistent=true` is never set** on these units.
- Feeds **one-bell** (D6.2) via a **status source file** — not a second watchdog daemon.
- Nikola does not operate window. No Court secrets, no real Spock recall paths hardcoded.
- Canary is safe to evaluate without secrets (mtime only; never opens soul/memory corpora).

---

## What it measures

| Signal | Meaning |
|--------|---------|
| **mtime age** of `signalPath` (file **or** directory) | Seconds since last modification of the Court-chosen freshness stamp |
| Compared to `maxAgeSeconds` | Age ≤ threshold → `FRESH`; age > threshold → `STALE` |
| Path absent / unreadable | → `MISSING` (fail-closed) |

Each tick writes **one line** to `statusOutPath`:

```
FRESH signal=/var/lib/court-signals/spock-index.freshness age=42s max=86400s
STALE signal=/var/lib/court-signals/spock-index.freshness age=90000s max=86400s
MISSING signal=/var/lib/court-signals/spock-index.freshness status=absent max=86400s
```

- Exit **0** on `FRESH`.
- Exit **nonzero** on `STALE` / `MISSING` (oneshot `ActiveState` visible in journal) **after** still writing the status file so one-bell fan-in sees it.

---

## What it does NOT measure

- **Not** semantic recall quality (“did Spock still answer the right thing?”).
- **Not** corpus integrity, hash of soul contents, or embedding drift.
- **Not** an alert sink — routing stays with the existing dead-man watching the one-bell stream.

Wrong `signalPath` → false green. Court must pick a stamp that actually moves when the index/recall surface is refreshed.

---

## What landed in-repo

| Path | Role |
|------|------|
| [`freshness/canary.sh`](./freshness/canary.sh) | Canary: mtime age → status line; exit nonzero on STALE/MISSING |
| [`freshness/module.nix`](./freshness/module.nix) | NixOS module `court.freshnessCanary.*` → oneshot + timer + tmpfiles |
| [`freshness/eval-freshness.nix`](./freshness/eval-freshness.nix) | Cheap eval check (no QEMU) + assert no `Persistent=true` |
| [`freshness/test-canary.sh`](./freshness/test-canary.sh) | Pure script proof (`touch -d`) — fresh / stale / missing / dir |
| [`freshness/check-canary-script.nix`](./freshness/check-canary-script.nix) | Flake check wrapping the script proof |

Flake checks:

- `checks.x86_64-linux.d6-freshness-eval` — module evaluates; timer has `OnBootSec`/`OnUnitActiveSec`; **no** `Persistent=`
- `checks.x86_64-linux.d6-freshness-script` — local script proof (no QEMU)

No full nixosTest in this cut (nested KVM often hangs here; eval + script are the VM-proofable gates). Court may add a nixosTest later on the rig if wanted.

---

## Module options (Court fills real paths)

```nix
imports = [
  /path/to/nikola/d6/freshness/module.nix
  /path/to/nikola/d6/one-bell/module.nix
];

court.freshnessCanary = {
  enable = true;
  # Placeholders — Court replaces with a *non-secret* freshness signal:
  #   - mtime of an index file Court already maintains, OR
  #   - a Court-written stamp file containing only timestamps (no soul text)
  signalPath = "/var/lib/court-signals/spock-index.freshness";
  maxAgeSeconds = 86400; # guess: 1 day; Court tunes
  statusOutPath = "/var/lib/court-signals/freshness.status";
  interval = "15min";
  onBootSec = "2min";
};

court.oneBell = {
  enable = true;
  sourceFiles = [
    # ... other Court signal files ...
    "/var/lib/court-signals/freshness.status" # ← statusOutPath
  ];
  # streamPath / interval / … as in d6/02-one-bell.md
};
```

Default paths under `/var/lib/court-signals/` are **documented placeholders**, not Spock’s real layout. Court owns the truth.

---

## How Court wires signalPath + one-bell

**COURT steps (Nikola does not apply):**

1. Choose a **non-secret** freshness signal whose mtime advances when recall/index is refreshed (index artifact, or a tiny stamp file Court touches/writes with timestamps only).
2. Set `court.freshnessCanary.signalPath` and tune `maxAgeSeconds` (labeled guess in defaults: 86400 s / 1 day).
3. Enable the module; confirm `statusOutPath` is written each tick (`systemctl start court-freshness-canary.service`).
4. Add `statusOutPath` to `court.oneBell.sourceFiles` so the fan-in stream carries `FRESH` / `STALE` / `MISSING` lines.
5. Point the **existing** dead-man at the one-bell stream (already D6.2). Optionally also watch canary unit failure (`ActiveState`) — status file remains the primary fan-in signal.
6. Confirm: `systemctl cat court-freshness-canary.timer` has **no** `Persistent=true`.
7. Deliberate stale proof: `touch -d '30 days ago' "$signalPath"` → status `STALE` → one-bell `OK … line=STALE …` (file present) and/or unit failed; restore with a fresh touch.
8. Do **not** invent a second page/alert daemon for this canary.

---

## Timer shape

`court-freshness-canary.timer` uses:

- `OnBootSec` (default `2min`)
- `OnUnitActiveSec` (option `interval`, default `15min`)

**`Persistent=` is omitted** (never `true`). Same Eli rule as D6.2 one-bell.

---

## Verify

**Nikola VM (2026-09-24):**

```bash
# Script proof (no NixOS):
bash d6/freshness/test-canary.sh

# Eval gate:
nix build -L .#checks.x86_64-linux.d6-freshness-eval

# Script flake check:
nix build -L .#checks.x86_64-linux.d6-freshness-script
```

Expected: fresh→`FRESH` exit 0; old mtime→`STALE` exit ≠0; missing→`MISSING` exit ≠0; eval asserts oneshot + no Persistent.

---

## Labeled guesses

| Claim | Label |
|-------|--------|
| Default `maxAgeSeconds = 86400` (1 day) | **guess** — Court tunes to Spock’s real refresh cadence |
| Default `interval = 15min` | **guess** — coarser than one-bell’s 5min; Court may align |
| Default placeholder paths under `/var/lib/court-signals/` | **placeholder** — not Spock’s real layout |
| Index mtime is a sufficient freshness proxy | **guess** — false if Court refreshes the wrong file; prefer an explicit stamp Court controls |
| Semantic “recall still answers” needs Spock product work | **fact of the pitch** — out of scope for this mtime canary |

---

## Non-goals

- Idea 3 (rig env Nix shell) — separate session.
- Reading or hashing Court soul/memory corpora.
- Replacing Spock’s sentinel or one-bell.
- `Persistent=true` on any unit.
