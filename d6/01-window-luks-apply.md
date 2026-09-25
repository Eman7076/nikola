# D6.1 — Controller LUKS migration runbook (Court-owned apply)

**Court Contract 001 · Deliverable D6.1** (implements D6 pitch idea 1)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli  
**Applies to:** **controller** (NixOS Chromebook fleet controller; flake attr `.#controller`)  
**Name history (FACT):** Called **window** until **2026-09-25** (Eli). Old notes that say “window” mean this host. Fleet flake: `nixosConfigurations.controller`, `hosts/controller/`, `networking.hostName = "controller"`.  
**Hard line:** Nikola drafts this checklist only. **Nikola does not operate controller.** Court runs every command below on Court metal. No claim that Nikola applied LUKS, unlocked, or rejoined mesh.

**Accepted upstream (cite these, do not re-invent):**

| Path | Role |
|------|------|
| [`d2/disko.nix`](../d2/disko.nix) | Fail-closed GPT + **512M ESP** + LUKS2 (argon2id) + btrfs subvols `/`, `/nix`, `/home` |
| [`d2/luks.nix`](../d2/luks.nix) | Additive initrd.systemd + TPM module list + cryptsetup/tpm2-tools + GC (does **not** own `boot.loader.*` / `zramSwap`) |
| [`d2/flake-fragment.nix`](../d2/flake-fragment.nix) | Court flake wiring sketch: `disko` input + `disko.nixosModules.disko` + imports |
| [`d2/REINSTALL.md`](../d2/REINSTALL.md) | Keyboard steps for `.#controller` (format → install → enroll; older text may still say `.#window`) |
| [`d2/README.md`](../d2/README.md) | D2.2.1 pin note: disko **v1.12.0**; nested-KVM limits on Nikola’s VM |
| [`d2/nixos-test.nix`](../d2/nixos-test.nix) | Passphrase LUKS boot test (no Cr50) — `checks…d2-luks-passphrase` |
| [`d2/nixos-test-disko.nix`](../d2/nixos-test-disko.nix) + [`d2/disko-layout-test.nix`](../d2/disko-layout-test.nix) | Layout test GPT+ESP+LUKS2+btrfs — `checks…d2-disko-layout` |
| [`d3/`](../d3/) | WireGuard mesh (rejoin after unlock) — Court owns rollout |

**Controller facts (from D4 / D6 pitch unless marked guess):** ~28.5 GB eMMC; currently unencrypted; PCRs 0–7 all-zero on Cr50 → **passphrase is the disk lock**; **do not claim TPM unlock** for trust. Threat model = lost/stolen **at rest**.

**Parachute (not a substitute for encryption):** pair this apply with a rehearsed Porteus/Ventoy recovery path — **Contract 002 D1** [`c002/01-window-recovery.md`](../c002/01-window-recovery.md) (implements D6 pitch **idea 10**). Recovery media is the parachute; LUKS is the harness. Do not treat idea 10 as optional comfort after a failed apply — rehearse **before** step 5 / §4 if the stick is not already proven once.

---

## 0. Ownership / labels

| Label | Meaning |
|-------|---------|
| **FACT** | Measured or already accepted in-repo |
| **GUESS** | Nikola’s estimate — Court must verify on controller |
| **COURT** | Human at keyboard on controller / recovery stick |
| **NIKOLA** | Text/Nix in this repo only — never executed against controller by Nikola |

---

## 1. Pre-flight (COURT) — backup before any destructive step

### 1.1 Irreplaceable vs replaceable

- **FACT (rig):** Court irreplaceable data class is ~**375 MB** souls/dbs on **novacourt**. That number is a **rig** fact, not a controller inventory.
- **For controller (COURT):** inventory what lives only on the Chromebook and is not on the rig. Typical classes (verify, do not assume sizes):
  - Court flake **pins** / lockfile copy Court actually boots (`flake.lock`, host modules Court did not upstream)
  - WireGuard **public** material pointers (pubkeys, endpoint strings, peer inventory) — **never** private key bytes in backup examples or git
  - Non-secret configs Court would hate to re-type (hostname notes, firewall toggles, mesh address reminders)
  - Anything under `/home` Court marks irreplaceable after a mental pass

### 1.2 Backup checklist (COURT)

