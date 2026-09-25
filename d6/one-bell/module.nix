# D6.2 — Court one-bell NixOS module (revised 2026-09-25)
# Author: Nikola (Court Contract 001)
#
# External bus heartbeat watcher on **controller** (was "window" until 2026-09-25).
# Polls a Court-supplied heartbeatCommand that prints the rig feeder heartbeat JSON.
# Change-only local log. Optional alertCommand hook (Court owns the alert; no tokens here).
#
# Old local file fan-in is superseded (see archive/fan-in.sh.superseded-2026-09-25):
# the one bus lives on the rig; this is the watcher-of-the-watcher from OUTSIDE.
#
# Eli constraint: never Persistent=true on timer or service.
# Nikola proposes only — does not SSH/operate controller, conduit, or rig.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.court.oneBell;
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    types
    ;

  watch = pkgs.writeShellApplication {
    name = "court-one-bell-watch";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      gnugrep
      gawk
      jq
      bash
    ];
    # Strip the shebang from the checked-in script; writeShellApplication adds its own.
    text = lib.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ./watch.sh);
  };
in
{
  options.court.oneBell = {
    enable = mkEnableOption "Court one-bell external bus heartbeat watcher (oneshot + timer on controller)";

    heartbeatCommand = mkOption {
      type = types.str;
      default = "";
      example = "ssh court-rig cat /var/lib/court-bus/heartbeat.json";
      description = ''
        Shell command that prints the feeder heartbeat JSON on stdout.
        Court supplies the real string (ssh or other). This module invents no
        host, key, or path. Required (non-empty) when enable = true.
      '';
    };

    staleAfterSec = mkOption {
      type = types.ints.positive;
      # GUESS: Spock said “say 5 min” for noticing feeder stale from outside.
      default = 300;
      description = ''
        Seconds after feeder_last_run before overall = STALE.
        GUESS default 300 (Spock: “say 5 min”). Court may retune.
      '';
    };

    sourceFailingRuns = mkOption {
      type = types.ints.positive;
      # GUESS: align with feeder’s three-run HEALTH before treating a source as failing.
      default = 3;
      description = ''
        A source is failing when status == "failing" AND fails >= this threshold.
        GUESS default 3 (align feeder HEALTH). Court may retune.
      '';
    };

    interval = mkOption {
      type = types.str;
      # GUESS: Spock said every ~2 min.
      default = "2min";
      example = "2min";
      description = ''
        Duration for OnUnitActiveSec (re-arm after each oneshot).
        GUESS default 2min (Spock: every ~2 min). Persistent=true is never set.
      '';
    };

    onBootSec = mkOption {
      type = types.str;
      # GUESS: first tick soon after boot without Persistent catch-up.
      default = "30s";
      description = ''
        Delay after boot before the first oneshot (OnBootSec).
        GUESS default 30s.
      '';
    };

    logPath = mkOption {
      type = types.str;
      default = "/var/lib/court-one-bell/watch.log";
      description = "Local change-only log on controller.";
    };

    statePath = mkOption {
      type = types.str;
      default = "/var/lib/court-one-bell/watch.state";
      description = "Small state file for last emitted conditions (change detection).";
    };

    alertCommand = mkOption {
      type = types.str;
      default = "";
      description = ''
        Optional hook. If non-empty, run once per emitted change with env
        COURT_ONE_BELL_EVENT set to the log line. Empty = log only.
        Nikola does not write the alert sink; no tokens in this flake.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.heartbeatCommand != "";
        message = "court.oneBell.heartbeatCommand must be a non-empty shell command when court.oneBell.enable = true (Court supplies; module invents no host/key/path).";
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/court-one-bell 0750 root root -"
    ];

    systemd.services.court-one-bell = {
      description = "Court one-bell bus heartbeat watcher (controller watches rig feeder from outside)";
      path = [
        pkgs.bash
        pkgs.coreutils
        pkgs.jq
      ];
      # Use environment attrset (not Environment= list) so Court commands with
      # spaces (e.g. ssh … cat …) are escaped correctly by the NixOS systemd module.
      environment = {
        COURT_ONE_BELL_HEARTBEAT_CMD = cfg.heartbeatCommand;
        COURT_ONE_BELL_STALE_AFTER_SEC = toString cfg.staleAfterSec;
        COURT_ONE_BELL_SOURCE_FAILING_RUNS = toString cfg.sourceFailingRuns;
        COURT_ONE_BELL_LOG_PATH = cfg.logPath;
        COURT_ONE_BELL_STATE_PATH = cfg.statePath;
        COURT_ONE_BELL_ALERT_CMD = cfg.alertCommand;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${watch}/bin/court-one-bell-watch";
        # Eli constraint: never Persistent=true (that knob is on the *timer*; still
        # documented here so reviewers grepping units see the intent).
      };
    };

    systemd.timers.court-one-bell = {
      description = "Court one-bell timer (Persistent unset — Eli constraint)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.onBootSec;
        OnUnitActiveSec = cfg.interval;
        Unit = "court-one-bell.service";
        # Persistent deliberately omitted. Never set Persistent = true.
        #
        # Why OnBootSec + OnUnitActiveSec (not OnCalendar with Persistent=true):
        # after suspend/AFK we do *not* want a burst of catch-up runs. Staleness
        # is measured from feeder_last_run in the heartbeat JSON, not from a
        # Persistent backlog. Eli: no Persistent=true ever on these units.
      };
    };
  };
}
