# D3 — Endpoints: IPv6-first, CGNAT IPv4, relay fallback

**Court Contract 001 · Deliverable D3 / D3.1**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

Networking guidance for Spock/Eli. **Not** a certification of any ISP path. Facts vs guesses are labeled.

## Facts (Spock-measured / Court-known)

| Fact | Source |
|------|--------|
| **rig has a global IPv6** from AT&T **mobile-range** addressing | Spock measurement — treat as fact, not guess |
| Only **controller** is NixOS; **rig** = Arch, **conduit** = Pop!_OS | Court inventory |
| IPv4 home paths may be CGNAT or NAT without inbound | Common; confirm per site before relying on IPv4 Endpoint |

## Unknown (must test)

| Unknown | Why it matters |
|---------|----------------|
| Whether **unsolicited inbound IPv6 UDP/51820** reaches the rig | Could be home-gateway IPv6 firewall (Eli can pinhole) **or** carrier block (cannot open) |
| Whether phone-cellular → rig IPv6 WG handshake succeeds | Court will test from phone cellular once WG listens on rig |

Until inbound IPv6 is confirmed, do not assume `[rig-ipv6]:51820` works as a production Endpoint.

## Primary plan — IPv6-first Endpoint (rig)

1. Prefer WireGuard `Endpoint = [rig-global-ipv6]:51820` on peers that dial the rig (controller, conduit), once the measured address is filled into `d3/peers.nix`.
2. Bring up `wg-court` on the rig (Arch, `wg-quick` from `nix build .#wg-conf-rig`).
3. From phone cellular (and from controller/conduit), attempt handshake / `wg show` latest handshake.
4. If the home gateway filters inbound IPv6: Eli pinholes UDP 51820 to the rig.
5. If the **carrier** blocks unsolicited inbound IPv6: pinhole will not help — go to fallback.

Mesh addresses stay IPv4 (`10.77.0.0/24`) in this draft; IPv6 here is for **underlay Endpoint reachability**, not replacing mesh IPs (optional ULA mesh can be added later).

## Fallback — small VPS relay

If inbound IPv6 to the rig fails (carrier block or unworkable CPE):

- Run WireGuard (or only a meeting-point peer) on a **small VPS** with a stable public address.
- All home peers dial the VPS with `persistentKeepalive = 25` (inventory default).
- Cost: one hop + a bill; reliability: high.

## Prior CGNAT / IPv4 notes (still valid)

WireGuard needs at least one side of a peer pair to know a reachable `Endpoint` so it can send the first handshake.

When a peer sits behind CGNAT (or a home NAT with no port-forward and no working inbound IPv6):

- **Inbound `Endpoint` to that peer does not work** on IPv4 CGNAT.
- Setting `endpoint = "cgnat-public:51820"` on other peers for that node is a dead config.
- Full-mesh “everyone lists everyone else’s endpoint” collapses for pairs where both sides lack a reachable address (**double NAT / both-CGNAT**).

### What still works

If **at least one peer has a stable reachable endpoint** (rig IPv6 if inbound works, VPS, colo, forwarded port):

#### Hub / spoke

- Put the reachable peer in the middle (hub).
- Other peers set `endpoint = hub:port` and keepalive so they dial out and refresh NAT mappings.
- Spoke↔spoke via hub needs AllowedIPs / routing beyond this module’s default **/32 full mesh**.

#### Full mesh with keepalive (module + wg-quick default shape)

- Every peer lists the others’ public keys + mesh `/32` AllowedIPs.
- Only peers with a real inbound path get a non-null `endpoint` in `d3/peers.nix`.
- On public hosts’ configs, leave the no-inbound peer’s `endpoint = null`; that peer initiates + keepalive.
- Peer pairs that both lack endpoints still cannot start a session without a third path.

**One peer down:** with full mesh and two remaining peers that can reach each other, connectivity continues (`d3/nixos-test.nix`). If the only reachable hub dies and two no-inbound spokes have no path to each other, spoke↔spoke dies.

## Labeled options

| Approach | Notes | Label |
|----------|--------|--------|
| **IPv6 Endpoint to rig** | Prefer `[rig-ipv6]:51820` when inbound works | **Primary plan**; inbound = **unknown** until tested |
| **Keepalive to a public hub** | One dialable peer; others dial out | Common pattern; works with stock WireGuard |
| **Port-forward / “public IP” add-on (IPv4)** | Some ISPs sell a real IP or allow CPE forwarding | **Guess** — ISP-specific |
| **VPS as meeting point** | Cheap VPS; all dial the VPS | **Fallback** if inbound IPv6 fails |
| **Tailscale / Headscale / DERP-style relay** | Userspace coordination + relay | **Guess** that Court may or may not want this vs raw WG |
| **UDP hole punching / ICE-like helpers** | Not in stock `wg(8)` | Out of scope for this D3 module |
| **`DynamicEndpointRefresh` / roaming** | Helps when the reachable side’s IP changes; does not create inbound through CGNAT alone | Useful adjunct |

## Recommendation for Court (draft)

1. **Try IPv6-first:** fill Spock’s measured rig global IPv6 into `peers.nix`, listen on rig, test from phone cellular + other peers.
2. If inbound IPv6 works (with or without Eli’s gateway pinhole): use that as the primary Endpoint; keep keepalive on dialing peers.
3. If inbound IPv6 fails due to carrier: stand up a **small VPS relay** and dial that instead.
4. Leave `endpoint = null` for peers with no inbound path on everyone else’s peer list.
5. Do not assume IPv4 CGNAT can be opened without ISP cooperation.

## Secrets reminder

Private keys stay as **file paths** (`court.wireguard.privateKeyFile` on NixOS; `PostUp = wg set %i private-key <path>` in wg-quick confs). Public keys and endpoints are fine in Nix. Do not commit production private keys.
