# Thin host snippet — rig
{ ... }:
{
  imports = [ ../wireguard-mesh.nix ];
  court.wireguard = {
    enable = true;
    thisPeer = "rig";
    privateKeyFile = "/run/secrets/wg-court.key";
    peers = import ./common-peers.nix;
  };
}
