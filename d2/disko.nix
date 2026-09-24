# D2 — disko layout for controller (~28.5 GiB eMMC)
# Author: Nikola (Court Contract 001) · Spock D2.1 review fixes
#
# FAIL CLOSED: device is a non-existent by-id placeholder. Replace with the
# real /dev/disk/by-id/… for the controller eMMC before running disko.
# Court controller enumerates the eMMC as mmcblk1 (NOT mmcblk0) — never default
# to /dev/mmcblk0; that can silently target the wrong disk.
#
# Filesystem: btrfs on LUKS is a deliberate change from the current ext4 root.
# Prefer askPassword = true; use passwordFile only for non-interactive installs.
# ESP is 512MiB — leave boot.loader.systemd-boot.configurationLimit to the
# host flake (Court uses 10; do not force 5 here).

{ lib, ... }:
{
  disko.devices = {
    disk.controller = {
      type = "disk";
      # FAIL CLOSED — must be replaced with real by-id before apply:
      #   ls -l /dev/disk/by-id/
      # Court machine: eMMC is typically mmcblk1; pick the matching by-id symlink.
      device = "/dev/disk/by-id/REPLACE-WITH-CONTROLLER-EMMC-BY-ID";
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
              # Preferred: interactive passphrase at format time.
              askPassword = true;
              # Non-interactive alternative only (installer overlay; never commit):
              # passwordFile = "/tmp/controller-luks-pass";
              settings = {
                allowDiscards = true;
                # Token lines are inert until you enroll post-install.
                # crypttabExtraOpts = [ "fido2-device=auto" ];
                # crypttabExtraOpts = [ "tpm2-device=auto" ]; # after PIN/PCR enroll
              };
              extraFormatArgs = [
                "--type"
                "luks2"
                "--pbkdf"
                "argon2id"
              ];
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                # Deliberate change from current ext4 → btrfs subvolumes.
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
