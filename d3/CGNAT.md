# D3 — CGNAT / no inbound endpoint

**Court Contract 001 · Deliverable D3**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

Written answer for: a home router behind **carrier-grade NAT (CGNAT)**, so no stable public endpoint is reachable from the outside.

This is networking guidance for Spock/Eli to apply. It is **not** a certification that any specific Court ISP path is CGNAT — if Court’s ISP situation is unknown, treat ISP-specific claims below as **labeled guesses**.

## What breaks

WireGuard needs at least one side of a peer pair to know a reachable `Endpoint` (IP:port) so it can send the first handshake packet.

When a peer sits behind CGNAT (or a home NAT with no port-forward and no IPv6):

- **Inbound `Endpoint` to that peer does not work.** Packets aimed at the CGNAT public address never reach the peer’s WireGuard listen port (or hit the wrong subscriber).
- Setting `endpoint = "cgnat-public:51820"` on other peers for that node is a dead config — handshakes from the outside fail.
- Full-mesh “everyone lists everyone else’s endpoint” collapses for pairs where both sides lack a reachable address (**double NAT / both-CGNAT**).

## What still works

If **at least one peer has a stable public endpoint** (VPS, colo, fiber with a real public IP, or a forwarded port):

### Hub / spoke

- Put the reachable peer in the middle (hub).
- CGNAT peers set `endpoint = hub:port` and `persistentKeepalive` (module default **25s**) so they dial out and refresh the NAT mapping.
- Spoke↔spoke traffic can hairpin through the hub if AllowedIPs / routing are set that way (this module’s default is **/32 full mesh**, not automatic spoke↔spoke via hub — extend AllowedIPs or add routes if you want hub relay of mesh traffic).

### Full mesh with keepalive (this module’s default shape)

- Every peer still lists the others’ public keys + mesh `/32` AllowedIPs.
- Only peers with a real inbound path get a non-null `endpoint`.
- CGNAT peers leave `endpoint = null` on *their* entry in others’ configs? **No** — wait: the `endpoint` field lives on the *remote* peer entry. So on the CGNAT host’s config, set `endpoint` toward the public peers; on the public hosts’ configs, leave the CGNAT peer’s `endpoint = null` and rely on the CGNAT side to initiate + keepalive.
- Once the CGNAT side has initiated, return traffic flows through the mapped hole until the mapping expires; keepalive refreshes it.
- Peer pairs that both lack endpoints still cannot start a session to each other without a third path (see guesses below).

**One peer down:** with full mesh and two remaining peers that can reach each other (both have endpoints, or one dials the other), connectivity between those two continues. That is what `d3/nixos-test.nix` checks. If the only reachable hub dies and two CGNAT spokes have no path to each other, spoke↔spoke dies — topology choice matters.

## Labeled honest guesses / options

| Approach | Notes | Label |
|----------|--------|--------|
| **Keepalive to a public hub** | Simplest with this module: one peer (e.g. conduit on a VPS, or rig if it has public IP) is always dialable; home peers dial out. | Common pattern; works with stock WireGuard |
| **IPv6 if the ISP gives a global address** | Often bypasses IPv4 CGNAT; use a `/128` mesh or parallel `fd77:…` ULA. | **Guess** — depends on Court ISP / CPE |
| **Port-forward / “public IP” add-on** | Some ISPs sell a real IP or allow forwarding on the CPE. | **Guess** — ISP-specific; do not assume |
| **VPS as meeting point** | Cheap VPS runs WireGuard (or only a relay); all home peers dial the VPS. | Reliable; adds a hop and a bill |
| **Tailscale / Headscale / DERP-style relay** | Userspace coordination + relay when P2P/NAT fails. Heavier dependency; great UX. | **Guess** that Court may or may not want this vs raw WG |
| **UDP hole punching / ICE-like helpers** | Not in stock `wg(8)`; needs extra software. | Out of scope for this D3 module |
| **`DynamicEndpointRefresh` / roaming** | Helps when the *reachable* side’s IP changes; does not create inbound through CGNAT by itself. | Useful adjunct, not a CGNAT fix |

## Recommendation for Court (draft)

1. Pick **one** always-reachable endpoint (likely a small VPS or whichever Court host already has a stable public address).
2. Configure home/CGNAT peers with that endpoint + `persistentKeepalive = 25` (module default).
3. Leave `endpoint = null` for the CGNAT peer on everyone else’s peer list.
4. If two home peers must talk while the hub is down, either give one a real inbound path or accept a relay product (Tailscale/DERP/etc.) — **guess:** raw WireGuard alone will not save double-CGNAT.

## Secrets reminder

Private keys stay as **file paths** (`court.wireguard.privateKeyFile`). Public keys and endpoints are fine in Nix. Do not commit production private keys.
