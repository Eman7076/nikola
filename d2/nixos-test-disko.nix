# D2.2 — nixosTest via disko makeDiskoTest: Nikola layout (not upstream-only LUKS)
# Author: Nikola
#
# Proves GPT + ESP + LUKS2 + btrfs subvolumes /, /nix, /home:
#   format → unlock with TEST-ONLY passphrase → mount → boot with passphrase.
# Passphrase lock only (PCRs zero / no TPM enroll in this test).
#
#   nix build -L .#checks.x86_64-linux.d2-disko-layout
#
# Pattern: disko.lib.testLib.makeDiskoTest (see nix-community/disko tests/).
# Note: nixpkgs 25.05 qemu-common wants { lib, pkgs }; disko’s test lib still
# calls it with { lib, stdenv } — thin adapter below.

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
    # Adapter: disko passes { lib, stdenv }; 25.05 qemu-common needs { lib, pkgs }.
    qemu-common =
      { lib, stdenv }:
      import (pkgs.path + "/nixos/lib/qemu-common.nix") {
        inherit lib pkgs;
      };
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
