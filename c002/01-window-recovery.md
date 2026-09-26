# C002.1 — Controller Ventoy / Porteus recovery runbook (Court-owned)

**Court Contract 002 · Deliverable 1** (implements D6 pitch **idea 10**)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli  
**Applies to:** **controller** (NixOS Chromebook fleet controller)  
**Name history (FACT):** This machine was called **window** until **2026-09-25** (Eli). Old notes that say “window” mean this host. Fleet flake target: `nixosConfigurations.controller`, `hosts/controller/`, `networking.hostName = "controller"`.  
**Hard line:** Nikola drafts this checklist only. **Nikola does not operate controller**, boot sticks, unlock LUKS, restore souls, or claim any live rehearsal. Court runs every step on Court metal / Court media.

**Upstream cites (do not re-invent):**

| Path | Role |
|------|------|
| [`d2/disko.nix`](../d2/disko.nix) | GPT + 512M ESP + LUKS2 `cryptroot` + btrfs subvols `/`, `/nix`, `/home` |
| [`d2/REINSTALL.md`](../d2/REINSTALL.md) | Format → install → enroll (attr was `.#window` in older text; live target is `.#controller`) |
| [`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) | Idea 1 apply runbook — **this** doc is the parachute it requires |
| [`d6/PITCH.md`](../d6/PITCH.md) §10 | Menu item this deliverable implements |
| [`check-stick.sh`](./check-stick.sh) | VM-safe “required paths present” checker (extra stick files OK) |
| [`manifest.example.txt`](./manifest.example.txt) | **Additive** manifest Court merges onto the existing stick |

**Controller facts (FACT unless marked):** ~28.5 GB eMMC; **today still unencrypted** (pre–idea 1); PCRs 0–7 all-zero on Cr50 → passphrase is the disk lock after LUKS. Souls/dbs ~**375 MB** class live on **novacourt/rig**, not as a controller inventory number — Court decides what of that class (if any) ever rides on recovery media.

**Ordering:** Recovery first (this doc), then LUKS ([`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md)). Do not treat a beautiful unread runbook as a substitute for encryption — parachute, not harness ([`d6/PITCH.md`](../d6/PITCH.md) §10).

> **Rehearsal status (FACT — Spock, 2026-09-25):** **PASSED.** Window ~**22:2x–23:3x** America/Chicago; **Eli’s hands** on controller (Nikola did **not** run metal). §7 steps **1–6** green; D6.1 stop rule **satisfied**. Findings 1–4 below are folded into this revision. **Do NOT start D6.1 apply** — still Eli’s decision/hands. Passed: Ventoy from controller boot menu; SystemRescue **13.02 NORMAL mode** → root shell; `check-stick` ok=8 missing=0 (live + earlier on rig); eMMC RO mount **`mmcblk1p2`** (NixOS root), unmounted untouched; fleet-flake tarball rev **`76f1716`** extracted (`flake.nix`, `flake.lock`, `hosts/`, `home/`). Device names `/dev/sda1`, `mmcblk1p2` are **FACT** from this Court night — **GUESS** if other hardware differs.

---

## 0. Ownership / labels

| Label | Meaning |
|-------|---------|
| **FACT** | Measured or already accepted in-repo |
| **GUESS** | Nikola’s estimate — Court must verify on controller / stick |
| **COURT** | Human at keyboard on controller, recovery stick, or offline backup medium |
| **NIKOLA** | Text/scripts in this repo only — never executed against controller by Nikola |

| Who | Owns |
|-----|------|
| **COURT** | Existing stick inventory, additive `court-recovery/` tree, hashes, souls backup custody, rehearsal, live unlock/restore |
| **NIKOLA** | This markdown, `check-stick.sh`, example manifest, flake check wiring |
| **Neither** | Redistributing copyrighted ISOs; putting soul bytes or keys in git |

---

## 1. Purpose (COURT)

