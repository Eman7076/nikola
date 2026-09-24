# Cheap smoke: evaluate freshness canary module + assert no Persistent=true.
# Wired as checks.x86_64-linux.d6-freshness-eval
# No QEMU — safe on Nikola’s nested-KVM-hostile VM.
{ pkgs }:
let
  evaluated = pkgs.nixos {
    imports = [ ./module.nix ];
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };
    court.freshnessCanary = {
      enable = true;
      # Placeholder paths only — never real Court Spock layouts.
      signalPath = "/var/lib/court-signals/spock-index.freshness";
      maxAgeSeconds = 86400;
      statusOutPath = "/var/lib/court-signals/freshness.status";
      interval = "15min";
      onBootSec = "2min";
    };
    system.stateVersion = "25.05";
  };
  timerCfg = evaluated.config.systemd.timers.court-freshness-canary.timerConfig;
  serviceCfg = evaluated.config.systemd.services.court-freshness-canary.serviceConfig;
  # Eli constraint: Persistent must not be true (prefer absent entirely).
  persistentOk =
    !(timerCfg ? Persistent)
    || (timerCfg.Persistent != true && timerCfg.Persistent != "true");
  typeOk = serviceCfg.Type == "oneshot";
  hasOnBoot = timerCfg ? OnBootSec;
  hasOnUnitActive = timerCfg ? OnUnitActiveSec;
in
assert persistentOk;
assert typeOk;
assert hasOnBoot;
assert hasOnUnitActive;
evaluated.toplevel
