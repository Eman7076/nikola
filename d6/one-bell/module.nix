# D6.2 — Court one-bell NixOS module
# Author: Nikola (Court Contract 001)
#
# Fan-in of Court-configured source *files* into one append-only stream.
# Feeds the existing sentinel/dead-man — does NOT install a second watchdog daemon
# or any alert sink. No Persistent=true on timer or service (Eli constraint).
#
# Court points the dead-man at court.oneBell.streamPath (see d6/02-one-bell.md).

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

  fanIn = pkgs.writeShellApplication {
    name = "court-one-bell-fan-in";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      gawk
    ];
    # Strip the shebang from the checked-in script; writeShellApplication adds its own.
    text = lib.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (builtins.readFile ./fan-in.sh);
  };

  sourcesFile = pkgs.writeText "court-one-bell-sources.txt" (
    lib.concatMapStrings (p: p + "\n") cfg.sourceFiles
  );
in
{
  options.court.oneBell = {
    enable = mkEnableOption "Court one-bell fan-in (oneshot + timer → stream for existing dead-man)";

    sourceFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "/var/lib/court-signals/mesh.status"
        "/var/lib/court-signals/disk.free"
      ];
      description = ''
        Absolute paths of source *files* Court maintains. Each file contributes one
        status line per tick. Missing/unreadable → MISSING line in the stream
        (fail-closed, measurable). No silent skip.
      '';
    };

    streamPath = mkOption {
      type = types.str;
      default = "/var/lib/court-one-bell/bell.log";
      description = "Append-only stream path the existing dead-man/sentinel should watch.";
    };

    interval = mkOption {
      type = types.str;
      default = "5min";
      example = "2min";
      description = ''
        Duration for OnUnitActiveSec (re-arm after each oneshot). Paired with
        OnBootSec so the first tick is soon after boot. Persistent=true is never set.
      '';
    };

    onBootSec = mkOption {
      type = types.str;
      default = "1min";
      description = "Delay after boot before the first oneshot (OnBootSec).";
    };

    debounceSec = mkOption {
      type = types.ints.unsigned;
      default = 0;
      description = ''
        If >0 and the OK/MISSING core payload is identical to the last block, skip
        appending when the stream mtime is newer than this many seconds. 0 = always append.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d /var/lib/court-one-bell 0750 root root -"
    ];

    systemd.services.court-one-bell = {
      description = "Court one-bell fan-in (feed existing dead-man; not a second watchdog)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${fanIn}/bin/court-one-bell-fan-in";
        Environment = [
          "COURT_ONE_BELL_STREAM=${cfg.streamPath}"
          "COURT_ONE_BELL_DEBOUNCE_SEC=${toString cfg.debounceSec}"
          "COURT_ONE_BELL_SOURCES_FILE=${sourcesFile}"
        ];
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
        # after suspend/AFK we do *not* want a burst of catch-up bells. The existing
        # dead-man should notice stream staleness (mtime / last END age) instead of
        # consuming a Persistent backlog. Eli: no Persistent=true ever on these units.
      };
    };
  };
}
