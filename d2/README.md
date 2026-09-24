# D2.1 — Controller / window disk encryption (draft)

**Court Contract 001 · Deliverable D2.1 / D2.2 / D2.2.1** (addresses Spock’s D2 review)  
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
| `nixos-test.nix` | Passphrase LUKS boot test (no Cr50) — D2.1 |
| `disko-layout-test.nix` | TEST-ONLY mirror of `disko.nix` for makeDiskoTest (device + passwordFile) |
| `nixos-test-disko.nix` | D2.2 disko layout test (GPT+ESP+LUKS2+btrfs) |
| `eval-luks.nix` | Cheap module eval check (no QEMU) |
| `RESEARCH.md` | Earlier Cr50 brief (still valid background) |


## D2.2.1 — disko pin (machines_qemu skew)

**Symptom (Court rig):** `makeDiskoTest` formatted GPT+ESP+LUKS2+btrfs and installed into `/mnt`, then crashed at reboot/passphrase with:

```
AttributeError: 'Driver' object has no attribute 'machines_qemu'
```

**Cause:** flake previously followed disko `master`. Post-v1.13 master registers the post-install VM via `driver.machines_qemu`, which **nixpkgs 25.05’s** test `Driver` does not expose. Same class of version skew as the earlier qemu-common adapter (removed on this pin — v1.12 does not take that argument).

**Fix:** pin disko to **`v1.12.0`** (2025-05-08, nixos-25.05 freeze window). Matches `pkgs.disko` version on this nixpkgs pin. Keeps the whole flake on one channel — did **not** bump only this check to a newer nixpkgs.

**Still needed from Court:** re-run `nix build -L .#checks.x86_64-linux.d2-disko-layout` on the rig so passphrase-unlock + btrfs subvolume assertions actually execute. This GPU-less / nested-KVM-hostile VM only evals/typechecks.

## Verify

On Nikola’s Grok Bot VM (2026-09-24):

- `nix build .#checks.x86_64-linux.d2-luks-eval` — **passed** (`luks.nix` evaluates into a NixOS toplevel).
- `nix build .#checks.x86_64-linux.d2-luks-passphrase` — **not runnable here**. Nested KVM faults (`kernel BUG` in `kvm_arch_vcpu_create`). The test mirrors nixpkgs `nixos/tests/systemd-initrd-luks-password.nix` (25.05). **Passphrase-only** unlock (upstream-style LUKS on a blank disk) — does **not** assert Nikola’s GPT/ESP/btrfs layout. Please run it on the rig or any host with working nested virt:

```bash
nix build -L .#checks.x86_64-linux.d2-luks-passphrase
```

- `nix build .#checks.x86_64-linux.d2-disko-layout` — **D2.2 / D2.2.1** (disko **v1.12.0**). Uses `disko.lib.testLib.makeDiskoTest` on a test-only mirror of Nikola’s layout (`disko-layout-test.nix`): GPT + 512 MiB ESP + LUKS2 (argon2id) + btrfs subvols `/`, `/nix`, `/home`. Formats, unlocks with a **TEST-ONLY** throwaway passphrase (`secretsecret` via makeDiskoTest’s `/tmp/secret.key`), boots, asserts mounts + subvolumes. Production `disko.nix` stays fail-closed on the by-id placeholder; the test remaps the device to the VM disk. No TPM enroll (PCRs zero — passphrase is the lock).
  - **Eval / typecheck (this VM, 2026-09-24):** passed — `nix eval` yields `disko-nikola-d2-disko-layout`; driver typecheck + lint clean; drv instantiates.
  - **QEMU run (this VM):** **blocked / killed.** Nested virt hung after `machine: starting vm` (~15 min; qemu-system 0 % CPU, test-driver spinning). Same class of failure as D2.1/D3 nested KVM on this box — do **not** wait the 3600 s timeout. Run on the Court rig (or any host with working nested virt):

```bash
nix build -L .#checks.x86_64-linux.d2-disko-layout
```

## Secrets

No passphrases in git. nixosTests use throwaway passphrases inside the test VM only (clearly labeled TEST-ONLY).
