# D3 — WireGuard mesh (rig / controller / conduit)

**Court Contract 001 · Deliverable D3**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

Reusable NixOS module + nixosTest + CGNAT notes for a three-peer WireGuard mesh. Text/Nix for Spock/Eli to review and apply — Nikola does not SSH to Court machines or handle real secrets.

## Spock note (from D2 follow-up)

Spock confirmed **controller PCRs 0–7 are all zero**; TPM unlock is off — **passphrase is the lock**. D2.2 (disko layout test) is queued separately and is **not** part of this D3 tree.

## Addressing (default mesh)

| Peer (contract name) | Mesh IPv4 | Role notes |
|----------------------|-----------|------------|
| **rig** | `10.77.0.1/24` | Often a build/virt host; may have a stable endpoint |
| **controller** | `10.77.0.2/24` | Window/controller PC — passphrase LUKS (see `d2/`) |
| **conduit** | `10.77.0.3/24` | Name suggests a path/relay candidate; assign endpoint if public |

- **Prefix:** `10.77.0.0/24` (invented for Court drafts; change via `court.wireguard` + peer `address` values if it collides).
- **Optional IPv6 ULA (not enabled in module by default):** `fd77:0:0::/48` with `::1` / `::2` / `::3` — add manually if Court wants dual-stack.
- **Interface default:** `wg-court`
- **Listen port default:** `51820/udp`
- **Keepalive default:** `25` seconds (NAT/CGNAT hole refresh)

See **[CGNAT.md](./CGNAT.md)** when a home peer has no inbound endpoint.

## Files

| Path | Role |
|------|------|
| `wireguard-mesh.nix` | Reusable module: `options.court.wireguard` |
| `hosts/*.nix` | Thin example snippets (`thisPeer` only + shared peers attr) |
| `nixos-test.nix` | Three-node mesh ping + one-peer-down check |
| `eval-wireguard.nix` | Cheap module eval (no QEMU) |
| `CGNAT.md` | CGNAT / no-inbound written answer |
| `README.md` | This file |

## Secrets policy

- **Private keys:** only as `court.wireguard.privateKeyFile = "/path/on/host";` (agenix, sops-nix, or root-only file). **Never** embed private key material in production Nix.
- **Public keys:** strings in host config / git are fine.
- **nixosTest keys:** labeled **TEST-ONLY** inside `nixos-test.nix` / eval — disposable, not for Court production.

Generate production keys on the target (or offline) and install the private file out of band:

```bash
umask 077
wg genkey | tee /run/secrets/wg-court.key | wg pubkey > /run/secrets/wg-court.pub
# distribute .pub values into the peers { ... } attr; keep .key only on that host
```

## How to adopt

1. Vendor `wireguard-mesh.nix` into the Court flake (or flake `imports`).
2. On each host, set `thisPeer`, `privateKeyFile`, and the shared `peers` attr (public keys + addresses + endpoints).
3. Example (controller):

```nix
{ config, ... }:
{
  imports = [ ./wireguard-mesh.nix ];

  court.wireguard = {
    enable = true;
    thisPeer = "controller";
    privateKeyFile = "/run/secrets/wg-court.key"; # path only
    peers = {
      rig = {
        publicKey = "RIG_PUBLIC_KEY=";
        address = "10.77.0.1";
        endpoint = "rig.example.net:51820"; # or null if unreachable
      };
      controller = {
        publicKey = "CONTROLLER_PUBLIC_KEY=";
        address = "10.77.0.2";
        endpoint = null; # this host — endpoint unused for self
      };
      conduit = {
        publicKey = "CONDUIT_PUBLIC_KEY=";
        address = "10.77.0.3";
        endpoint = "conduit.example.net:51820";
      };
    };
  };
}
```

Thin copies of the same idea live under `hosts/` (rig / controller / conduit) — fill in real public keys and endpoints before apply.

4. Open firewall: module defaults `openFirewall = true` (UDP listen + trust `wg-court`).
5. From each host: `wg show` and `ping 10.77.0.X`.

## Verify

On Nikola’s Grok Bot VM (2026-09-24 CT):

- `nix build .#checks.x86_64-linux.d3-wireguard-eval` — **passed** (`wireguard-mesh.nix` evaluates into a NixOS toplevel with `wg-court` units).
- `nix build .#checks.x86_64-linux.d3-wireguard-mesh` — **not runnable here**. Nested KVM faults (`kernel BUG` in `kvm_arch_vcpu_create` / `kvm_spurious_fault`). The test driver **typechecks and lints**; three-node VMs fail to start on this host. Please run on the rig or any host with working nested virt:

```bash
nix build -L .#checks.x86_64-linux.d3-wireguard-mesh
```

## Flake checks

| Check | Purpose |
|-------|---------|
| `d3-wireguard-eval` | Module evaluates (no QEMU) |
| `d3-wireguard-mesh` | Full mesh + peer-down nixosTest |

## Honest limitations

- Default topology is **full mesh with /32 AllowedIPs**, not automatic hub hairpin for spoke↔spoke.
- CGNAT needs at least one reachable endpoint or an external relay — see CGNAT.md.
- No security certification claim; draft for human review.
- IPv6 mesh not wired in the module yet (document-only suggestion).
