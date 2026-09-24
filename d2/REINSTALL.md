# D2.1 — Reinstall / adopt steps (keyboard — Court runs these)

Target flake output: **`.#window`** until the controller rename.

## 0. Preconditions

- Backups of the current ext4 root (this migration switches to **btrfs**).
- Edit `disko.nix`: replace `device` with real `/dev/disk/by-id/…` from `ls -l /dev/disk/by-id/` after `lsblk`. On this Chromebook the internal eMMC has shown up as **mmcblk1**; do not assume mmcblk0.
- Merge `flake-fragment.nix` into the Court flake (disko input + module imports).
- **Remove** `fileSystems."/"` and `fileSystems."/boot"` from `hardware-configuration.nix` (disko owns those).

## 1. Eval check (safe)

```bash
nix flake check '.#window'   # or: nixos-rebuild dry-activate --flake '.#window'
```

Expect failure until the by-id placeholder is replaced and conflicting `fileSystems` are removed.

## 2. Format (DESTRUCTIVE)

Boot installer or maintenance environment with the flake available.

`askPassword = true` → disko prompts for the LUKS passphrase at format time (no `/tmp` password file).

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  --flake '.#window'
```

## 3. Install / switch

```bash
sudo nixos-install --flake '.#window'
# later:
sudo nixos-rebuild switch --flake '.#window'
```

## 4. First boot

Unlock with the LUKS **passphrase**. Confirm networking and remote builds.

## 5. Recovery key (offline)

```bash
sudo systemd-cryptenroll --recovery-key /dev/disk/by-uuid/<LUKS-UUID>
```

Store offline. Not in git.

## 6. TPM2 with PIN (preferred token convenience)

Spock: PCR7 alone is insufficient without Secure Boot. Use a PIN so theft of the device is not enough:

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes /dev/disk/by-uuid/<LUKS-UUID>
```

You will be prompted for a TPM PIN (distinct from the LUKS passphrase). Passphrase remains a fallback slot.

Add crypttab token opts as required by your systemd-initrd generation (often `tpm2-device=auto`), rebuild, reboot, test PIN unlock, then test passphrase fallback once.

### Alternate: PCRs 0+2+4 (no PIN)

Only if Spock accepts re-enrollment churn:

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+4 /dev/disk/by-uuid/<LUKS-UUID>
```

**Re-enroll after every kernel or firmware update** that changes those measurements. Document who owns that checklist.

### Do not

- `systemd-cryptenroll --tpm2-pcrs=7` alone on this MrChromebox box.
- `tpm2_clear` without an explicit Spock conversation.

## 7. Optional FIDO2

```bash
sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-uuid/<LUKS-UUID>
```

## ESP note

512 MiB ESP with `configurationLimit = 10` is intentional headroom for systemd-boot generations. If generations fill `/boot`, lower the limit or grow the ESP in a later disko revision — change them together.