- [ ] Copy controller / fleet flake pin + lock (or the stick fleet-flake tarball) to an **offline** medium Court controls (USB that does **not** travel in the same bag as the Chromebook — GUESS: matches D4 #9 threat note).
- [ ] Record `wg show` **public** peer lines / Court peer inventory pointers (pubs + endpoints only). Private key files: Court backs them up under Court’s existing secret custody — **do not paste key material into this runbook or the flake**.
- [ ] `lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,FSTYPE` and `ls -l /dev/disk/by-id/` captured to the backup medium (needed to fill `disko.nix` by-id).
- [ ] Confirm Porteus/Ventoy stick is bootable on **this** Chromebook once (COURT rehearsal per [`c002/01-window-recovery.md`](../c002/01-window-recovery.md)). If not rehearsed, **stop** and finish Contract 002 D1 dry-run first (GUESS: botched 28.5 GB apply without USB recovery costs a travel week — D6 pitch).
- [ ] Free-space target after backup staging: GUESS **≥4–6 GB free** before format (D4 #5 band); measure with `df -h` on live root and installer environment.

### 1.3 Secrets policy

- No passphrases, recovery keys, WireGuard private keys, or age identities in git or in markdown examples.
- D2 nixosTests use throwaway TEST-ONLY passphrases inside the VM only (`d2/README.md`).

---

## 2. Pre-flight — verify free space + layout pin (COURT)

```bash
# On live controller (before installer), record:
df -h /
df -h /boot 2>/dev/null || true
lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

- [ ] Confirm eMMC capacity ~28.5 GB class (FACT from D4; re-measure).
- [ ] Confirm **by-id** symlink for the internal eMMC. **FACT:** Court eMMC has shown up as **mmcblk1**, not mmcblk0 — never default to `/dev/mmcblk0` (`d2/disko.nix`, `d2/REINSTALL.md`).
- [ ] Confirm Court flake will use disko **v1.12.0** (or the pin Court already accepted with D2.2.1). Nikola’s contractor flake pins:
  `git+https://github.com/nix-community/disko.git?ref=refs/tags/v1.12.0&rev=ff442f5d1425feb86344c028298548024f21256d`
  (see top-level `flake.nix`). Court may vendor the same tag in the controller / fleet flake.

### ESP / generation budget (FACT from D2)

- ESP size in [`d2/disko.nix`](../d2/disko.nix): **`size = "512M"`** (512 MiB).
- Court `boot.loader.systemd-boot.configurationLimit = 10` — Nikola does **not** override to 5 (`d2/luks.nix`, `d2/REINSTALL.md` § ESP note).
- If generations fill `/boot` after apply: lower `configurationLimit` **or** grow ESP in a later disko revision — **change them together**.

---

## 3. Merge accepted D2 modules into the Court controller flake (COURT)

Follow [`d2/flake-fragment.nix`](../d2/flake-fragment.nix) and [`d2/REINSTALL.md`](../d2/REINSTALL.md) §0:

- [ ] Add `disko` input (prefer **v1.12.0** tag matching D2.2.1).
- [ ] Import `disko.nixosModules.disko`.
- [ ] Import vendored or path-linked [`d2/disko.nix`](../d2/disko.nix) and [`d2/luks.nix`](../d2/luks.nix).
- [ ] Replace placeholder  
  `device = "/dev/disk/by-id/REPLACE-WITH-CONTROLLER-EMMC-BY-ID";`  
  with the real by-id from step 2.
- [ ] **Remove** `fileSystems."/"` and `fileSystems."/boot"` from `hardware-configuration.nix` (disko owns those). Keep other hw bits.
- [ ] Do **not** redeclare `boot.loader.*` or `zramSwap` inside `luks.nix` — those stay in the Court host flake (`d2/luks.nix` header).
- [ ] Keep `askPassword = true` (interactive passphrase at format). `passwordFile` is non-interactive alternative only — never commit a password file.

### Safe eval before format

```bash
nix flake check '.#controller'   # or: nixos-rebuild dry-activate --flake '.#controller'
```

Expect failure until by-id is real and conflicting `fileSystems` are removed (`d2/REINSTALL.md` §1).

### Optional: re-prove layout checks on the rig (COURT)

Nikola’s VM cannot run nested QEMU reliably. On the **rig** (working virt):

```bash
nix build -L .#checks.x86_64-linux.d2-luks-passphrase
nix build -L .#checks.x86_64-linux.d2-disko-layout
```

(Paths assume Court’s checkout wires the same checks; otherwise run against this contractor flake on the rig.)

---

## 4. Apply path (DESTRUCTIVE — COURT only)

**Stop if backups or Ventoy rehearsal are incomplete.**

Boot installer / maintenance environment with the flake available (`d2/REINSTALL.md` §2–3).

### 4.1 Format

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/v1.12.0 -- \
  --mode disko \
  --flake '.#controller'
```

**GUESS:** pinning the disko *runner* to `v1.12.0` matches the flake input; if Court prefers `nix run` from the flake’s own disko input, use that equivalent. `askPassword = true` → passphrase prompt at format time (no `/tmp` password file).

### 4.2 Install / switch

```bash
sudo nixos-install --flake '.#controller'
# later, on a booted system:
sudo nixos-rebuild switch --flake '.#controller'
```

### 4.3 First unlock smoke (COURT)

- [ ] Reboot; unlock with the LUKS **passphrase** only.
- [ ] Confirm mounts: `/`, `/nix`, `/home` on btrfs subvols; `/boot` on vfat ESP (`d2/disko.nix` layout).
- [ ] Confirm networking comes up far enough to reach mesh tooling.
- [ ] **Do not** claim TPM unlock succeeded. PCRs are all-zero (FACT from D4). Optional later enrollments (`systemd-cryptenroll --tpm2-with-pin=yes` or PCRs 0+2+4) are documented in [`d2/REINSTALL.md`](../d2/REINSTALL.md) §§5–6 and remain **Court/Spock** decisions — passphrase stays mandatory fallback. **Never** `--tpm2-pcrs=7` alone on this MrChromebox box.

### 4.4 Mesh rejoin (COURT)

- [ ] Bring up WireGuard per accepted [`d3/`](../d3/) inventory (controller peer; path-only private key).
- [ ] `wg show` — handshake age healthy to rig / conduit as Court expects.
- [ ] Confirm remote-build or SSH-over-mesh path Court relies on still works (GUESS: first post-LUKS failure mode is “disk fine, Endpoint stale” — pair with D4 #1 / D6 idea 7 if needed).

### 4.5 Recovery key (offline — COURT)

```bash
sudo systemd-cryptenroll --recovery-key /dev/disk/by-uuid/<LUKS-UUID>
```

Store offline. Not in git (`d2/REINSTALL.md` §5).

---

## 5. Rollback if boot fails (COURT)

| Symptom | First moves |
|---------|-------------|
| Passphrase rejected / no cryptroot | Boot Porteus/Ventoy ([`c002/01-window-recovery.md`](../c002/01-window-recovery.md)). Confirm you are on the intended by-id disk. Do **not** run disko again until Court is sure of the target. |
| Unlocks but emergency target / no `/` | From recovery: inspect btrfs subvols; confirm disko names `cryptroot` / subvol mountpoints match `d2/disko.nix`. |
| Boots but no mesh | Treat as D3/ops — disk encryption is not the WireGuard config. Fix peers/endpoints; do not re-format. |
| ESP full / cannot add generation | From recovery or prior generation: lower `configurationLimit` or free `/boot`; ESP is 512 MiB by design. |
| Need prior unencrypted root | Only if Court kept a **full** pre-migration image/backup. btrfs migration is a deliberate break from ext4 (`d2/disko.nix` header). Without that image, rollback = restore from backups onto a fresh disko layout, not “undo LUKS in place.” |

**NIKOLA:** no remote hands. If Court needs a doc fix, say so in review — do not ask Nikola to SSH.

---

## 6. Done criteria (COURT signs)

- [ ] Passphrase unlock → multi-user (or Court-equivalent) on controller.
- [ ] btrfs subvols mounted as in `d2/disko.nix`; ESP mounted at `/boot`.
- [ ] Mesh rejoined; Court-critical remote path verified.
- [ ] Recovery key stored offline; no secrets added to git.
- [ ] Porteus/Ventoy still boots (parachute intact — [`c002/01-window-recovery.md`](../c002/01-window-recovery.md)).
- [ ] Explicit non-claim: **TPM unlock is not part of the trust story** while PCRs read zero.

---

## 7. What Nikola verified on the contractor VM (this session)

- Runbook cites real `d2/` paths and the 512 MiB ESP / `configurationLimit = 10` pairing from accepted D2 text.
- **Nikola did not** run disko, `nixos-install`, or any command against controller.
- Nested KVM on this VM remains hostile to QEMU nixosTests (same class as D2.2) — Court re-runs layout checks on the rig if desired before apply.
