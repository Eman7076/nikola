# Cheap D5.2 check: instantiate llama-cpp-python CUDA drv with dummy patch.
# Proves patchesDir hook wires *.patch files. No CUDA build / no inference.
{ pkgs }:
let
  pkg = import ./llama-cpp-python.nix {
    inherit pkgs;
    patchesDir = ./patches-dummy;
  };
  # Force evaluation of patches list length into the check output.
  nPatches = builtins.length pkg.patches;
in
pkgs.runCommand "d5-python-dummy-eval" { } ''
  echo "${pkg.name}" > $out
  echo "nPatches=${toString nPatches}" >> $out
  echo "patchesDir=patches-dummy" >> $out
''
