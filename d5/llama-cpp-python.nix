# D5.4 — disable HF-download tests; D5.3 Pillow via PBI; D5.2 JamePeng src.
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
      # D5.3: fork pyproject needs Pillow>=9.5.0; stock 0.3.9 recipe omits it.
      # Fact: recipe declares `dependencies = [ diskcache jinja2 numpy typing-extensions ]`
      # and buildPythonPackage mirrors those into propagatedBuildInputs (+ python3).
      # Fact (measured on this pin): overrideAttrs on `dependencies` does NOT stick —
      # evaluated drv.dependencies stays the original four. Append pillow to
      # propagatedBuildInputs instead; that is what lands in the check env
      # (pythonRuntimeDepsCheckHook failed Court with "pillow not installed").
      propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [
        pkgs.python3Packages.pillow
      ];
      # D5.4: Court CUDA build — 82 passed, 3 ERROR (LocalEntryNotFoundError).
      # Those three pull a GGUF via huggingface_hub at test time; nix sandbox
      # has no network. Stock recipe already disables test_real_model /
      # test_real_llama for the same class. Append the three that failed;
      # keep doCheck on so the other ~82 still run (Spock preference).
      # Fact (fork tree @ 34c1bfb): all three live in tests/test_llama.py and
      # take the llama_cpp_model_path fixture.
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
