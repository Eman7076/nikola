# C002.1 — Window Ventoy / Porteus recovery runbook (Court-owned)

**Court Contract 002 · Deliverable 1** (implements D6 pitch **idea 10**)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli  
**Applies to:** **window** (NixOS Chromebook conductor; flake host still `.#window` until rename)  
**Hard line:** Nikola drafts this checklist only. **Nikola does not operate window**, boot sticks, unlock LUKS, restore souls, or claim any live rehearsal. Court runs every step on Court metal / Court media.

**Upstream cites (do not re-invent):**

| Path | Role |
|------|------|
| [`d2/disko.nix`](../d2/disko.nix) | GPT + 512M ESP + LUKS2 `cryptroot` + btrfs subvols `/`, `/nix`, `/home` |
| [`d2/REINSTALL.md`](../d2/REINSTALL.md) | Format → install → enroll for `.#window` |
| [`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) | Idea 1 apply runbook — **this** doc is the parachute it requires |
| [`d6/PITCH.md`](../d6/PITCH.md) §10 | Menu item this deliverable implements |
| [`check-stick.sh`](./check-stick.sh) | VM-safe “files present on mounted stick” checker |
| [`manifest.example.txt`](./manifest.example.txt) | Placeholder manifest Court copies onto the stick |

**Window facts (FACT unless marked):** ~28.5 GB eMMC; **today still unencrypted** (pre–idea 1); PCRs 0–7 all-zero on Cr50 → passphrase is the disk lock after LUKS. Souls/dbs ~**375 MB** class live on **novacourt/rig**, not as a window inventory number — Court decides what of that class (if any) ever rides on recovery media.

**Ordering:** Recovery first (this doc), then LUKS ([`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md)). Do not treat a beautiful unread runbook as a substitute for encryption — parachute, not harness ([`d6/PITCH.md`](../d6/PITCH.md) §10).

---

## 0. Ownership / labels

| Label | Meaning |
|-------|---------|
| **FACT** | Measured or already accepted in-repo |
| **GUESS** | Nikola’s estimate — Court must verify on window / stick |
| **COURT** | Human at keyboard on window, recovery stick, or offline backup medium |
| **NIKOLA** | Text/scripts in this repo only — never executed against window by Nikola |

| Who | Owns |
|-----|------|
| **COURT** | ISOs, Ventoy install, stick layout, hashes, souls backup custody, rehearsal, live unlock/restore |
| **NIKOLA** | This markdown, `check-stick.sh`, example manifest, flake check wiring |
| **Neither** | Redistributing copyrighted ISOs; putting soul bytes or keys in git |

---

## 1. Purpose (COURT)

