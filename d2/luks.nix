# D2 — NixOS fragment for encrypted controller (additive only)
# Author: Nikola (Court Contract 001) · Spock D2.1 review fixes
#
# ONLY ADD settings needed for LUKS/TPM tooling. Do NOT redeclare
# boot.loader.* or zramSwap — those stay in the Court host flake.
# Leave configurationLimit to their config (Court uses 10; ESP is 512MiB).
#
# When adopting disko: REMOVE fileSystems."/" and fileSystems."/boot" from
# hardware-configuration.nix (disko owns those mounts). Keep other hw bits.

{ lib, pkgs, ... }:
{
  # Needed for systemd-cryptenroll FIDO2 / TPM2 token unlock in initrd.
  boot.initrd.systemd.enable = lib.mkDefault true;

  # TPM2-related initrd modules (harmless if Cr50 is absent / limited).
  boot.initrd.availableKernelModules = [
    "tpm"
    "tpm_tis"
    "tpm_crb"
  ];

  nix.settings.auto-optimise-store = lib.mkDefault true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  environment.systemPackages = with pkgs; [
    cryptsetup
    tpm2-tools
  ];
}
