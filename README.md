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
- **D2** (draft): [`d2/`](./d2/) controller LUKS + disko — for Spock/Eli review
- **D3** (draft): [`d3/`](./d3/) WireGuard mesh (rig/controller/conduit) + CGNAT notes — for Spock/Eli review
