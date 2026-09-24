# D5.2 — JamePeng llama-cpp-python 0.3.49 src (submodules) + CUDA + patches/.
# Author: Nikola
#
# Stock nixpkgs 25.05 ships abetlen llama-cpp-python 0.3.9. House runs the
# JamePeng fork at 0.3.49; House patches (clean_continuation, logits_all_draft,
# stopping_word) target that tree. Override src only — keep cudaSupport,
# CUDAARCHS, and patchesDir hook.
#
# SUBMODULES (fact): the fork vendors llama.cpp at vendor/llama.cpp via a git
# submodule. fetchFromGitHub MUST set fetchSubmodules = true or the build has
# no C++ tree (scikit-build finds an empty vendor/).
#
# TAG PIN (fact): JamePeng publishes no plain v0.3.49 tag. All platform release
# tags (v0.3.49-cu128-linux-20260831, …) point at the same commit below.
# We pin that rev explicitly.
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

  # JamePeng 0.3.49 — shared tip of all v0.3.49-* release tags (2026-08-31).
  jamePengRev = "34c1bfbce3ad485d31e67039fa9200e6ab49882e";

  llamaPyCuda = (pkgs.python3Packages.llama-cpp-python.override { cudaSupport = true; }).overrideAttrs (
    old: {
      pname = old.pname or "llama-cpp-python";
      version = "0.3.49";
      src = pkgs.fetchFromGitHub {
        owner = "JamePeng";
        repo = "llama-cpp-python";
        rev = jamePengRev;
        hash = "sha256-IxxpnOCp+Pi5h9fP0BTp3GAQSs+oSM36zul7jWGFMMU=";
        # REQUIRED: vendor/llama.cpp is a git submodule (ggml-org/llama.cpp).
        fetchSubmodules = true;
      };
      patches = (old.patches or [ ]) ++ patchFiles;
      # CMake 3.24+ — semicolon-separated arch list (incl. 89, 120 on this pin).
      CUDAARCHS = arches;
    }
  );
in
llamaPyCuda
