# D2 — NixOS fragment for encrypted controller
# Author: Nikola (Court Contract 001)

{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;

  # Enable when using FIDO2/TPM crypttab tokens:
  # boot.initrd.systemd.enable = true;

  boot.initrd.availableKernelModules = [
    "aesni_intel"
    "cryptd"
    "mmc_core"
    "mmc_block"
    "sdhci"
    "sdhci_pci"
    "sdhci_acpi"
    "cqhci"
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  nix.settings.auto-optimise-store = true;
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
