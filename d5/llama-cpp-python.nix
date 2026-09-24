# D5.1 — llama-cpp-python with CUDA + local patches/ hook.
# Author: Nikola
#
# Prefer stock nixpkgs python3Packages.llama-cpp-python + override
# { cudaSupport = true; }, then overrideAttrs for:
#   - patches from patchesDir (*.patch only; .gitkeep ignored)
#   - CUDAARCHS env = nixpkgs cmakeCudaArchitecturesString (Ada 89 + Blackwell 120)
#
# Why CUDAARCHS (not SKBUILD_CMAKE_ARGS -DCMAKE_CUDA_ARCHITECTURES=…):
# SKBUILD_CMAKE_ARGS is semicolon-separated; the arch string also uses
# semicolons, so embedding it would split into bogus args. CMake 3.24+
# reads CUDAARCHS from the environment (same list). Fact for this pin:
# scikit-build-core pulls in cmake >= 3.31.
#
# Default patchesDir = ./patches (empty for Court). Dummy proof uses
# ./patches-dummy via checks / callers.

{
  pkgs,
  patchesDir ? ./patches,
}:
let
  inherit (pkgs) lib;

  patchFiles =
    let
      entries = builtins.readDir patchesDir;
      names = builtins.filter (n: lib.hasSuffix ".patch" n) (builtins.attrNames entries);
    in
    map (n: patchesDir + "/${n}") (lib.sort (a: b: a < b) names);

  arches = pkgs.cudaPackages.flags.cmakeCudaArchitecturesString;

  llamaPyCuda = (pkgs.python3Packages.llama-cpp-python.override { cudaSupport = true; }).overrideAttrs (
    old: {
      pname = old.pname or "llama-cpp-python";
      patches = (old.patches or [ ]) ++ patchFiles;
      # CMake 3.24+ — semicolon-separated arch list (incl. 89, 120 on this pin).
      CUDAARCHS = arches;
    }
  );
in
llamaPyCuda
