# D6.2.1 — Court one-bell NixOS module (revised 2026-09-25)
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

  # GUESS: TimeoutStartSec a little above heartbeatTimeoutSec so systemd kills
  # the oneshot if timeout(1) itself is somehow stuck (Spock D6.2.1).
  # Documented as heartbeatTimeoutSec + 15.
  timeoutStartSec = cfg.heartbeatTimeoutSec + 15;

  watch = pkgs.writeShellApplication {
    name = "court-one-bell-watch";
    runtimeInputs = with pkgs; [
      coreutils # timeout(1) required for heartbeat/alert bound
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

    heartbeatTimeoutSec = mkOption {
      type = types.ints.positive;
      # GUESS: Spock D6.2 — hung ssh/disk must not keep oneshot activating forever.
      default = 30;
      description = ''
        Seconds to wait for heartbeatCommand (and alertCommand) via coreutils
        `timeout`. Exit 124 → UNREACHABLE with detail "timeout" (change-only).
        GUESS default 30. Court may retune.
        systemd TimeoutStartSec is set to heartbeatTimeoutSec + 15 (GUESS) so the
        oneshot cannot outlive a stuck timeout wrapper.
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
        Double-gated with feeder (leave as-is per Spock).
      '';
    };

    clockSkewSec = mkOption {
      type = types.ints.positive;
      # GUESS: age < -60 → CLOCK skew change-only line instead of silent clamp.
      default = 60;
      description = ''
        If (now - feeder_last_run) < -clockSkewSec, emit change-only
        "CLOCK skew <n>s" (enter) / "CLOCK ok" (leave). Smaller negative ages
        still clamp silently to 0 for STALE/FRESH. GUESS default 60.
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

    user = mkOption {
      type = types.str;
      default = "court-one-bell";
      description = ''
        Dedicated system user the oneshot runs as (not root). Court will give
        this user its own ssh identity for heartbeatCommand. Default
        "court-one-bell". Module creates users.users.''${user} + matching group
        and owns /var/lib/court-one-bell.
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
        Bounded by the same heartbeatTimeoutSec so a hung alert cannot freeze
        the watcher. Nikola does not write the alert sink; no tokens in this flake.
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

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      description = "Court one-bell external bus heartbeat watcher";
      home = "/var/lib/court-one-bell";
      createHome = false; # owned via tmpfiles / StateDirectory
    };
    users.groups.${cfg.user} = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/court-one-bell 0750 ${cfg.user} ${cfg.user} -"
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
        COURT_ONE_BELL_HEARTBEAT_TIMEOUT_SEC = toString cfg.heartbeatTimeoutSec;
        COURT_ONE_BELL_STALE_AFTER_SEC = toString cfg.staleAfterSec;
        COURT_ONE_BELL_SOURCE_FAILING_RUNS = toString cfg.sourceFailingRuns;
        COURT_ONE_BELL_CLOCK_SKEW_SEC = toString cfg.clockSkewSec;
        COURT_ONE_BELL_LOG_PATH = cfg.logPath;
        COURT_ONE_BELL_STATE_PATH = cfg.statePath;
        COURT_ONE_BELL_ALERT_CMD = cfg.alertCommand;
      };
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.user;
        ExecStart = "${watch}/bin/court-one-bell-watch";
        # GUESS: heartbeatTimeoutSec + 15 — a little above the timeout(1) bound
        # so systemd can still stop a wedged oneshot; timer can then re-fire.
        TimeoutStartSec = timeoutStartSec;
        # StateDirectory ensures /var/lib/court-one-bell exists and is owned by User=
        # even if tmpfiles raced; complements the tmpfiles rule above.
        StateDirectory = "court-one-bell";
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
