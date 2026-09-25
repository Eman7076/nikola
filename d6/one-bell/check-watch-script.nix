# Pure script proof for revised one-bell watch (no QEMU).
# Wired as checks.x86_64-linux.d6-one-bell-script
{ pkgs }:
pkgs.runCommand "d6-one-bell-watch-script" { } ''
  set -euo pipefail
  export PATH="${pkgs.coreutils}/bin:${pkgs.bash}/bin:${pkgs.jq}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:$PATH"
  cp ${./watch.sh} ./watch.sh
  cp ${./test-watch.sh} ./test-watch.sh
  chmod +x ./watch.sh ./test-watch.sh
  bash ./test-watch.sh | tee $out
''
