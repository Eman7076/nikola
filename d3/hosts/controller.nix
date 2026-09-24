# Thin host snippet — controller (NixOS only)
# rig = Arch (wg-quick via packages.wg-conf-rig)
# conduit = Pop!_OS (wg-quick via packages.wg-conf-conduit)
{ ... }:
let
  inventory = import ../peers.nix;
in
{
  imports = [ ../wireguard-mesh.nix ];
  court.wireguard = {
    enable = true;
    thisPeer = "controller";
    privateKeyFile = "/run/secrets/wg-court.key"; # path only — never inline
    listenPort = inventory.listenPort;
    persistentKeepalive = inventory.persistentKeepalive;
    meshCidr = inventory.meshCidr;
    peers = inventory.peers; # single source of truth: d3/peers.nix
  };
}
