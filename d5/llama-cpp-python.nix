# D5.6 — JamePeng 0.4.0 src bump; D5.4 HF-download tests disabled; D5.3 Pillow via PBI.
# Author: Nikola
#
# Stock nixpkgs 25.05 ships abetlen llama-cpp-python 0.3.9. House runs the
# JamePeng fork. D5.2–D5.5 pinned 0.3.49 @ 34c1bfb. D5.6 moves to 0.4.0
# (Court 2026-09-25: house wheel 0.3.49 → 0.4.0 cu131; clean_continuation
# now upstream). Override src only — keep cudaSupport, CUDAARCHS, patchesDir,
# driver shim (shell), Pillow PBI, sandbox-safe disabledTests.
#
# SUBMODULES (fact): the fork vendors llama.cpp at vendor/llama.cpp via a git
# submodule. fetchFromGitHub MUST set fetchSubmodules = true or the build has
# no C++ tree (scikit-build finds an empty vendor/).
#
# TAG PIN (fact, 2026-09-25): no plain `v0.4.0` tag on the remote. All
# `v0.4.0-*` platform tags (incl. `v0.4.0-cu131-linux-20260919`, matching
# Court’s published cu131 wheel line) point at the same commit below.
# `__version__` in tree is `"0.4.0"`. Court named “tag v0.4.0”; we pin that
# shared rev.
#
# PATCH CONTRACT (fact, Court 2026-09-25): clean_continuation is upstream in
# 0.4.0 (prefix-match branch has its own else). Remaining House patches to
# land under d5/patches/: logits_all_draft, stopping_word — two, not three.
# See d5/patches/README.md.
#
# Why CUDAARCHS (not SKBUILD_CMAKE_ARGS -DCMAKE_CUDA_ARCHITECTURES=…):
# SKBUILD_CMAKE_ARGS is semicolon-separated; the arch string also uses
# semicolons, so embedding it would split into bogus args. CMake 3.24+
# reads CUDAARCHS from the environment (same list). Fact for this pin:
# scikit-build-core pulls in cmake >= 3.31.
#
# Default patchesDir = ./patches (empty for Court until House drops the two
# remaining diffs). Dummy proof uses ./patches-dummy via checks / callers.

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

  # JamePeng 0.4.0 — shared tip of all v0.4.0-* release tags (2026-09-19).
  jamePengRev = "5c83af7dcfed4ffdd6bda791835d92698c90a398";

  llamaPyCuda = (pkgs.python3Packages.llama-cpp-python.override { cudaSupport = true; }).overrideAttrs (
    old: {
      pname = old.pname or "llama-cpp-python";
      version = "0.4.0";
      src = pkgs.fetchFromGitHub {
        owner = "JamePeng";
        repo = "llama-cpp-python";
        rev = jamePengRev;
        hash = "sha256-nxLy/hxfdxFToHihGTqbKIwBofCH5wnessvUQkKenh0=";
        # REQUIRED: vendor/llama.cpp is a git submodule (ggml-org/llama.cpp).
        fetchSubmodules = true;
      };
      patches = (old.patches or [ ]) ++ patchFiles;
      # D5.3: fork pyproject needs Pillow>=9.5.0; stock 0.3.9 recipe omits it.
      # Fact: overrideAttrs on `dependencies` does NOT stick on this recipe —
      # append pillow to propagatedBuildInputs (what lands in the check env).
      propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [
        pkgs.python3Packages.pillow
      ];
      # D5.4: sandbox has no network — same three HF-download ERROR class as
      # 0.3.49. Fact (0.4.0 tree @ 5c83af7): names unchanged; they now live in
      # tests/test_runtime.py (was tests/test_llama.py on 0.3.49). disabledTests
      # matches by name. Keep doCheck on so the rest still run.
      disabledTests = (old.disabledTests or [ ]) ++ [
        "test_grammar_sampling_safety"
        "test_logit_bias"
        "test_custom_logits_processor"
      ];
      # CMake 3.24+ — semicolon-separated arch list (incl. 89, 120 on this pin).
      CUDAARCHS = arches;
    }
  );
in
llamaPyCuda
