# Cheap D6.3 check: instantiate court-env shell name only — no CUDA build, no GPU.
# Wired as checks.x86_64-linux.d6-env-pin-eval
# Caller must pass pkgsCuda (allowUnfree) — same as d5-shell-eval.
{ pkgs }:
let
  shell = import ./shell.nix { inherit pkgs; };
in
pkgs.runCommand "d6-env-pin-eval" { } ''
  echo "${shell.name}" > $out
''
