# D6.4 — Court Spock recall / index freshness canary NixOS module
# Author: Nikola (Court Contract 001)
#
# Measures mtime age of a Court-configured signal path; writes a status file
# for court.oneBell.sourceFiles. No Persistent=true (Eli). No Court secrets,
# no real Court paths hardcoded — Court fills signalPath / statusOutPath.
#
# Court wiring (see d6/04-freshness-canary.md):
#   1. Set court.freshnessCanary.signalPath to a non-secret freshness signal
#      (index file mtime, or Court-written freshness stamp — placeholders only).
#   2. Add court.freshnessCanary.statusOutPath to court.oneBell.sourceFiles.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.court.freshnessCanary;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  canary = pkgs.writeShellApplication {
    name = "court-freshness-canary";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    # Strip the shebang from the checked-in script; writeShellApplication adds its own.
    text = lib.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ./canary.sh);
  };
in
{
  options.court.freshnessCanary = {
    enable = mkEnableOption "Court Spock recall/index freshness canary (oneshot + timer → status file for one-bell)";

    signalPath = mkOption {
      type = types.str;
      # Placeholder only — Court replaces with a real non-secret freshness signal.
      # Do not invent Spock’s real recall/index paths here.
      default = "/var/lib/court-signals/spock-index.freshness";
      example = "/var/lib/court-signals/spock-index.freshness";
      description = ''
        Absolute path whose mtime is the freshness signal (file or directory).
        Court owns the real path. Nikola never hardcodes Spock recall layout.
        The canary only stats mtime — it does not read file contents.
      '';
    };

    maxAgeSeconds = mkOption {
      type = types.ints.positive;
      default = 86400;
      example = 43200;
      description = "Maximum age in seconds before the signal is STALE (default 1 day).";
    };

    statusOutPath = mkOption {
      type = types.str;
      default = "/var/lib/court-signals/freshness.status";
      description = ''
        Status file the canary writes each tick (FRESH/STALE/MISSING line).
        Court should list this path in court.oneBell.sourceFiles so the fan-in
        stream carries the measured age (fail-closed when MISSING/STALE text appears).
      '';
    };

    interval = mkOption {
      type = types.str;
      default = "15min";
      example = "5min";
      description = ''
        Duration for OnUnitActiveSec (re-arm after each oneshot). Paired with
        OnBootSec. Persistent=true is never set.
      '';
    };

    onBootSec = mkOption {
      type = types.str;
      default = "2min";
      description = "Delay after boot before the first oneshot (OnBootSec).";
    };
  };

  config = mkIf cfg.enable {
    # Parent dirs for default status/signal placeholders — Court may override paths.
    systemd.tmpfiles.rules = [
      "d /var/lib/court-signals 0750 root root -"
    ];

    systemd.services.court-freshness-canary = {
      description = "Court Spock recall/index freshness canary (feeds one-bell status file)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${canary}/bin/court-freshness-canary";
        Environment = [
          "COURT_FRESHNESS_SIGNAL=${cfg.signalPath}"
          "COURT_FRESHNESS_MAX_AGE=${toString cfg.maxAgeSeconds}"
          "COURT_FRESHNESS_STATUS=${cfg.statusOutPath}"
        ];
        # Eli constraint: never Persistent=true (that knob is on the *timer*).
        # SuccessExitStatus so ActiveState can still show failure on STALE/MISSING
        # while the written status file remains the one-bell signal.
      };
    };

    systemd.timers.court-freshness-canary = {
      description = "Court freshness canary timer (Persistent unset — Eli constraint)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.onBootSec;
        OnUnitActiveSec = cfg.interval;
        Unit = "court-freshness-canary.service";
        # Persistent deliberately omitted. Never set Persistent = true.
      };
    };
  };
}
