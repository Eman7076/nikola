# Pure script proof for the freshness canary (no QEMU).
# Wired as checks.x86_64-linux.d6-freshness-script
{ pkgs }:
pkgs.runCommand "d6-freshness-canary-script" { } ''
  set -euo pipefail
  export PATH="${pkgs.coreutils}/bin:${pkgs.bash}/bin:$PATH"
  cp ${./canary.sh} ./canary.sh
  cp ${./test-canary.sh} ./test-canary.sh
  chmod +x ./canary.sh ./test-canary.sh
  bash ./test-canary.sh | tee $out
''
