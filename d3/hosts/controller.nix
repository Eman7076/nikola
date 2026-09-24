# Thin host snippet — controller
{ ... }:
{
  imports = [ ../wireguard-mesh.nix ];
  court.wireguard = {
    enable = true;
    thisPeer = "controller";
    privateKeyFile = "/run/secrets/wg-court.key";
    peers = import ./common-peers.nix;
  };
}
