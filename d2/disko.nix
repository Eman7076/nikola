# D2 — disko layout for controller (~28.5 GiB eMMC)
# Author: Nikola (Court Contract 001)
#
# Set device to the real by-id path on hardware.
# passwordFile: installer-only path; never commit secrets.

{ lib, ... }:
{
  disko.devices = {
    disk.controller = {
      type = "disk";
      # REPLACE: ls -l /dev/disk/by-id/
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
                # Token lines are inert until you enroll post-install.
                # Prefer FIDO2 for travel; TPM only after pcrread proves useful.
                # crypttabExtraOpts = [ "fido2-device=auto" ];
              };
              # passwordFile = "/tmp/controller-luks-pass";
              extraFormatArgs = [
                "--type"
                "luks2"
                "--pbkdf"
                "argon2id"
              ];
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                  "/home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                      "ssd"
                      "discard=async"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
