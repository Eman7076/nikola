# D6.2 — nixosTest: one-bell external bus watcher (no Persistent=true)
# Author: Nikola
#
# Nested KVM on Nikola’s Grok Bot VM is often broken; if the driver crashes here,
# keep d6-one-bell-eval + d6-one-bell-script green and re-run this check on the
# Court rig:
#
#   nix build -L .#checks.x86_64-linux.d6-one-bell
#
# Proves:
#   1. oneshot runs with fake heartbeatCommand (fresh → silent; then stale → one line)
#   2. timer unit exists and does NOT assign Persistent=true
#   3. service unit is Type=oneshot

{ pkgs, ... }:
pkgs.nixosTest {
  name = "nikola-d6-one-bell";

  nodes.machine =
    { pkgs, ... }:
    let
      # Tiny helpers written into the store; Court would pass ssh — we pass cat.
      hbFresh = pkgs.writeText "hb-fresh.json" ''
        {"feeder_last_run": 9999999999,
         "sources": {"igris-note": {"status": "ok", "fails": 0, "last_ok": 9999999999, "last_error": ""}}}
      '';
      hbStale = pkgs.writeText "hb-stale.json" ''
        {"feeder_last_run": 1,
         "sources": {"igris-note": {"status": "ok", "fails": 0, "last_ok": 1, "last_error": ""}}}
      '';
    in
    {
      imports = [ ./module.nix ];

      # Point heartbeatCommand at a mutable path the test rewrites between ticks.
      court.oneBell = {
        enable = true;
        heartbeatCommand = "cat /var/lib/court-one-bell-test/heartbeat.json";
        staleAfterSec = 300; # GUESS
        sourceFailingRuns = 3; # GUESS
        interval = "1h";
        onBootSec = "2s"; # GUESS-ish short for test boot; production default 30s
        logPath = "/var/lib/court-one-bell/watch.log";
        statePath = "/var/lib/court-one-bell/watch.state";
        alertCommand = "";
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/court-one-bell-test 0755 root root -"
        "C /var/lib/court-one-bell-test/heartbeat.json 0644 root root - ${hbFresh}"
        "C /var/lib/court-one-bell-test/hb-stale.json 0644 root root - ${hbStale}"
      ];
    };

  testScript = ''
    import re

    machine.wait_for_unit("multi-user.target")

    machine.fail(
        "grep -E '^Persistent= *(true|yes)' "
        "/etc/systemd/system/court-one-bell.timer "
        "/etc/systemd/system/court-one-bell.service "
        "2>/dev/null"
    )
    timer_text = machine.succeed("systemctl cat court-one-bell.timer")
    assert not re.search(r"(?m)^Persistent=(true|yes)\\b", timer_text), (
        "timer must not set Persistent=true"
    )
    svc_text = machine.succeed("systemctl cat court-one-bell.service")
    assert not re.search(r"(?m)^Persistent=(true|yes)\\b", svc_text)
    assert "Type=oneshot" in svc_text

    # Tick 1: fresh → silent (no log lines / empty or absent log ok).
    machine.succeed("systemctl start court-one-bell.service")
    machine.succeed("test -f /var/lib/court-one-bell/watch.state")
    # Log may be absent or empty.
    log1 = machine.succeed(
        "test -f /var/lib/court-one-bell/watch.log && cat /var/lib/court-one-bell/watch.log || true"
    )
    assert "FEEDER stale" not in log1
    assert "FEEDER unreachable" not in log1

    # Tick 2: swap to stale heartbeat → one STALE line.
    machine.succeed(
        "cp /var/lib/court-one-bell-test/hb-stale.json "
        "/var/lib/court-one-bell-test/heartbeat.json"
    )
    machine.succeed("systemctl start court-one-bell.service")
    log2 = machine.succeed("cat /var/lib/court-one-bell/watch.log")
    assert "FEEDER stale" in log2
    stale_count = log2.count("FEEDER stale")
    assert stale_count == 1, f"expected one stale line, got {stale_count}: {log2!r}"

    # Tick 3: still stale → silent (still one line).
    machine.succeed("systemctl start court-one-bell.service")
    log3 = machine.succeed("cat /var/lib/court-one-bell/watch.log")
    assert log3.count("FEEDER stale") == 1

    machine.succeed("systemctl is-active court-one-bell.timer")
  '';
}
