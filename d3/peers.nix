# D3 — Court WireGuard peer inventory (single source of truth)
# Author: Nikola · Court Contract 001
#
# Drives:
#   - court.wireguard NixOS module (controller only — NixOS)
#   - packages.wg-conf-rig / wg-conf-conduit (Arch / Pop!_OS via wg-quick)
#
# Private keys are NEVER here — only paths on each host.
# Public keys below are placeholders for production; nixosTest overrides with TEST-ONLY keys.

{
  interface = "wg-court";
  meshCidr = "10.77.0.0/24";
  listenPort = 51820;
  persistentKeepalive = 25;

  # Default path for wg-quick PostUp (Arch/Pop). Override at build time if needed:
  #   nix build .#wg-conf-rig --argstr privateKeyPath /path/to/key
  # Documented install path:
  privateKeyPath = "/etc/wireguard/wg-court.key";

  # Peer names = contract names. Mesh addresses are fixed for the draft.
  # endpoint: host:port or [ipv6]:port; null = no inbound (peer must dial out + keepalive).
  #
  # IPv6-first plan (see CGNAT.md): prefer Endpoint = "[rig-global-ipv6]:51820"
  # once Spock fills the measured AT&T mobile-range address and inbound is confirmed.
  peers = {
    rig = {
      # Arch Linux — wg-quick (not NixOS)
      publicKey = "REPLACE_RIG_PUBLIC_KEY=";
      address = "10.77.0.1";
      # Fact (Spock): rig has a global IPv6 from AT&T mobile-range.
      # Unknown: whether unsolicited inbound UDP/51820 reaches the rig.
      # When inbound IPv6 works, set e.g. endpoint = "[2001:db8::rig]:51820";
      endpoint = null;
    };
    controller = {
      # NixOS — court.wireguard module
      publicKey = "REPLACE_CONTROLLER_PUBLIC_KEY=";
      address = "10.77.0.2";
      # Often home / CGNAT on IPv4 — leave null unless a real inbound path exists.
      endpoint = null;
    };
    conduit = {
      # Pop!_OS — wg-quick (not NixOS)
      publicKey = "REPLACE_CONDUIT_PUBLIC_KEY=";
      address = "10.77.0.3";
      # Candidate public/VPS endpoint if used as relay fallback; null until assigned.
      endpoint = null;
    };
  };
}
