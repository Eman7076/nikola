# Pure script proof for c002 stick checker (no QEMU).
# Wired as checks.x86_64-linux.c002-stick-check
{ pkgs }:
pkgs.runCommand "c002-stick-check" { } ''
  set -euo pipefail
  export PATH="${pkgs.coreutils}/bin:${pkgs.bash}/bin:${pkgs.gnugrep}/bin:$PATH"
  cp ${./check-stick.sh} ./check-stick.sh
  cp ${./check-stick-test.sh} ./check-stick-test.sh
  cp ${./manifest.example.txt} ./manifest.example.txt
  chmod +x ./check-stick.sh ./check-stick-test.sh
  bash ./check-stick-test.sh | tee $out
''
