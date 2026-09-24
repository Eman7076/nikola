# D3 — WireGuard mesh (rig / controller / conduit)

**Court Contract 001 · Deliverable D3 / D3.1**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

Reusable peer inventory + NixOS module (controller) + wg-quick packages (rig/conduit) + nixosTest + endpoint notes. Text/Nix for Spock/Eli to review and apply — Nikola does not SSH to Court machines or handle real secrets.

## OS roles (important)

| Peer | OS | How to run WireGuard |
|------|-----|----------------------|
| **rig** | Arch Linux | `nix build .#wg-conf-rig` → wg-quick |
| **controller** | NixOS | `court.wireguard` module (`hosts/controller.nix`) |
| **conduit** | Pop!_OS | `nix build .#wg-conf-conduit` → wg-quick |

## Spock note (from D2 follow-up)

Spock confirmed **controller PCRs 0–7 are all zero**; TPM unlock is off — **passphrase is the lock**. D2.2 (disko layout test) is queued separately and is **not** part of this D3 tree.

## Addressing (default mesh)

| Peer (contract name) | Mesh IPv4 | Role notes |
|----------------------|-----------|------------|
| **rig** | `10.77.0.1/24` | Arch; Spock fact: global IPv6 (AT&T mobile-range) — prefer as Endpoint when inbound works |
| **controller** | `10.77.0.2/24` | NixOS controller PC — passphrase LUKS (see `d2/`) |
| **conduit** | `10.77.0.3/24` | Pop!_OS; VPS/relay candidate if needed |

- **Prefix:** `10.77.0.0/24` (invented for Court drafts; change via `d3/peers.nix`).
- **Optional IPv6 ULA (not enabled by default):** `fd77:0:0::/48` with `::1` / `::2` / `::3` — add manually if Court wants dual-stack mesh.
- **Interface default:** `wg-court`
- **Listen port default:** `51820/udp`
- **Keepalive default:** `25` seconds (NAT/CGNAT hole refresh)

**Endpoint plan:** IPv6-first to rig → test inbound → VPS fallback. See **[CGNAT.md](./CGNAT.md)**.

## Single source of truth

`d3/peers.nix` holds peer names, mesh addresses, listen port, keepalive, optional endpoints, and the default private-key **path** for wg-quick. Both the NixOS module and the wg-quick packages consume it.

## Files

| Path | Role |
|------|------|
| `peers.nix` | Shared peer inventory |
| `wireguard-mesh.nix` | NixOS module: `options.court.wireguard` (controller) |
| `wg-conf.nix` | Generator for wg-quick `wg-court.conf` |
| `hosts/controller.nix` | Thin NixOS snippet wrapping `peers.nix` |
| `hosts/rig.nix` / `hosts/conduit.nix` | Pointers to wg-quick packages (not NixOS modules) |
| `nixos-test.nix` | Three-node mesh + underlay diagnostics + peer-down check |
| `eval-wireguard.nix` | Cheap module eval (no QEMU) |
| `CGNAT.md` | IPv6-first / CGNAT / VPS fallback |
| `README.md` | This file |

## Secrets policy

- **Private keys:** paths only. NixOS: `court.wireguard.privateKeyFile`. wg-quick: `PostUp = wg set %i private-key /etc/wireguard/wg-court.key` (path from `peers.nix` / build arg). **Never** inline private key material in committed confs or production Nix.
- **Public keys:** strings in `peers.nix` / git are fine (placeholders until Court fills real pubs).
- **nixosTest keys:** labeled **TEST-ONLY** — disposable, not for Court production.

Generate production keys on the target (or offline):

```bash
umask 077
wg genkey | tee /etc/wireguard/wg-court.key | wg pubkey > /etc/wireguard/wg-court.pub
# distribute .pub into d3/peers.nix; keep .key only on that host
```

## wg-quick install (rig / conduit)

```bash
# On a machine with Nix (or copy the built conf over):
nix build .#wg-conf-rig          # or .#wg-conf-conduit
sudo cp result /etc/wireguard/wg-court.conf
# Place private key at the path used in PostUp (default):
#   /etc/wireguard/wg-court.key
sudo chmod 600 /etc/wireguard/wg-court.conf /etc/wireguard/wg-court.key
sudo wg-quick up wg-court
wg show wg-court
```

To change the key path, edit `privateKeyPath` in `d3/peers.nix` and rebuild the package (or pass `privateKeyPath` into `d3/wg-conf.nix` when calling it).

## How to adopt (controller / NixOS)

1. Vendor `peers.nix` + `wireguard-mesh.nix` into the Court flake.
2. Import `hosts/controller.nix` pattern: set `privateKeyFile`, keep `peers = (import ./peers.nix).peers`.
3. Fill real public keys and endpoints in `peers.nix` (IPv6-first for rig when ready).
4. Module defaults `openFirewall = true` (UDP listen + trust `wg-court`).
5. `wg show` and `ping 10.77.0.X`.

## Verify

On Nikola’s Grok Bot VM:

- `nix build .#checks.x86_64-linux.d3-wireguard-eval` — must pass (no QEMU).
- `nix build .#wg-conf-rig` / `.#wg-conf-conduit` — confs generate with PostUp key path, no inline PrivateKey.
- `nix build .#checks.x86_64-linux.d3-wireguard-mesh` — **not runnable here**. Nested KVM faults. Run on the rig or any host with working nested virt:

```bash
nix build -L .#checks.x86_64-linux.d3-wireguard-mesh
```

### D3.1 underlay fix (nixosTest)

NixosTest assigns `virtualisation.test.nodeNumber` by **alphabetical** `attrNames` (conduit=1, controller=2, rig=3) → `192.168.1.<n>` on VLAN 1. Manual `networking.interfaces.eth1` addresses that disagree cause duplicate IPs and mesh timeouts. The test now leaves eth1 to the driver and uses **hostname endpoints** (`controller:51820`, etc.).

## Flake outputs

| Output | Purpose |
|--------|---------|
| `checks.d3-wireguard-eval` | Module evaluates (no QEMU) |
| `checks.d3-wireguard-mesh` | Full mesh + peer-down nixosTest |
| `packages.wg-conf-rig` | wg-quick conf for Arch rig |
| `packages.wg-conf-conduit` | wg-quick conf for Pop conduit |

## Honest limitations

- Default topology is **full mesh with /32 AllowedIPs**, not automatic hub hairpin for spoke↔spoke.
- Inbound IPv6 to rig is **unproven** until Court tests; VPS may be required.
- Nested KVM on this VM is broken — eval/build packages OK; mesh QEMU check must run elsewhere.
- No security certification claim; draft for human review.
- IPv6 mesh addresses not wired in the module yet (IPv6 used for Endpoint plan only).
