# Nikola — Court contractor deliverables

**Court Contract 001**  
**Author:** Nikola (contractor)  
**Reviewer:** Spock (Court architect) · **Principal:** Eli

Standalone flake: sandbox home-manager (D1) plus Court-shaped Nix/docs for LUKS, WireGuard, ideas, and CUDA `llama-cpp-python`. Nikola proposes text/Nix in this repo only — does **not** SSH to Court machines or hold secrets.

## Apply sandbox home (D1, VM only)

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

## Deliverables

| ID | Status | Path |
|----|--------|------|
| **D1** | Accepted | this flake — sandbox `homeConfigurations.box` |
| **D2 / D2.1 / D2.2.1** | Accepted (rig QEMU) | [`d2/`](./d2/) controller LUKS + disko; disko pinned **v1.12.0** |
| **D3 / D3.1** | Accepted | [`d3/`](./d3/) WireGuard mesh + wg-quick pkgs + IPv6-first notes — Court owns rollout |
| **D4** | Accepted | [`d4/`](./d4/) ten ranked **controller** ideas |
| **D5.1–D5.4** | Accepted (rig) | [`d5/`](./d5/) JamePeng `llama-cpp-python` **0.3.49** CUDA + patches hook + pillow + sandbox-safe tests |
| **D5.5** | On `main`; Court GPU re-smoke | [`d5/`](./d5/) Arch NVIDIA **driver-only** shim (`shellHook` + `court-llama-env`) |
| **D6** | Pitch on `main` | [`d6/PITCH.md`](./d6/PITCH.md) ten ranked **fleet** ideas — reproducible / measurable bias |
| **D6.1** | Landed (Court apply) | [`d6/01-window-luks-apply.md`](./d6/01-window-luks-apply.md) window LUKS migration runbook — **Nikola does not operate window** |
| **D6.2** | Landed (module + checks) | [`d6/02-one-bell.md`](./d6/02-one-bell.md) + [`d6/one-bell/`](./d6/one-bell/) fan-in oneshot/timer — feeds existing dead-man; no `Persistent=true` |
| **D6.4** | Landed (module + checks) | [`d6/04-freshness-canary.md`](./d6/04-freshness-canary.md) + [`d6/freshness/`](./d6/freshness/) Spock index/recall mtime canary → one-bell status file; no `Persistent=true` |

## Hard lines

No Court machine access from Nikola, no secrets in git, no phone-home, nothing that needs a secret to evaluate. Labels: fact vs guess.

## Layout

- `flake.nix` / `flake.lock` — inputs + home + packages + checks + D5 shell
- `home.nix` / `modules/` — sandbox seat
- `d2/` … `d6/` — contract deliverables
- `notes/` — hop-surviving notes (no secrets)
