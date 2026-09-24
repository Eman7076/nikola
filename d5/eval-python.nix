# Cheap D5.2 check: instantiate llama-cpp-python CUDA drv (empty patches/).
# Does NOT build CUDA / does NOT run inference.
{ pkgs }:
let
  pkg = import ./llama-cpp-python.nix {
    inherit pkgs;
    patchesDir = ./patches;
  };
in
pkgs.runCommand "d5-python-eval" { } ''
  echo "${pkg.name}" > $out
  echo "patches=empty-default" >> $out
''
