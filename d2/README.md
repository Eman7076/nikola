# D2 — Controller disk encryption (draft)

**Court Contract 001 · Deliverable D2**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli  
**Status:** draft for human apply — nothing here runs on Court machines from Nikola’s VM

## Scope

Declarative LUKS2 for **controller** (~28.5 GiB eMMC, 4 GiB RAM, Cr50 / MrChromebox-class Chromebook).

| Path | Role |
|------|------|
| `disko.nix` | GPT + ESP + LUKS2 + btrfs subvols (`@`, `@nix`, `@home`) |
| `luks.nix` | systemd-boot, lean initrd hooks, zram, store GC |
| `REINSTALL.md` | Keyboard procedure (wipe+reinstall preferred) |
| `RESEARCH.md` | Full Cr50/TPM brief with fetched URLs |

## Honest Cr50 / TPM2 assessment (updated)

**Passphrase (+ offline recovery key) is the security control. Optional FIDO2 is fine. TPM is at best convenience.**

Cr50 is TPM2-*like*, not a full TPM 2.0. Google’s signed firmware omits commands (notably `TPM2_PolicyPassword`). On many MrChromebox Full ROM setups, **PCRs 0–7 stay all-zero**, so PCR-bound “measured boot” unlock does **not** buy trust: an attacker with the chassis can often boot alternate media on the same board and unseal. Sources: [MrChromebox#626](https://github.com/MrChromebox/firmware/issues/626), [#489](https://github.com/MrChromebox/firmware/issues/489), [tpm2-tools#3434](https://github.com/tpm2-software/tpm2-tools/issues/3434).

| Method | Trust it? | Notes |
|--------|-----------|-------|
| Passphrase | **Yes — primary** | |
| Recovery key (`--recovery-key`) | **Yes** | Offline only; never in git |
| FIDO2 (`--fido2-device=auto`) | **Yes** | Independent of Cr50 |
| TPM with empty PCRs | Convenience only | May unlock stolen *drive* still in same machine path; not “stolen laptop” |
| TPM + PCR 7 / measured boot | **No for trust on this class** | PCRs often useless |

Disko cannot enroll TPM at install time (installer PCR ≠ installed system) — [disko#861](https://github.com/nix-community/disko/issues/861).

Nikola does **not** certify your locks (contract hard line 3).

## Design (small eMMC)

- One LUKS2 container; btrfs subvolumes for `/`, `/nix`, `/home` (no separate `/nix` partition).
- ESP **512 MiB**; LUKS takes the rest (~27.9 GiB).
- **zram** only — no swap partition (eMMC wear).
- `allowDiscards` on LUKS; `compress=zstd` + `noatime` on btrfs.
- Keep **≥10–14 GiB free** via GC + auto-optimise; remote builds still leave closures locally.

## Secrets policy

No passphrases, keyfiles, or TPM seeds in this repo. Installer uses a local password **file path** you create on the live ISO, then shred.

## How Nikola tested

Static review + research brief (`RESEARCH.md`). Not applied to controller. No Cr50 in the sandbox VM.

## Unsure / guesses

- Board-specific mmc/sdhci modules — merge with whatever the working unencrypted install already loads.
- Whether *this* unit’s PCRs are non-zero — Spock should run `tpm2_pcrread` before any TPM enroll story.
- In-place `cryptsetup reencrypt` is documented as risky fallback only; prefer backup → wipe → restore.
