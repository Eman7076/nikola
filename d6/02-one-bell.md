# D6.2 — One-bell watcher (fan-in for the existing dead-man)

**Court Contract 001 · Deliverable D6.2** (implements D6 pitch idea 2)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

**Serves:** window (conductor); Spock’s ark / **existing** sentinel·dead-man; Eli’s “one stream” ask.

**Hard lines:**

- Eli: **`Persistent=true` is never set** on these units.
- Spock: this **feeds** the existing dead-man/sentinel — it does **not** invent a second independent watchdog daemon or alert sink.
- Nikola does not operate window. No alert-sink secrets in the flake.

---

## What landed in-repo

| Path | Role |
|------|------|
| [`one-bell/fan-in.sh`](./one-bell/fan-in.sh) | Fan-in script: source files → one stamped stream block; missing source → `MISSING … status=absent` |
| [`one-bell/module.nix`](./one-bell/module.nix) | NixOS module `court.oneBell.*` → oneshot service + timer + tmpfiles |
| [`one-bell/eval-one-bell.nix`](./one-bell/eval-one-bell.nix) | Cheap eval check (no QEMU) + assert no `Persistent=true` |
| [`one-bell/nixos-test.nix`](./one-bell/nixos-test.nix) | Full nixosTest with toy sources |

Flake checks:

- `checks.x86_64-linux.d6-one-bell-eval` — run on Nikola’s VM
- `checks.x86_64-linux.d6-one-bell` — nixosTest; **re-run on the Court rig** if nested KVM dies here (same pattern as D2.2)

---

## Timer shape (why OnBootSec + OnUnitActiveSec)

`court-one-bell.timer` uses:

- `OnBootSec` (default `1min`) — first tick soon after boot
- `OnUnitActiveSec` (option `interval`, default `5min`) — re-arm after each oneshot

**`Persistent=` is omitted** (never `true`).  

**Why not OnCalendar + Persistent=true:** after suspend/AFK, Persistent would fire a catch-up burst. Eli forbids Persistent. The dead-man should treat **stream staleness** (mtime / age of last `END` line) as the missed-tick signal instead.

---

## Module options (Court fills real paths)

```nix
imports = [ /path/to/nikola/d6/one-bell/module.nix ];

court.oneBell = {
  enable = true;
  sourceFiles = [
    # Court-maintained *files* only — examples, not prescriptions:
    # "/var/lib/court-signals/mesh.status"
    # "/var/lib/court-signals/disk.free"
    # "/var/lib/court-signals/organ.canary"
  ];
  streamPath = "/var/lib/court-one-bell/bell.log"; # dead-man watches this
  interval = "5min";
  onBootSec = "1min";
  debounceSec = 0; # optional: skip identical core payloads within N seconds
};
```

No ntfy tokens, SMTP creds, or other alert secrets belong here. Alert routing stays with the **existing** dead-man Court already trusts (D4 #2 Spock note).

---

## Stream format (measurable)

Each oneshot appends a block:

```
2026-09-24T23:00:00Z BEGIN ok=1 missing=1
OK source=/var/lib/court-signals/mesh.status line=handshake_age=42
MISSING source=/var/lib/court-signals/disk.free status=absent
2026-09-24T23:00:00Z END ok=1 missing=1
```

- Present readable file → `OK … line=…` (newlines collapsed).
- Missing/unreadable → `MISSING … status=absent` (**fail-closed**; never silent skip).
- Timestamps are UTC ISO-8601 (`Z`). Court converts for humans.

---

## How Court points the existing dead-man at the stream

**COURT steps (Nikola does not apply):**

1. Enable `court.oneBell` on window with the real source file paths Court will keep fresh (mesh handshake age writers, free-eMMC drop, organ canary, etc. — Court owns those writers; this module only reads files).
2. Point the **existing** sentinel/dead-man at `streamPath` (default `/var/lib/court-one-bell/bell.log`), using whatever watch primitive Court already uses (tail, inotify, mtime age, “last END older than N”, count of `MISSING`, etc.).
3. Confirm: one forced `systemctl start court-one-bell.service` produces a block; dead-man reacts to a deliberate `MISSING` (rename a source) and to stream staleness (stop the timer briefly).
4. Confirm: `systemctl cat court-one-bell.timer` has **no** `Persistent=true`.
5. Do **not** add a second page/alert daemon “because the bell exists.”

---

## Verify

**Nikola VM (2026-09-24):**
- `nix build .#checks.x86_64-linux.d6-one-bell-eval` — **passed** (toplevel builds; generated timer has `OnBootSec`/`OnUnitActiveSec`, **no** `Persistent=` assignment; service `Type=oneshot`).
- Local `fan-in.sh` smoke — present→`OK`, absent→`MISSING` (fail-closed); debounce skips identical payload within window.
- `nix build .#checks.x86_64-linux.d6-one-bell` — driver **typecheck + lint passed**; QEMU run **hung** at `machine: starting vm` (same nested-KVM class as D2.2). Do **not** wait the 3600 s timeout.

```bash
# VM (eval — expected green here):
nix build -L .#checks.x86_64-linux.d6-one-bell-eval

# Court rig (full nixosTest — re-run here):
nix build -L .#checks.x86_64-linux.d6-one-bell
```

---

## Non-goals

- Idea 4 (Spock recall freshness canary) — **landed as D6.4** ([`04-freshness-canary.md`](./04-freshness-canary.md)); Court adds its `statusOutPath` to `sourceFiles`.
- Alert sink configuration, secrets, or phone-home.
- Replacing Spock’s sentinel.
