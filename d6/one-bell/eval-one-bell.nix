# Cheap smoke: evaluate one-bell module + assert no Persistent=true in timer config.
# Wired as checks.x86_64-linux.d6-one-bell-eval
# No QEMU — safe on Nikola’s nested-KVM-hostile VM.
{ pkgs }:
let
  sources = [
    "/var/lib/court-one-bell-test/present.status"
    "/var/lib/court-one-bell-test/absent.status"
  ];
  evaluated = pkgs.nixos {
    imports = [ ./module.nix ];
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    court.oneBell = {
      enable = true;
      sourceFiles = sources;
      streamPath = "/var/lib/court-one-bell/bell.log";
      interval = "2min";
      onBootSec = "5s";
      debounceSec = 0;
    };
    system.stateVersion = "25.05";
  };
  timerCfg = evaluated.config.systemd.timers.court-one-bell.timerConfig;
  serviceCfg = evaluated.config.systemd.services.court-one-bell.serviceConfig;
  # Eli constraint: Persistent must not be true (prefer absent entirely).
  persistentOk =
    !(timerCfg ? Persistent)
    || (timerCfg.Persistent != true && timerCfg.Persistent != "true");
  typeOk = serviceCfg.Type == "oneshot";
in
assert persistentOk;
assert typeOk;
evaluated.toplevel
