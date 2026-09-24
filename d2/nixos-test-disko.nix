# D2.2.1 — nixosTest via disko makeDiskoTest: Nikola layout (not upstream-only LUKS)
# Author: Nikola
#
# Proves GPT + ESP + LUKS2 + btrfs subvolumes /, /nix, /home:
#   format → unlock with TEST-ONLY passphrase → mount → boot with passphrase.
# Passphrase lock only (PCRs zero / no TPM enroll in this test).
#
#   nix build -L .#checks.x86_64-linux.d2-disko-layout
#
# Pattern: disko.lib.testLib.makeDiskoTest (see nix-community/disko tests/).
#
# Pin: disko **v1.12.0** (nixos-25.05 era; same as nixpkgs.disko). Newer disko
# master registers reboot VMs via driver.machines_qemu — an attribute the 25.05
# test Driver does not have → AttributeError after install/sync. v1.12.0 still
# uses driver.machines.append. No qemu-common adapter needed on this pin
# (that skew only appeared on later disko).

{
  pkgs,
  disko,
}:
let
  # Import disko’s test lib against *this* flake’s pkgs (25.05), not impure <nixpkgs>.
  diskoLib = import (disko + "/lib") {
    inherit (pkgs) lib;
    makeTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
    eval-config = import (pkgs.path + "/nixos/lib/eval-config.nix");
  };
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "nikola-d2-disko-layout";
  disko-config = ./disko-layout-test.nix;
  testMode = "module";
  enableOCR = true;
  extraSystemConfig = {
    # Match d2/luks.nix preference; passphrase prompt is systemd-initrd style.
    boot.initrd.systemd.enable = true;
  };
  bootCommands = ''
    # TEST-ONLY passphrase — same bytes makeDiskoTest wrote to /tmp/secret.key
    machine.wait_for_text("[Pp]assphrase for")
    machine.send_chars("secretsecret\n")
  '';
  extraTestScript = ''
    machine.succeed("cryptsetup isLuks /dev/vda2")
    machine.succeed("findmnt -n -o FSTYPE / | grep -qx btrfs")
    machine.succeed("mountpoint -q /")
    machine.succeed("mountpoint -q /nix")
    machine.succeed("mountpoint -q /home")
    machine.succeed("btrfs subvolume list / | grep -qs 'path nix$'")
    machine.succeed("btrfs subvolume list / | grep -qs 'path home$'")
    machine.succeed("btrfs subvolume list / | grep -qs 'path root$'")
  '';
}
