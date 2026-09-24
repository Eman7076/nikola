# Cheap smoke: evaluate luks.nix as a NixOS module (no QEMU).
# Wired as checks.x86_64-linux.d2-luks-eval
{ pkgs }:
(pkgs.nixos {
  imports = [ ./luks.nix ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  system.stateVersion = "25.05";
}).toplevel
