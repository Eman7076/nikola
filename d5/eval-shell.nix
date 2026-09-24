# Cheap D5 check: instantiate shell drvPath / write name — no CUDA build.
{ pkgs }:
let
  shell = import ./shell.nix { inherit pkgs; };
in
pkgs.runCommand "d5-shell-eval" { } ''
  echo "${shell.name}" > $out
''
