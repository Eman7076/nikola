# D2 — Exact reinstall steps (you at the keyboard)

Nikola does not run these. No `curl | sh`. Read fully before touching the disk.

## 0. Preconditions

- Verified backups (flake, state you need, optional SSH host keys).
- NixOS installer matching your generation.
- Strong LUKS passphrase chosen offline.
- Optional: FIDO2 token if you want token unlock later.
- Power connected; prefer wipe+reinstall over in-place reencrypt.

## 1. Identify the eMMC

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,TYPE
ls -l /dev/disk/by-id/
```

Set `disko.devices.disk.controller.device` to the **by-id** path (not the USB installer).

## 2. One-time password file on the installer

```bash
install -m 600 /dev/null /tmp/controller-luks-pass
# write ONLY the passphrase into that file
```

Point disko LUKS `passwordFile` at `/tmp/controller-luks-pass` in an installer-only overlay. Never commit it.

## 3. Apply disko (DESTROYS the disk)

From the Court flake with D2 imported:

```bash
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko \
  --flake '.#controller'
```

Confirm the device string twice.

## 4. nixos-install

```bash
sudo nixos-install --flake '.#controller'
```

## 5. First boot — passphrase

Unlock with the LUKS passphrase. Verify ssh/Tailscale/remote-build.  
Shred `/tmp/controller-luks-pass` if it still exists on the installer medium.

## 6. Recovery key (recommended)

```bash
sudo systemd-cryptenroll --recovery-key /dev/disk/by-uuid/<LUKS-UUID>
```

Store the printed recovery key **offline**. Not in git.

## 7. Optional FIDO2 (preferred token path)

```bash
sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-uuid/<LUKS-UUID>
```

Enable `boot.initrd.systemd.enable` and add `crypttabExtraOpts = [ "fido2-device=auto" ];` (or disko equivalent), then `nixos-rebuild switch`.

## 8. Optional TPM — convenience only on Cr50

```bash
sudo tpm2_getcap properties-fixed | head
sudo tpm2_pcrread
```

If PCRs 0–7 are all zero, **stop** — do not sell TPM unlock as security. Passphrase/FIDO2 remain the doors.

If Spock still wants convenience enroll with empty PCRs:

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs= /dev/disk/by-uuid/<LUKS-UUID>
```

`tpm2_clear` is disruptive; only with Spock’s explicit OK.

## 9. Travel checklist

- Passphrase in a manager Eli/Spock control — not in fleet git.
- Recovery key offline.
- After firmware/bootloader changes, re-test unlock; re-enroll tokens if needed.

## In-place encrypt (discouraged)

Only if wipe is impossible: live USB, verified backup, `cryptsetup reencrypt --encrypt --type luks2 --reduce-device-size 32M …`, then wire initrd. Power loss mid-reencrypt risks the filesystem. Prefer section 3–5.

## Rollback

Installer + restore from step 0 backups / previous unencrypted image. No clean in-place “undo LUKS” without reformat or restore.
