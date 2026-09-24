# Cheap smoke: evaluate wireguard-mesh.nix as a NixOS module (no QEMU).
# Wired as checks.x86_64-linux.d3-wireguard-eval
#
# Uses a throwaway TEST-ONLY private key file in the Nix store — never production.
{ pkgs }:
let
  # TEST-ONLY — disposable; same key material as d3/nixos-test.nix rig key.
  testPrivateKeyFile = pkgs.writeText "court-wg-test-only.key" "ICBJnZwrjk4TvUMusgXlxLrfA9JfShzk3BqkgLi74FA=";
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
    privateKeyFile = "${testPrivateKeyFile}";  # TEST-ONLY store path string
    peers = {
      # Public keys TEST-ONLY (from d3/nixos-test.nix)
      rig = {
        publicKey = "sKEDqQpxjR2n2RG5xYqj3Pt67KHGosqgiwhHlO8a2Dk=";
        address = "10.77.0.1";
        endpoint = "192.0.2.1:51820";
      };
      controller = {
        publicKey = "JuA9FgMHvbY43hDLpiVyx0SHXN2Je4gP6adR7R04TgI=";
        address = "10.77.0.2";
        endpoint = "192.0.2.2:51820";
      };
      conduit = {
        publicKey = "/NMF4iCj19Bt2g8v8/lWOUz3DJOM3CaUweDWsBEQiHM=";
        address = "10.77.0.3";
        endpoint = null;
      };
    };
  };
  system.stateVersion = "25.05";
}).toplevel
