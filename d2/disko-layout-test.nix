# D2.2 — test-only mirror of Nikola’s controller layout for makeDiskoTest
# Author: Nikola (Court Contract 001)
#
# Mirrors d2/disko.nix (GPT + ESP + LUKS2 + btrfs subvols /, /nix, /home).
# Differences vs production (intentional, TEST ONLY):
#   - device is a VM placeholder; makeDiskoTest remaps to /dev/vdb (format)
#     then /dev/vda (booted system). Production stays fail-closed on by-id.
#   - passwordFile instead of askPassword so the installer VM can format
#     non-interactively. Passphrase is the throwaway written by makeDiskoTest.
#   - --iter-time=1 keeps argon2id but speeds the VM test (not for Court apply).
#
# TEST-ONLY passphrase (never production):
#   makeDiskoTest writes:  echo -n 'secretsecret' > /tmp/secret.key
#   Label: TEST-ONLY — not a real secret; safe to commit this comment.

{
  disko.devices = {
    disk.controller = {
      type = "disk";
      # Placeholder only — makeDiskoTest.prepareDiskoConfig overrides this.
      device = "/dev/vdb";
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
              # TEST-ONLY: /tmp/secret.key content = "secretsecret" (makeDiskoTest).
              passwordFile = "/tmp/secret.key";
              settings = {
                allowDiscards = true;
              };
              extraFormatArgs = [
                "--type"
                "luks2"
                "--pbkdf"
                "argon2id"
                "--iter-time"
                "1"
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