Parachute **before** D2 LUKS on controller’s ~28.5 GB eMMC ([`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md)):

1. Rehearse once on **this** Chromebook **before** any destructive `disko` apply.
2. Keep a known path when eMMC dies, passphrase is lost-but-recovery-key-exists, or post-LUKS boot fails.
3. Know how to restore Court-owned ~375 MB-class souls from **Court’s** encrypted/offline backup — Nikola never holds souls.
4. Know how to materialize the **fleet flake** at a recorded pin **without** needing GitHub or a live path to the rig bare repo (default: pre-seeded tarball on the stick).

**Stop rule:** If the stick has not passed §7 rehearsal, **do not** start [`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) §4.

---

## 2. What lives on the stick (COURT — existing media)

**FACT:** The fleet already has a **128 GB Ventoy stick** holding **five OSes** plus the **Porteus toolkit**. It is the fleet’s fifth member. Section 2 is a **checklist against that real stick**, not a “build Ventoy from scratch” guide.

Nikola does **not** redistribute ISOs. Court keeps the existing layout; **adds** the `court-recovery/` tree (and any Court-chosen pin/tarball files). Do **not** wipe or replace the five OS slots to satisfy this runbook.

**EJECT, never pull (COURT — FACT from 2026-09-25 rehearsal):** Before removing the stick from any host (rig, controller, live ISO), **unmount all three partitions** and **power the device off** (or cleanly eject), then remove. **Bold rule:** do not yank the stick while mounted.

**Rehearsal slip (FACT — Spock, same night):** Stick was pulled from the **rig** without unmount → kernel logged `"lost sync page write"` on **`sda1` block 0**. Data was actually OK (`HASHES` verified). Recorded so nobody repeats it — still treat dirty removal as a hash-recheck event, not as “probably fine.”

### 2.1 Existing layout (FACT) + additive tree (COURT)

```text
<stick>/                        # EXISTING Ventoy volume — leave intact
  (Ventoy boot files)
  … five OS ISOs + Porteus toolkit (Court’s current names) …
  court-recovery/               # ADD — do not replace sibling ISOs
    manifest.txt                # required paths only (start from manifest.example.txt)
    HASHES.txt                  # sha256 (or Court-standard) for listed blobs
    FLAKE_PIN.txt               # fleet pin + how to materialize it
    check-stick.sh              # copy of c002/check-stick.sh
    fleet-flake-<REV>.tar.gz    # DEFAULT materialization of the fleet flake (see §4)
    backups/                    # SLOT only — Court may keep souls offline elsewhere
      README.txt                # “souls backup rides on medium X” — no secret bytes
    NOTES.txt                   # Court rehearsal log
```

**ISO slots:** Court already chose versions on the stick. This runbook does **not** invent filenames for the five OSes. If Court wants the checker to gate on a specific ISO path, **add that relative path** to `manifest.txt`. Paths **not** listed are ignored — extra ISOs are fine.

| Intent | Who |
|--------|-----|
| Keep five OS + Porteus toolkit as-is | **COURT** (already on stick) |
| Add `court-recovery/` + fleet-flake tarball + pin/hashes | **COURT** |
| Optional: list one or more ISO paths in the manifest as hard requirements | **COURT** |

Record **sha256** (or Court-standard hash) for every **listed** blob in `HASHES.txt` on the stick — not as fake hashes in this repo.

### 2.2 Manifest (COURT maintains — additive)

Ship starts from [`manifest.example.txt`](./manifest.example.txt). Court copies it to `court-recovery/manifest.txt` and edits:

- Required: `court-recovery/` files + the fleet-flake tarball path Court actually wrote.
- Optional: specific existing ISO paths Court wants fail-closed.
- **Do not** list every ISO on the stick. **Do not** remove sibling ISOs to make the tree “match the example.”

Checker: [`check-stick.sh`](./check-stick.sh) — exit 0 only if every **listed** path exists and files are non-empty. Unlisted files/dirs on the stick are **tolerated** (no “unexpected file” fail). No network. Safe to dry-run on Nikola’s VM against a fake tree.

```bash
# On a machine with the stick mounted at /mnt/stick (COURT):
bash /mnt/stick/court-recovery/check-stick.sh /mnt/stick
# Or:
COURT_RECOVERY_MANIFEST=/mnt/stick/court-recovery/manifest.txt \
  bash check-stick.sh /mnt/stick
```

---

## 3. Souls restore (~375 MB class) — COURT only

**FACT (rig):** Irreplaceable data class ~**375 MB** souls/dbs on **novacourt** ([`d6/PITCH.md`](../d6/PITCH.md) fleet table). That is a **rig** fact, not “controller holds 375 MB.”

**NIKOLA never holds souls.** Restore means Court copies from an **encrypted/offline backup Court already owns** onto a recovered system.

### 3.1 Placeholders (names only — no real contents in git)

Examples of **filenames** Court might use on a medium Court controls:

- `SOULS_BACKUP.age`
- `souls-backup.tar.age`
- `souls-backup.tar.gpg`

Do **not** commit these files or their plaintext. The example manifest lists a **slot path** such as `court-recovery/backups/.keep` or a pointer README — Court replaces with the real encrypted blob path on the stick **or** documents that the blob lives on a **separate** offline medium (preferred if the stick travels with the Chromebook — **GUESS:** matches D4 #9 / D6.1 threat note).

### 3.2 Checklist (COURT)

- [ ] Verify encrypted backup present on stick **or** on the separate medium Court designated; record which in `NOTES.txt`.
- [ ] If disk is already LUKS (**post–idea 1**): unlock per §5, then mount btrfs subvols.
- [ ] If disk is still unencrypted (**today — FACT**): mount eMMC partitions directly; skip cryptsetup.
- [ ] Decrypt backup with Court’s existing age/gpg custody (**not** documented as key material here).
- [ ] `rsync` or `tar -x` into the Court-chosen path on the recovered system (GUESS: often under `/home/…` or a Court souls tree on novacourt after mesh is up — Court decides; controller may only be a staging host).
- [ ] Verify size/hash Court recorded at backup time (`du -h`, `sha256sum` against Court’s offline notes).
- [ ] Confirm Nikola’s repo still contains **zero** soul bytes.

---

## 4. Materialize a known flake pin (COURT)

Two different repos — **label which is which:**

| Kind | What | Where it lives | Disaster default |
|------|------|----------------|------------------|
| **Fleet flake** (canonical) | What **controller** boots (`nixosConfigurations.controller`, …) | Bare repo on the **rig**, reachable only from inside the house or over the mesh — **not** on GitHub | **Stick tarball** at pinned rev (§4.1) |
| **Contractor flake** (this repo) | Nikola’s sandbox / Contract deliverables (`Eman7076/nikola` on GitHub) | Public GitHub | Optional; useful for contractor docs/checks, **not** the machine’s boot source |

Stick carries `court-recovery/FLAKE_PIN.txt` that Court updates. Suggested format:

```text
# Fleet flake (canonical — boots controller). NOT the GitHub contractor repo.
kind=fleet-flake
source=stick-tarball
path=court-recovery/fleet-flake-0123456789abcdef0123456789abcdef01234567.tar.gz
rev=0123456789abcdef0123456789abcdef01234567
date=2026-09-25
recorded_by=Court
notes=pre-seeded before controller LUKS rehearsal
# Optional contractor pin (GitHub example only — does not replace fleet flake):
# contractor_repo=Eman7076/nikola
# contractor_rev=<40 hex>
```

`rev=` must be a 40-char hex git SHA when present ([`check-stick.sh`](./check-stick.sh) optionally validates that line). Record the tarball’s hash in `HASHES.txt`.

### 4.1 DEFAULT — extract the pre-seeded fleet-flake tarball (no network)

```bash
# From the live ISO with the stick mounted (COURT):
mkdir -p /tmp/fleet-flake
tar -xzf /mnt/stick/court-recovery/fleet-flake-<REV>.tar.gz -C /tmp/fleet-flake
# Then: nixos-rebuild / nixos-install / eval against that tree at the pinned rev Court packed.
```

Court builds that tarball on the rig (or any machine that can read the bare fleet repo) at the recorded rev, copies it onto the stick, and lists it in the manifest + `HASHES.txt`. **This is the path that works away from home when the mesh is down.**

### 4.2 If the mesh is up (demoted — optional)

Only when Court can reach the rig bare repo over the mesh (or from inside the house):

```bash
# Illustrative — Court fills the real bare-repo URL / path Court already uses
git clone <court-fleet-bare-or-mesh-url> fleet-flake
cd fleet-flake
git fetch origin <REV>
git checkout <REV>
```

Do **not** treat GitHub clone of `Eman7076/nikola` as a substitute for the fleet flake. The contractor repo may still be fetched from GitHub when useful for Nikola docs/checks:

```bash
# Contractor flake only (GitHub) — labeled, optional
git clone --depth 1 https://github.com/Eman7076/nikola.git
cd nikola && git fetch --depth 1 origin <CONTRACTOR_REV> && git checkout <CONTRACTOR_REV>
```

Prefer the stick’s recorded fleet rev over “whatever is tip today.”

---

## 5. Unlock path when LUKS already applied (forward-looking — COURT)

For post–idea 1 disasters. Layout from [`d2/disko.nix`](../d2/disko.nix):

- GPT disk; ESP 512M → vfat `/boot`
- LUKS2 partition name **`cryptroot`** (argon2id)
- Inner btrfs subvolumes: `/root` → `/`, `/nix` → `/nix`, `/home` → `/home`
- Device placeholder until Court fills by-id: `/dev/disk/by-id/REPLACE-WITH-CONTROLLER-EMMC-BY-ID`
- **FACT:** Court eMMC has shown up as **mmcblk1**, not mmcblk0 — never default to `/dev/mmcblk0`

### 5.1 Open + mount (illustrative — COURT adapts paths)

```bash
# Identify disk (COURT — confirm by-id / by-uuid before typing)
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
ls -l /dev/disk/by-uuid/

# Open LUKS (passphrase or recovery key — never typed into git)
sudo cryptsetup open /dev/disk/by-uuid/<LUKS-UUID> cryptroot
# or: sudo cryptsetup open /dev/disk/by-id/<…>-part2 cryptroot

# Mount btrfs subvols matching d2/disko.nix
sudo mkdir -p /mnt/{nix,home,boot}
sudo mount -o subvol=/root,compress=zstd:3,noatime /dev/mapper/cryptroot /mnt
sudo mount -o subvol=/nix,compress=zstd:3,noatime /dev/mapper/cryptroot /mnt/nix
sudo mount -o subvol=/home,compress=zstd:3,noatime /dev/mapper/cryptroot /mnt/home
# ESP (vfat) — pick the real ESP partition from lsblk / by-id
sudo mount /dev/disk/by-uuid/<ESP-UUID> /mnt/boot
```

Then inspect, restore (§3), or `nixos-install` / chroot rebuild per Court judgment. Enroll notes remain in [`d2/REINSTALL.md`](../d2/REINSTALL.md) §§5–6 — **do not** claim TPM unlock while PCRs read zero.

---

## 6. Pre-LUKS disaster (today — FACT: controller still unencrypted)

If eMMC fails or Court needs a clean reinstall **before** idea 1 encrypts the disk:

1. Boot live ISO from the **existing** Ventoy stick (Porteus toolkit or another Court-chosen slot).
2. Mount the eMMC partitions (no cryptsetup). Confirm **mmcblk1**/by-id — not mmcblk0 by habit.
3. Copy what matters to offline media (fleet-flake tarball / pin, public mesh inventory pointers, `/home` Court marks irreplaceable). **No private keys in this runbook’s examples.**
4. Reinstall via [`d2/REINSTALL.md`](../d2/REINSTALL.md) once Court is ready for LUKS — or restore an unencrypted image if Court kept a full pre-migration backup (**GUESS:** rare; plan for “restore onto fresh layout” instead). Target attr: **`.#controller`**.

---

## 7. Rehearsal protocol (the whole point — COURT)

Do this on **controller** before any disko wipe:

> **Rehearsal status (FACT — Spock / Eli hands, 2026-09-25 ~22:2x–23:3x America/Chicago):** **PASSED** — §7 steps **1–6** green. Findings 1–4 folded into this revision. D6.1 stop rule **unblocked** by that PASS, but **do not** treat this as go-now for apply — still **Eli’s night / Eli’s hands**. Nikola drafts only; Nikola did **not** operate controller.

1. [ ] **Confirm** the existing 128 GB Ventoy stick still boots its five OS + Porteus toolkit slots Court cares about (do **not** rebuild Ventoy unless Court already planned to).
2. [ ] **Add** `court-recovery/` (edited `manifest.txt`, `FLAKE_PIN.txt`, `HASHES.txt`, `check-stick.sh`, fleet-flake tarball at pinned rev). Leave sibling ISOs alone.
3. [ ] **Boot on this Chromebook — Ventoy NORMAL mode only (FACT, 2026-09-25 rehearsal):**
   - From the controller firmware/boot menu, enter Ventoy and start **SystemRescue 13.02** (or Court’s chosen recovery ISO) in **NORMAL** mode → root shell.
   - **Do not use Ventoy MEMDISK (Ctrl+D).** **FACT:** MEMDISK **breaks** SystemRescue boot — initramfs cannot find the medium → busybox emergency shell. (`Failed to probe lspcon` is a **harmless** Chromebook Intel graphics warning; ignore it.)
   - **NORMAL mode is the mode.** SystemRescue’s own **“copy to RAM”** boot option is a **different** thing from Ventoy Memdisk — do not confuse them.
   - Confirm firmware reaches Ventoy and the slots Court needs (or document which slots fail — GUESS: some Chromebook recovery images need specific firmware paths).
4. [ ] **Mount the stick from the live system, then run the checker (COURT):**

   Device names below are **FACT** from the 2026-09-25 Court night (`/dev/sda1` = stick first partition under that boot). **GUESS** if other hardware enumerates differently — confirm with `lsblk` first.

   ```bash
   mkdir -p /mnt/stick
   # First try — plain mount (often fails under Ventoy NORMAL mode):
   mount -o ro /dev/sda1 /mnt/stick
   # FACT (rehearsal, twice): plain mount fails with
   #   fsconfig() failed: /dev/sda1: Can't open blockdev
   # still fails after: dmsetup remove ventoy
   # Working route:
   L=$(losetup -r -f --show /dev/sda1); mount -o ro "$L" /mnt/stick
   ```

   **Confirm the mount before reading anything** — empty mount-point dirs look like empty trees; a silent failed mount → false “`court-recovery` missing” alarm:

   ```bash
   findmnt /mnt/stick   # must show the stick (or loop) source; do not proceed if empty
   ls /mnt/stick/court-recovery
   bash /mnt/stick/court-recovery/check-stick.sh /mnt/stick
   ```

   Expect all `OK` lines for **listed** paths (rehearsal: **ok=8 missing=0**); fix `MISSING` before claiming rehearsal pass. Extra unlisted ISOs must **not** fail the check. Checker also passed **ok=8** earlier on the rig (**FACT**).
5. [ ] **Dry run unlock-or-mount without wiping:**
   - Pre-LUKS (today): mount eMMC read-only if possible; list trees; unmount. Do **not** run `disko --mode disko`.
   - **FACT (2026-09-25):** RO mount of NixOS root on **`mmcblk1p2`**, inspected, unmounted untouched.
   - Post-LUKS (after idea 1): practice `cryptsetup open` + subvol mounts on a **spare** or accept that first live unlock after apply *is* the practice — still rehearse stick boot + checker **before** apply.
6. [ ] Practice extracting the fleet-flake tarball to a throwaway directory (**default**). **FACT (2026-09-25):** tarball at rev **`76f1716`** extracted — tree contained `flake.nix`, `flake.lock`, `hosts/`, `home/`. Optionally, **if mesh is up**, practice clone from the rig bare repo — demoted path only.
7. [ ] Record pass/fail + date + who in `court-recovery/NOTES.txt` on the stick (and/or Court ops log).

   **NOTES guidance (COURT — Nikola does not operate the stick):** `NOTES.txt` already has a **partial first-pass log** from this night. The formal **PASS** line goes in when the stick **next sits in the rig** — Nikola does not write that file on Court media. Example line when Court appends:

   ```text
   2026-09-25 rehearsal PASS controller Ventoy+SystemRescue-NORMAL+check-stick+fleet-tarball-76f1716 — Eli (Spock witness)
   ```

8. [ ] Only then is D6.1’s stop rule satisfied. **Still Eli’s decision** whether/when to start [`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) destructive steps — this PASS is **not** an apply go-order.

**Eject reminder:** when finished, **unmount all three stick partitions**, power off / clean eject, **then** remove (§2). Never pull while mounted.

**NIKOLA:** may prove the checker against a fake tree via `checks.x86_64-linux.c002-stick-check`. That is **not** a substitute for Court boot rehearsal. Nikola did **not** run this rehearsal on metal.

---

## 8. room note (think-only boundary)

**room** is a Bazzite render peer (immutable render / wire-only by Eli’s ruling).

- **No Court souls on room.**
- Nikola does **not** operate room.
- Recovery story’s fifth member is the **existing Porteus/Ventoy stick**, not room.
- Render jobs only; do not ask room to hold backups, unlock LUKS, or host flake pins for controller mortality.

---

## 9. Cross-links — recovery first, then LUKS

| Order | Doc | Role |
|-------|-----|------|
| 1 | **This file** [`c002/01-window-recovery.md`](./01-window-recovery.md) | Parachute + rehearsal |
| 2 | [`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) | Harness (idea 1 apply) |
| 3 | [`d2/REINSTALL.md`](../d2/REINSTALL.md) | Keyboard install/enroll after format |

Rollback table in D6.1 already points at Porteus/Ventoy; treat **this** Contract 002 D1 as the concrete parachute checklist that table assumes.

---

## 10. What Nikola verified on the contractor VM (this session)

- Runbook cites real `d2/disko.nix` names (`cryptroot`, subvols `/root` `/nix` `/home`, 512M ESP) and `d2/REINSTALL.md`.
- `check-stick.sh` + fake-tree test pass under `checks.x86_64-linux.c002-stick-check` (no QEMU), including **extra unlisted ISO tolerated**.
- **Nikola did not** boot Ventoy, unlock LUKS, restore souls, or operate controller/room.
- ISO URLs are intentionally omitted so this repo cannot be read as redistributing proprietary images — Court already holds the stick media.
- Corrections vs first C002.1 draft (Spock 2026-09-25): **controller** rename + history line; fleet flake **stick tarball default** (network demoted); **additive** checklist on the **existing** 128 GB stick.
- Fold-in after Court rehearsal PASS (Spock 2026-09-25, Eli hands): Ventoy **NORMAL** (not MEMDISK); stick mount via `losetup -r` when plain `mount` fails; `findmnt` before reads; **eject never pull**; device names `/dev/sda1` / `mmcblk1p2` recorded as Court-night FACT.
