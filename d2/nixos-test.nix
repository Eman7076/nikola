# D2.1 — nixosTest: LUKS unlocks with a passphrase and boots (no Cr50)
# Author: Nikola
#
# Pattern follows nixpkgs nixos/tests/systemd-initrd-luks-password.nix.
# Throwaway passphrase lives ONLY inside the test VM — never commit real secrets.
#
#   nix build -L .#checks.x86_64-linux.d2-luks-passphrase

{ pkgs, ... }:
pkgs.nixosTest {
  name = "nikola-d2-luks-passphrase";

  nodes.machine =
    { pkgs, lib, ... }:
    {
      virtualisation = {
        emptyDiskImages = [ 512 ];
        useBootLoader = true;
        mountHostNixStore = true;
        useEFIBoot = true;
      };

      boot.loader.systemd-boot.enable = true;
      boot.initrd.systemd = {
        enable = true;
        emergencyAccess = true;
      };

      environment.systemPackages = with pkgs; [ cryptsetup ];

      specialisation.boot-luks.configuration = {
        boot.initrd.luks.devices = lib.mkVMOverride {
          cryptroot.device = "/dev/vdb";
        };
        virtualisation.rootDevice = "/dev/mapper/cryptroot";
        virtualisation.fileSystems."/".autoFormat = true;
      };
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed(
        "echo -n test-passphrase-not-production | cryptsetup luksFormat -q --iter-time=1 /dev/vdb -"
    )
    machine.succeed("bootctl set-default nixos-generation-1-specialisation-boot-luks.conf")
    machine.succeed("sync")
    machine.crash()

    machine.start()
    machine.wait_for_console_text("Please enter passphrase for disk cryptroot")
    machine.send_console("test-passphrase-not-production\n")
    machine.wait_for_unit("multi-user.target")
    assert "/dev/mapper/cryptroot on / type ext4" in machine.succeed("mount")
  '';
}
