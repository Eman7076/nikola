# Thin host snippet — conduit
{ ... }:
{
  imports = [ ../wireguard-mesh.nix ];
  court.wireguard = {
    enable = true;
    thisPeer = "conduit";
    privateKeyFile = "/run/secrets/wg-court.key";
    peers = import ./common-peers.nix;
  };
}
