# Cheap smoke: evaluate wireguard-mesh.nix as a NixOS module (no QEMU).
# Wired as checks.x86_64-linux.d3-wireguard-eval
#
# Uses a throwaway TEST-ONLY private key file in the Nix store — never production.
# Peer addresses/ports come from d3/peers.nix (single inventory).
{ pkgs }:
let
  inventory = import ./peers.nix;
  # TEST-ONLY — disposable; same key material as d3/nixos-test.nix rig key.
  testPrivateKeyFile = pkgs.writeText "court-wg-test-only.key" "ICBJnZwrjk4TvUMusgXlxLrfA9JfShzk3BqkgLi74FA=";
  # TEST-ONLY public keys (from d3/nixos-test.nix); production uses peers.nix placeholders.
  testPeers = {
    rig = inventory.peers.rig // {
      publicKey = "sKEDqQpxjR2n2RG5xYqj3Pt67KHGosqgiwhHlO8a2Dk=";
      endpoint = "192.0.2.1:51820";
    };
    controller = inventory.peers.controller // {
      publicKey = "JuA9FgMHvbY43hDLpiVyx0SHXN2Je4gP6adR7R04TgI=";
      endpoint = "192.0.2.2:51820";
    };
    conduit = inventory.peers.conduit // {
      publicKey = "/NMF4iCj19Bt2g8v8/lWOUz3DJOM3CaUweDWsBEQiHM=";
      endpoint = null;
    };
  };
in
(pkgs.nixos {
  imports = [ ./wireguard-mesh.nix ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  networking.hostName = "eval-rig";
  court.wireguard = {
    enable = true;
    thisPeer = "rig";
    privateKeyFile = "${testPrivateKeyFile}"; # TEST-ONLY store path string
    listenPort = inventory.listenPort;
    persistentKeepalive = inventory.persistentKeepalive;
    meshCidr = inventory.meshCidr;
    peers = testPeers;
  };
  system.stateVersion = "25.05";
}).toplevel
