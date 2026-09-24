# D2 — Exact reinstall steps (you at the keyboard)

Nikola does not run these. No `curl | sh`. Read fully before touching the disk.

## 0. Preconditions

- Court backups of controller config + any state you care about (flake, `/var` bits, SSH host keys if you want to keep them).
- NixOS installer USB/ISO matching your generation (26.05 line is fine).
- A strong passphrase chosen offline; you will type it into a **local file on the installer**, never into git.
- Laptop on power; 30–90 minutes depending on restore.

## 1. Identify the eMMC

Boot installer → networking if needed → root shell:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,TYPE
ls -l /dev/disk/by-id/
```

Note the **by-id** path for the internal eMMC (not the USB installer).  
Edit `disko.nix`: set `disko.devices.disk.controller.device = "/dev/disk/by-id/…";`

## 2. Create a one-time password file on the installer

```bash
install -m 600 /dev/null /tmp/controller-luks-pass
# put ONLY the passphrase in that file (your editor or printf); no trailing commentary
```

You will point disko at this path for format. Shred after install.

## 3. Apply disko (DESTROYS the disk)

From your flake checkout on the installer (USB copy, `git clone` of Court flake with D2 files imported):

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  --flake '.#controller'
```

Or your project’s documented `disko-install` / `nixos-install` path if you already have one.  
**Confirm the device string twice.** Wrong by-id = wrong disk.

If your disko version expects `passwordFile` on the LUKS content, set it in a temporary installer-only overlay:

```nix
disko.devices.disk.controller.content.partitions.luks.content.passwordFile = "/tmp/controller-luks-pass";
```

## 4. Install NixOS into the opened mapper

```bash
sudo nixos-install --flake '.#controller'
# set root password when prompted (separate from LUKS passphrase)
```

## 5. First boot (passphrase)

Reboot, remove installer media.  
At cryptsetup prompt: enter the **LUKS passphrase**.  
Confirm multi-user target, Tailscale/ssh, remote-build to rig still work.

```bash
shred -u /tmp/controller-luks-pass   # if the installer still mounted; else already gone
```

## 6. Optional TPM2 enroll (Cr50 may refuse)

Only after passphrase boot works:

```bash
# Inspect TPM
sudo tpm2_getcap properties-fixed | head
sudo systemd-cryptenroll /dev/disk/by-partlabel/cryptroot
# expect to see passphrase slot; no TPM yet

# Enroll TPM (keeps passphrase slot)
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/cryptroot
```

If enroll errors (unsupported command / Cr50 limits):

1. Keep using passphrase — **encryption still holds**.
2. Optional recovery key (store offline, not in git):

```bash
sudo systemd-cryptenroll --recovery-key /dev/disk/by-partlabel/cryptroot
```

3. Only if Spock agrees: investigate `tpm2_clear` implications before clearing ownership ([MrChromebox#626](https://github.com/MrChromebox/firmware/issues/626)). Clearing is disruptive; do not treat it as routine.

Ensure flake already has systemd-initrd + `crypttabExtraOpts` including `tpm2-device=auto` (see `disko.nix` / `luks.nix`), then rebuild:

```bash
sudo nixos-rebuild switch --flake '.#controller'
```

Reboot once. If TPM unlock works, you should get a short timeout then boot; if not, passphrase still unlocks.

## 7. Travel / lost device checklist

- Passphrase memorized or in a password manager Spock/Eli control — not in the fleet git repo.
- Recovery key offline.
- Remote wipe is **not** provided by LUKS alone; plan separately if needed.
- After firmware or Secure Boot changes, PCR7 enrollments often break → unlock with passphrase → re-enroll TPM.

## Rollback

Boot installer → if you still have backups, re-disko without LUKS from last known good unencrypted layout, or restore from image backup taken in step 0. There is no in-place “undo LUKS” without reformat or restore.