Parachute **before** D2 LUKS on window’s ~28.5 GB eMMC ([`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md)):

1. Rehearse once on **this** Chromebook **before** any destructive `disko` apply.
2. Keep a known path when eMMC dies, passphrase is lost-but-recovery-key-exists, or post-LUKS boot fails.
3. Know how to restore Court-owned ~375 MB-class souls from **Court’s** encrypted/offline backup — Nikola never holds souls.
4. Know how to fetch a recorded flake pin (`Eman7076/nikola` or Court fleet flake) without guessing revs.

**Stop rule:** If the stick has not passed §7 rehearsal, **do not** start [`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) §4.

---

## 2. What lives on the stick (COURT supplies)

Nikola does **not** redistribute ISOs. Court downloads from upstream, writes Ventoy, and records versions + hashes on the stick manifest.

### 2.1 Layout (GUESS — Court picks final tree)

Suggested root on the USB after Ventoy is installed (Ventoy keeps its own ESP/data partitions; Court places content under the Ventoy data volume):

```text
<stick>/
  (Ventoy boot files — installed by Court via Ventoy tool)
  ISOs/                          # or Ventoy default ISO folder Court prefers
    <chromebook-recovery>.iso    # Chromebook recovery image — COURT downloads
    <nixos-installer>.iso        # NixOS installer — COURT downloads
    <porteus-or-live>.iso        # Porteus or Court-chosen live Linux with cryptsetup + network
  court-recovery/
    manifest.txt                 # required paths list (start from manifest.example.txt)
    FLAKE_PIN.txt                # rev + date + who recorded
    check-stick.sh               # copy of c002/check-stick.sh
    backups/                     # SLOT only — Court may keep souls offline elsewhere
      README.txt                 # “souls backup rides on medium X” pointer — no secret bytes
    NOTES.txt                    # optional Court rehearsal log
```

**ISO slots (names are slots, not redistributed files):**

| Slot | Intent | Who picks version |
|------|--------|-------------------|
| Chromebook recovery | Vendor recovery / firmware path if eMMC is toast | **COURT** — download from Google/ChromeOS recovery upstream Court already trusts |
| NixOS installer | Fresh `nixos-install` / flake install per [`d2/REINSTALL.md`](../d2/REINSTALL.md) | **COURT** — matching nixpkgs channel Court boots |
| Porteus (or live Linux) | cryptsetup + mount + rsync/tar + network for flake fetch | **COURT** — Porteus is the pitch default; any live ISO Court verifies can run `cryptsetup` + network is fine (**GUESS:** Porteus remains lightest Ventoy peer) |

Label every ISO filename Court actually uses in `manifest.txt`. Record **sha256** (or Court-standard hash) next to each name in `NOTES.txt` or a sibling `HASHES.txt` Court maintains — not in this repo’s example as fake hashes.

### 2.2 Manifest (COURT maintains)

Ship starts from [`manifest.example.txt`](./manifest.example.txt). Court copies it to `court-recovery/manifest.txt` on the stick and edits paths to match real ISO filenames and backup slot names.

Checker: [`check-stick.sh`](./check-stick.sh) — reads the manifest; exit 0 only if every listed path exists and files are non-empty. No network. Safe to dry-run on Nikola’s VM against a fake tree.

```bash
# On a machine with the stick mounted at /mnt/stick (COURT):
bash /mnt/stick/court-recovery/check-stick.sh /mnt/stick
# Or:
COURT_RECOVERY_MANIFEST=/mnt/stick/court-recovery/manifest.txt \
  bash check-stick.sh /mnt/stick
```

---

## 3. Souls restore (~375 MB class) — COURT only

**FACT (rig):** Irreplaceable data class ~**375 MB** souls/dbs on **novacourt** ([`d6/PITCH.md`](../d6/PITCH.md) fleet table). That is a **rig** fact, not “window holds 375 MB.”

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
- [ ] `rsync` or `tar -x` into the Court-chosen path on the recovered system (GUESS: often under `/home/…` or a Court souls tree on novacourt after mesh is up — Court decides; window may only be a staging host).
- [ ] Verify size/hash Court recorded at backup time (`du -h`, `sha256sum` against Court’s offline notes).
- [ ] Confirm Nikola’s repo still contains **zero** soul bytes.

---

## 4. Fetch a known flake pin (COURT)

Stick carries a small `court-recovery/FLAKE_PIN.txt` that Court updates. Suggested format (one fact per line):

```text
repo=Eman7076/nikola
rev=0123456789abcdef0123456789abcdef01234567
date=2026-09-24
recorded_by=Court
notes=contractor flake pin before window LUKS rehearsal
```

`rev=` must be a 40-char hex git SHA when present ([`check-stick.sh`](./check-stick.sh) optionally validates that line).

### 4.1 Ways to materialize the pin (COURT — needs network on the live ISO)

```bash
# A) Shallow clone at recorded rev
git clone --depth 1 https://github.com/Eman7076/nikola.git
cd nikola
git fetch --depth 1 origin <REV>
git checkout <REV>

# B) Existing clone
git fetch origin <REV>
git checkout <REV>

# C) Nix prefetch (no working tree needed for some workflows)
nix flake prefetch "github:Eman7076/nikola?rev=<REV>"
```

Court fleet flake (if different from this contractor repo) uses the same pattern with Court’s repo URL and the rev recorded in `FLAKE_PIN.txt`. Prefer the stick’s recorded rev over “whatever main is today.”

**GUESS:** live Porteus/NixOS ISO networking is enough for github.com; if air-gapped, Court pre-seeds a tarball of the pinned tree on the stick and lists it in the manifest.

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

## 6. Pre-LUKS disaster (today — FACT: window still unencrypted)

If eMMC fails or Court needs a clean reinstall **before** idea 1 encrypts the disk:

1. Boot live ISO from the Ventoy stick (Porteus or NixOS installer).
2. Mount the eMMC partitions (no cryptsetup). Confirm **mmcblk1**/by-id — not mmcblk0 by habit.
3. Copy what matters to offline media (flake pin, public mesh inventory pointers, `/home` Court marks irreplaceable). **No private keys in this runbook’s examples.**
4. Reinstall via [`d2/REINSTALL.md`](../d2/REINSTALL.md) once Court is ready for LUKS — or restore an unencrypted image if Court kept a full pre-migration backup (**GUESS:** rare; plan for “restore onto fresh layout” instead).

---

## 7. Rehearsal protocol (the whole point — COURT)

Do this on **window** before any disko wipe:

1. [ ] Write Ventoy + Court-chosen ISOs; copy `court-recovery/` tree including edited `manifest.txt`, `FLAKE_PIN.txt`, and `check-stick.sh`.
2. [ ] Boot the stick on **this** Chromebook; confirm firmware/boot menu reaches Ventoy and each ISO slot Court cares about starts (or document which slots fail — GUESS: some Chromebook recovery images need specific firmware paths).
3. [ ] From the live environment (or from another machine with the stick mounted), run:

   ```bash
   bash court-recovery/check-stick.sh /path/to/stick-root
   ```

   Expect all `OK` lines; fix `MISSING` before claiming rehearsal pass.
4. [ ] **Dry run unlock-or-mount without wiping:**
   - Pre-LUKS (today): mount eMMC read-only if possible; list trees; unmount. Do **not** run `disko --mode disko`.
   - Post-LUKS (after idea 1): practice `cryptsetup open` + subvol mounts on a **spare** or accept that first live unlock after apply *is* the practice — still rehearse stick boot + checker **before** apply.
5. [ ] Optionally practice flake prefetch at the pinned rev on a throwaway directory (network).
6. [ ] Record pass/fail + date + who in `court-recovery/NOTES.txt` on the stick (and/or Court ops log). Example line:

   ```text
   2026-09-24 rehearsal PASS window Ventoy+check-stick — <name>
   ```

7. [ ] Only then continue to [`d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) destructive steps.

**NIKOLA:** may prove the checker against a fake tree via `checks.x86_64-linux.c002-stick-check`. That is **not** a substitute for Court boot rehearsal.

---

## 8. room note (think-only boundary)

**room** is a Bazzite render peer (immutable render / wire-only by Eli’s ruling). 

- **No Court souls on room.**
- Nikola does **not** operate room.
- Recovery story’s fifth member is the **Porteus/Ventoy stick**, not room.
- Render jobs only; do not ask room to hold backups, unlock LUKS, or host flake pins for window mortality.

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
- `check-stick.sh` + fake-tree test pass under `checks.x86_64-linux.c002-stick-check` (no QEMU).
- **Nikola did not** boot Ventoy, unlock LUKS, restore souls, or operate window/room.
- ISO URLs are intentionally omitted so this repo cannot be read as redistributing proprietary images — Court downloads upstream themselves.
