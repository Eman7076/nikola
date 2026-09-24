# D3 — Generate wg-quick conf for Arch (rig) / Pop!_OS (conduit)
# Author: Nikola · Court Contract 001
#
# Same peer list as court.wireguard (d3/peers.nix).
# No private key inline — PostUp loads from privateKeyPath.
#
#   nix build .#wg-conf-rig
#   nix build .#wg-conf-conduit
#
# Optional override:
#   nix build .#wg-conf-rig --override-input ...  (prefer callPackage arg)
# Flake packages pass privateKeyPath default from peers.nix.

{
  pkgs,
  thisPeer,
  privateKeyPath ? null,
  inventory ? import ./peers.nix,
}:
assert builtins.elem thisPeer [
  "rig"
  "controller"
  "conduit"
];
let
  inv = inventory;
  keyPath = if privateKeyPath != null then privateKeyPath else inv.privateKeyPath;
  me = inv.peers.${thisPeer};
  meshPrefix =
    let
      parts = pkgs.lib.splitString "/" inv.meshCidr;
    in
    if builtins.length parts == 2 then builtins.elemAt parts 1 else "24";

  otherNames = builtins.filter (n: n != thisPeer) (
    builtins.attrNames inv.peers
  );

  peerBlock =
    name:
    let
      p = inv.peers.${name};
      endpointLine =
        if p.endpoint != null then "Endpoint = ${p.endpoint}\n" else "";
      keepalive =
        if inv.persistentKeepalive > 0 then
          "PersistentKeepalive = ${toString inv.persistentKeepalive}\n"
        else
          "";
    in
    ''
      [Peer]
      # ${name}
      PublicKey = ${p.publicKey}
      AllowedIPs = ${p.address}/32
      ${endpointLine}${keepalive}'';

  conf = ''
    # Court WireGuard mesh — peer: ${thisPeer}
    # Generated from d3/peers.nix (same inventory as NixOS court.wireguard).
    #
    # PRIVATE KEY: not inline (Court policy). Place the key file at:
    #   ${keyPath}
    # then:
    #   sudo cp wg-court.conf /etc/wireguard/wg-court.conf
    #   sudo chmod 600 /etc/wireguard/wg-court.conf ${keyPath}
    #   sudo wg-quick up wg-court
    #
    # OS: rig=Arch, conduit=Pop!_OS (wg-quick). controller=NixOS uses the module.

    [Interface]
    Address = ${me.address}/${meshPrefix}
    ListenPort = ${toString inv.listenPort}
    PostUp = wg set %i private-key ${keyPath}

    ${pkgs.lib.concatStrings (map peerBlock otherNames)}
  '';
in
pkgs.writeTextFile {
  name = "wg-court.conf";
  text = conf;
}
