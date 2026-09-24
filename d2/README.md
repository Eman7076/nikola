# D2 — Controller disk encryption (draft)

**Court Contract 001 · Deliverable D2**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli  
**Status:** draft for human apply — nothing here runs on Court machines from Nikola’s VM

## Scope

Declarative LUKS2 for **controller** (NixOS Chromebook-class box: ~28.5 GiB eMMC, 4 GiB RAM, Cr50).  
Artifacts:

| Path | Role |
|------|------|
| `disko.nix` | GPT + ESP + LUKS2 root (btrfs) sized for small eMMC |
| `luks.nix` | NixOS fragment: systemd-initrd, LUKS, zram, eMMC-friendly bits |
| `REINSTALL.md` | Exact keyboard procedure you run |

## Honest Cr50 / TPM2 assessment

**Passphrase (or recovery key) is mandatory.** Treat TPM unlock as optional convenience, not the sole door.

Cr50 exposes a TPM2 interface but Google’s signed firmware is **not** a full TPM2.0 stack. Notably, `TPM2_PolicyPassword` is missing on Cr50, which breaks some policy/NV sealing flows ([tpm2-tools#3434](https://github.com/tpm2-software/tpm2-tools/issues/3434), [MrChromebox/firmware#626](https://github.com/MrChromebox/firmware/issues/626)). MrChromebox has stated Cr50 hardware could do more, but only Google-signed firmware runs.

**What can still work:** some operators report successful `systemd-cryptenroll --tpm2-device=auto` on Chromebooks *after* clearing TPM state (`tpm2_clear`), with automatic unlock on later boots ([same MrChromebox thread](https://github.com/MrChromebox/firmware/issues/626)). NixOS supports TPM2 LUKS via systemd-initrd + `crypttabExtraOpts = [ "tpm2-device=auto" ]` ([nixpkgs test](https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/systemd-initrd-luks-tpm2.nix), [Discourse](https://discourse.nixos.org/t/tpm2-luks-unlock-not-working/52342)).

**Guess (labeled):** On *this* controller, PCR-bound unlock is **plausible but not guaranteed**. Enroll only after a passphrase-unlocked boot succeeds. If enroll fails, you still have encryption; you type the passphrase when the box reboots away from home.

Nikola will **not** claim your locks are certified (contract hard line 3).

## Design choices (small eMMC)

- **One LUKS2 container** for `/` (btrfs), no separate `/nix` partition — simpler initrd, one unlock, store lives on `/nix` under root.
- **ESP 512 MiB** — enough for ~a few generations of UKI/kernels; raise to 1 GiB if you keep many profiles.
- **No swap partition** — `zramSwap` only (saves flash wear; matches Window’s prior intent).
- **`allowDiscards` / TRIM** on LUKS for eMMC — good for flash; slight metadata leak of free space (acceptable for this threat model: lost/stolen device at rest).
- **Headroom:** plan aggressive `nix.gc` + `auto-optimise-store`; 28 GiB is tight with a full NixOS closure + remote-build cache leftovers.

## Secrets policy

- No passphrases, keyfiles, or TPM seeds in this repo.
- Installer uses a **password file path you create on the live ISO** (see `REINSTALL.md`), then you shred it.
- Recovery: keep a second LUKS passphrase or `systemd-cryptenroll --recovery-key` output **offline**, not in git.

## How Nikola tested

- Static review + upstream docs/issues linked above.
- **Not** applied to controller (contract: VM-only). No `nixosTest` for LUKS+Cr50 here (no Cr50 in the sandbox).
- `nix-instantiate` / eval of these fragments may require your flake’s `disko` input; see integration note below.

## Integration note

Copy or import these files into the Court fleet flake’s `nixosConfigurations.controller` modules. Wire `disko.devices` from `disko.nix` and import `luks.nix`. Adjust `by-id` / disk device name on the machine (`lsblk`, `/dev/disk/by-id/...`).

## Unsure / guesses

- Exact eMMC kernel modules for *this* Chromebook board — `REINSTALL.md` lists a conservative mmc/sdhci set; add whatever `lsmod` showed on the working unencrypted install.
- Whether Cr50 needs `tpm2_clear` before enroll — document as optional troubleshooting, not a default “run this blindly” step (clearing TPM has consequences for any other TPM-bound state).
