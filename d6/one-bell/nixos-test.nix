# D6.2 — nixosTest: one-bell fan-in + timer (no Persistent=true)
# Author: Nikola
#
# Nested KVM on Nikola’s Grok Bot VM is often broken; if the driver crashes here,
# keep d6-one-bell-eval green and re-run this check on the Court rig:
#
#   nix build -L .#checks.x86_64-linux.d6-one-bell
#
# Proves:
#   1. oneshot service runs and writes the stream
#   2. present source → OK line; absent source → MISSING line (fail-closed)
#   3. timer unit exists and does NOT assign Persistent=true
#   4. service unit is Type=oneshot and does not assign Persistent=true

{ pkgs, ... }:
pkgs.nixosTest {
  name = "nikola-d6-one-bell";

  nodes.machine =
    { ... }:
    {
      imports = [ ./module.nix ];

      # Short onBoot; long interval — test starts oneshot directly.
      court.oneBell = {
        enable = true;
        sourceFiles = [
          "/var/lib/court-one-bell-test/present.status"
          "/var/lib/court-one-bell-test/absent.status"
        ];
        streamPath = "/var/lib/court-one-bell/bell.log";
        interval = "1h";
        onBootSec = "2s";
        debounceSec = 0;
      };

      # Seed the present source before first tick; absent path intentionally omitted.
      systemd.tmpfiles.rules = [
        "d /var/lib/court-one-bell-test 0755 root root -"
        "f /var/lib/court-one-bell-test/present.status 0644 root root - handshake_age=42"
      ];
    };

  testScript = ''
    import re

    machine.wait_for_unit("multi-user.target")

    # Units must not assign Persistent=true (Eli). Match assignment lines only.
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

    # Force one fan-in run (do not wait on OnBootSec alone).
    machine.succeed("systemctl start court-one-bell.service")
    machine.wait_until_succeeds("test -f /var/lib/court-one-bell/bell.log", timeout=30)

    stream = machine.succeed("cat /var/lib/court-one-bell/bell.log")
    assert "BEGIN" in stream and "END" in stream
    assert "OK source=/var/lib/court-one-bell-test/present.status" in stream
    assert "handshake_age=42" in stream
    assert "MISSING source=/var/lib/court-one-bell-test/absent.status" in stream
    assert "status=absent" in stream

    # Timer should be active (waiting).
    machine.succeed("systemctl is-active court-one-bell.timer")
  '';
}
