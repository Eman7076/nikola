# Nikola D1 — sandbox home-manager flake

**Court Contract 001 · Deliverable D1**  
**Author:** Nikola (contractor)  
**Reviewer:** Spock (Court architect) · **Principal:** Eli

Standalone `home-manager` flake for user `box` on Nikola’s Debian-class Grok Bot VM. Rebuilds the sandbox seat after VM hops. Does **not** touch controller, conduit, or rig.

## Apply (sandbox VM only)

```bash
# Restore this repo to ~/nikola-home, then:
sudo apt-get update && sudo apt-get install -y xz-utils curl ca-certificates
curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' > ~/.config/nix/nix.conf
cd ~/nikola-home
nix run home-manager/release-25.05 -- switch --flake .#box -b backup
```

## Tested

- Nix 2.35.2 single-user on this VM
- `home-manager switch --flake ~/nikola-home#box` → exit 0
- Tools verified on PATH: `rg`, `hx`, `eza`, `nixfmt`, `home-manager`

## Guesses (read me)

- Pinned **25.05**, not Court **26.05**
- Username `box` / `$HOME=/home/box`
- Single-user Nix (no systemd nix-daemon on this container)
- `targets.genericLinux.enable = true` for non-NixOS

## Layout

- `flake.nix` / `flake.lock` — inputs + `homeConfigurations.box`
- `home.nix` — user, bash, git, direnv
- `modules/devtools.nix` — packages
- `notes/` — hop-surviving notes (no secrets)

## Contract notes

Hard lines honored: no Court machine access, no secrets, text/repo for human apply only.

## Deliverables

- **D1** (accepted): this flake (sandbox home)
- **D2 / D2.2 / D2.2.1** (draft→fix): [`d2/`](./d2/) controller LUKS + disko layout test; **disko pinned to v1.12.0** (25.05-era; machines_qemu skew) — Court re-runs QEMU check on rig
- **D3 / D3.1** (accepted): [`d3/`](./d3/) WireGuard mesh (rig=Arch, controller=NixOS, conduit=Pop) + wg-quick pkgs + IPv6-first endpoint notes — Court owns rollout
- **D4** (accepted): [`d4/`](./d4/) ten ranked controller ideas (prose + honest costs)
- **D5.1** (draft→PASS evals): [`d5/`](./d5/) CUDA shell + `patches/` hook
- **D5.2** (draft): [`d5/`](./d5/) JamePeng `llama-cpp-python` **0.3.49** src (`fetchSubmodules`) — Court drops House patches + `nix build .#llama-cpp-python-cuda` on rig
