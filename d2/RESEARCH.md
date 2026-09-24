# D2 — LUKS on NixOS Chromebook-class controller (Cr50)

**Nikola · Contract 001.** HW: N3450, 4 GiB RAM, ~28.5 GiB eMMC, Cr50, NixOS ~26.05, remote builds, always-on, leaves house. Disk plaintext today.

---

## 1. Cr50 + systemd-cryptenroll / PCR LUKS — blunt

**PCR-bound TPM unlock is unrealistic as a security control. Passphrase is primary.**

### Cr50 facts
- Linux exposes Cr50 as TPM2-like (`google,cr50`). Binding: https://mjmwired.net/kernel/Documentation/devicetree/bindings/tpm/google,cr50.yaml
- **Not a full TPM 2.0.** MrChromebox: silicon capable; Google ships Cr50 FW with full TPM2 cmds disabled; signed Google FW only → **unfixable via UEFI.** https://github.com/MrChromebox/firmware/issues/626
- Missing **`TPM2_PolicyPassword`** → `0xB0143 command code not supported` on password-policy / some NVRAM seals. https://github.com/tpm2-software/tpm2-tools/issues/3434

### PCR binding
- Typical MrChromebox Full ROM: **PCRs 0–7 often all-zero** (no real measured boot). https://github.com/MrChromebox/firmware/issues/489 · #626 (2026-09: PCR binding “completely not available”; attacker boots USB on same board and unseals).
- Some boards fail enroll: `AES-128-CFB missing` / “TPM device not usable” (#626 ROBO360).

### What still works
| Method | OK? | Notes |
|--------|-----|-------|
| **Passphrase** | **Yes — primary** | |
| **Recovery key** `--recovery-key` | **Yes** | Offline only; do not invent secrets in docs |
| **FIDO2** `--fido2-device=auto` | **Yes** | Independent of Cr50 |
| **TPM, empty PCRs** | **Maybe** | After `tpm2_clear -c p`; convenience; protects stolen *drive*, not stolen *laptop* (BLORB path in #626) |
| **TPM + PCR 7 / 4+9+12** | **No for trust** | PCRs often useless |

Disko cannot declare TPM enroll (installer PCR ≠ installed). https://github.com/nix-community/disko/issues/861  
Post-boot manual: https://wiki.nixos.org/wiki/Full_Disk_Encryption · https://man7.org/linux/man-pages/man1/systemd-cryptenroll.1.html

**Travel verdict:** passphrase + recovery key (+ optional FIDO2). TPM optional convenience only after `tpm2_pcrread` proves non-zero *and* enroll succeeds on this board.

---

## 2. Disko layout (~28.5 GiB ≈ 29184 MiB)

One LUKS + btrfs subvols. **No** separate `/nix` partition. **No** swap partition → **zram**.

| Slice | Size | Role |
|-------|------|------|
| ESP | **512 MiB** | vfat `/boot` (768 MiB only if many generations) |
| LUKS2 | **~27.9 GiB** | rest; `allowDiscards` |
| `@`→`/` · `@nix`→`/nix` · `@home`→`/home` | shared pool | `compress=zstd`,`noatime` |
| Swap part | **0** | |
| zram | **~50% RAM ≈ 2 GiB** | compressed RAM swap |

**Nix headroom:** keep **≥10–14 GiB free** on LUKS; `auto-optimise-store` + weekly GC. Remote builds still leave closures locally.

Example: https://raw.githubusercontent.com/nix-community/disko/master/example/luks-btrfs-subvolumes.nix · zram: https://wiki.nixos.org/wiki/Swap

---

## 3. Minimal NixOS + disko (passphrase)

```nix
{ inputs, ... }: {
  imports = [ inputs.disko.nixosModules.disko ];
  disko.devices.disk.emmc = {
    type = "disk"; device = "/dev/mmcblk0"; # verify lsblk
    content.type = "gpt";
    content.partitions = {
      ESP = {
        size = "512M"; type = "EF00";
        content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ]; };
      };
      luks = {
        size = "100%";
        content = {
          type = "luks"; name = "cryptroot";
          # passwordFile = "/tmp/luks-pass"; # installer-only
          settings.allowDiscards = true;
          content = {
            type = "btrfs"; extraArgs = [ "-f" ];
            subvolumes = {
              "/root" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/nix"  = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
              "/home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
            };
          };
        };
      };
    };
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [ "aesni_intel" "cryptd" "mmc_block" ];
  boot.initrd.luks.devices.cryptroot.allowDiscards = true;
  # For FIDO2/TPM tokens later: boot.initrd.systemd.enable = true;
  zramSwap.enable = true;
  systemd.oomd.enable = true;
  nix.settings.auto-optimise-store = true;
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };
}
```

### Optional enroll (paths only — no invented secrets)
```bash
sudo systemd-cryptenroll --recovery-key /dev/disk/by-uuid/<LUKS-UUID>
sudo systemd-cryptenroll --fido2-device=auto /dev/disk/by-uuid/<LUKS-UUID>
# TPM convenience only: tpm2_getcap; tpm2_pcrread; maybe tpm2_clear -c p
# sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs= /dev/disk/by-uuid/<LUKS-UUID>
# crypttabExtraOpts = [ "fido2-device=auto" ] or [ "tpm2-device=auto" ]
```

---

## 4. Migrate unencrypted → encrypted

**Preferred:** backup → live USB → disko wipe/LUKS → restore flake + data → `nixos-install`. Disko is not in-place.

**In-place (risky):** live USB, offline:
1. Verified backup.
2. Shrink FS; leave **≥32 MiB** free at partition end.
3. `cryptsetup reencrypt --encrypt --type luks2 --reduce-device-size 32M /dev/mmcblk0pN`  
   https://man7.org/linux/man-pages/man8/cryptsetup-reencrypt.8.html
4. Open mapper; grow FS; wire `boot.initrd.luks.devices` + `/` → mapper; rebuild initrd (`nixos-enter`/`nixos-install`).
5. Test unlock before travel.

eMMC power-loss mid-reencrypt = data-loss risk even with LUKS2 recovery paths.

---

## 5. Risks

| Risk | Mitigation |
|------|------------|
| **eMMC wear** (LUKS+Nix churn) | TRIM; zram not disk swap; GC; remote builds |
| **Cr50/firmware** | No measured-boot trust; passphrase/FIDO2 |
| **Initrd @ 4 GiB** | Lean initrd; avoid huge Argon2 memory; systemd-stage1 only if tokens need it |
| **Travel passphrase loss** | Offline recovery key; optional FIDO2; recovery USB with flake |
| **Always-on + theft** | Lock screen; do **not** sell no-PCR TPM as security |

---

## URLs fetched
- https://github.com/MrChromebox/firmware/issues/626  
- https://github.com/MrChromebox/firmware/issues/489  
- https://github.com/tpm2-software/tpm2-tools/issues/3434  
- https://mjmwired.net/kernel/Documentation/devicetree/bindings/tpm/google,cr50.yaml  
- https://wiki.nixos.org/wiki/Full_Disk_Encryption  
- https://wiki.nixos.org/wiki/Swap  
- https://github.com/nix-community/disko/issues/861  
- https://raw.githubusercontent.com/nix-community/disko/master/example/luks-btrfs-subvolumes.nix  
- https://man7.org/linux/man-pages/man1/systemd-cryptenroll.1.html  
- https://man7.org/linux/man-pages/man8/cryptsetup-reencrypt.8.html
