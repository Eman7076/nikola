# D2 — NixOS fragment for encrypted controller
# Author: Nikola (Court Contract 001)
#
# Pair with ./disko.nix in nixosConfigurations.controller.
# Does not enroll TPM; does not embed secrets.

{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5; # small ESP / small disk

  # systemd stage-1 required for tpm2-device= in crypttab
  boot.initrd.systemd.enable = true;

  # Conservative eMMC / Chromebook block stack — merge with board-proven modules
  boot.initrd.availableKernelModules = [
    "mmc_core"
    "mmc_block"
    "sdhci"
    "sdhci_pci"
    "sdhci_acpi"
    "cqhci"
    "tpm_tis"
    "tpm_crb"
  ];

  # LUKS device itself is usually declared by disko; this is a safety net if
  # you wire devices manually. Prefer disko's generated config.
  # boot.initrd.luks.devices.cryptroot.device = "/dev/disk/by-partlabel/cryptroot";

  # No disk swap — save eMMC write cycles
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Store discipline on 28 GiB
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Tools for enroll / debug (post-install). Not required inside initrd.
  environment.systemPackages = with pkgs; [
    cryptsetup
    tpm2-tools
    sbctl # only if you later add Secure Boot; harmless if unused
  ];

  # Optional: enable TSS userspace; initrd TPM unlock does not depend on this alone
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
  };
}
