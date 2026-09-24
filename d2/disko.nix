# D2 — disko layout for controller (~28.5 GiB eMMC)
# Author: Nikola (Court Contract 001)
#
# IMPORT into nixosConfigurations.controller.
# Set `disko.devices.disk.controller.device` to the real by-id path on hardware.
#
# Secrets: do NOT put a passphrase here. For nixos-install / disko-install,
# pass a passwordFile path that exists only on the installer environment
# (see REINSTALL.md). Example override at apply time:
#   disko.devices.disk.controller.content.partitions.luks.content.passwordFile = "/tmp/controller-luks-pass";

{ lib, ... }:
{
  disko.devices = {
    disk.controller = {
      type = "disk";
      # REPLACE on the machine, e.g. "/dev/disk/by-id/mmc-DF4032_0x... "
      device = "/dev/mmcblk0";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            name = "ESP";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            priority = 2;
            name = "cryptroot";
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings = {
                allowDiscards = true;
                # systemd-initrd unlock; TPM enroll is post-install (see REINSTALL.md)
                crypttabExtraOpts = [
                  "tpm2-device=auto"
                  "token-timeout=10"
                ];
              };
              # passwordFile = "/run/secrets/controller-luks"; # set only on installer
              extraFormatArgs = [
                "--type"
                "luks2"
                "--pbkdf"
                "argon2id"
              ];
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd:3"
                  "noatime"
                  "ssd" # eMMC still benefits from discard-friendly opts
                  "discard=async"
                ];
              };
            };
          };
        };
      };
    };
  };
}
