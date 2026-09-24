# D2.1 — Controller / window disk encryption (draft)

**Court Contract 001 · Deliverable D2.1** (addresses Spock’s D2 review)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

## Spock review → changes

1. **Security:** Do **not** bind LUKS to PCR 7 alone on MrChromebox without Secure Boot (PCR 7 matches a thief’s USB OS). Prefer **`systemd-cryptenroll --tpm2-with-pin=yes`** so possession of the chassis is not enough. Alternate: PCRs **0+2+4** with documented re-enroll after every kernel/firmware update. Passphrase remains the mandatory fallback. Threat model: lost/stolen device at rest.
2. **Fail closed:** `disko.nix` device defaults to `/dev/disk/by-id/REPLACE-WITH-CONTROLLER-EMMC-BY-ID` (non-existent). Court eMMC has been **mmcblk1**, not mmcblk0 — always use by-id.
3. **Integration:** See `flake-fragment.nix` — add `disko` input, import `disko.nixosModules.disko`, target **`.#window`** until rename.
4. **Eval conflicts:** `luks.nix` only **adds** initrd.systemd, tpm modules/tools, gc. Does not redeclare `boot.loader.*` or `zramSwap`. You must remove `fileSystems."/"` and `fileSystems."/boot"` from `hardware-configuration.nix` when adopting disko.
5. **`askPassword = true`** by default; `passwordFile` documented as non-interactive alternative only.

## Layout notes

- **btrfs** subvols for `/`, `/nix`, `/home` — deliberate change from Court **ext4**; backups/images assuming ext4 need a fresh restore plan.
- **512 MiB ESP** paired with Court’s existing `configurationLimit = 10` (Nikola no longer overrides the limit to 5).
- zram left entirely to Court’s `zramSwap.memoryPercent = 100`.

## Files

| Path | Role |
|------|------|
| `disko.nix` | Fail-closed disk + ESP + LUKS2 + btrfs |
| `luks.nix` | Additive initrd/TPM/gc only |
| `REINSTALL.md` | Keyboard steps for `.#window` |
| `flake-fragment.nix` | Inputs + module wiring sketch |
| `nixos-test.nix` | Passphrase LUKS boot test (no Cr50) |
| `eval-luks.nix` | Cheap module eval check (no QEMU) |
| `RESEARCH.md` | Earlier Cr50 brief (still valid background) |

## Verify

On Nikola’s Grok Bot VM (2026-09-23):

- `nix build .#checks.x86_64-linux.d2-luks-eval` — **passed** (`luks.nix` evaluates into a NixOS toplevel).
- `nix build .#checks.x86_64-linux.d2-luks-passphrase` — **not runnable here**. Nested KVM faults (`kernel BUG` in `kvm_arch_vcpu_create`). The test mirrors nixpkgs `nixos/tests/systemd-initrd-luks-password.nix` (25.05). Please run it on the rig or any host with working nested virt:

```bash
nix build -L .#checks.x86_64-linux.d2-luks-passphrase
```

## Secrets

No passphrases in git. nixosTest uses a throwaway passphrase inside the test VM only.
