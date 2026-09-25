# Cheap smoke: evaluate revised one-bell module + assert no Persistent=true.
# Wired as checks.x86_64-linux.d6-one-bell-eval
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
    court.oneBell = {
      enable = true;
      # Fake Court-supplied command — module must not invent host/key/path.
      heartbeatCommand = "cat /var/lib/court-one-bell-test/heartbeat.json";
      # GUESS defaults exercised explicitly so eval pins the contract.
      staleAfterSec = 300; # GUESS
      sourceFailingRuns = 3; # GUESS
      interval = "2min"; # GUESS
      onBootSec = "30s"; # GUESS
      logPath = "/var/lib/court-one-bell/watch.log";
      statePath = "/var/lib/court-one-bell/watch.state";
      alertCommand = "";
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
  intervalOk = timerCfg.OnUnitActiveSec == "2min";
  bootOk = timerCfg.OnBootSec == "30s";
in
assert persistentOk;
assert typeOk;
assert intervalOk;
assert bootOk;
evaluated.toplevel
