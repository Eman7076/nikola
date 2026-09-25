# D5.6 — JamePeng llama-cpp-python 0.4.0 CUDA shell + Arch NVIDIA driver shim.
# Imported by flake with a pkgs set that has config.allowUnfree = true
# (CUDA toolkit is unfree). Do not use the flake's default pkgs here.
#
# Target (fact from Court): Arch + proprietary NVIDIA driver.
# Text for Spock/Eli on the rig — Nikola's sandbox VM has no NVIDIA GPU
# (shim logic is unevaluated against a real driver here).
{ pkgs }:
let
  llamaCuda = pkgs.llama-cpp.override { cudaSupport = true; };
  llamaCppPython = import ./llama-cpp-python.nix {
    inherit pkgs;
    patchesDir = ./patches;
  };
  # python3 with llama-cpp-python on site-packages (in-process bindings).
  pythonEnv = pkgs.python3.withPackages (_ps: [ llamaCppPython ]);

  # Shared bash fragment (sourceable). writeText so shellHook can `source` it.
  driverShimLib = pkgs.writeText "court-cuda-driver-shim.sh" (
    builtins.readFile ./court-cuda-driver-shim.sh
  );

  # Wrapper: set up shim then exec the given command (scripted / one-shot use).
  courtLlamaEnv = pkgs.writeShellScriptBin "court-llama-env" ''
    # shellcheck source=/dev/null
    source ${driverShimLib}
    court_cuda_driver_shim_setup || true
    if [ "$#" -eq 0 ]; then
      echo "usage: court-llama-env <command> [args...]" >&2
      echo "  example: court-llama-env python -c 'import llama_cpp; print(llama_cpp.llama_supports_gpu_offload())'" >&2
      exit 2
    fi
    exec "$@"
  '';
in
pkgs.mkShell {
  name = "nikola-d5-llama-cuda";

  packages = [
    pythonEnv
    llamaCuda # llama-cli / llama-server (HTTP model serve — keep)
    # Merged toolkit (cuda-merged-* on 25.05); setup hooks set CUDA_PATH.
    pkgs.cudaPackages.cudatoolkit
    pkgs.pciutils
    pkgs.nvtopPackages.nvidia
    courtLlamaEnv
  ];

  shellHook = ''
    # D5.5: make host NVIDIA driver visible to nix-built libggml-cuda.so.
    # shellcheck source=/dev/null
    source ${driverShimLib}
    court_cuda_driver_shim_setup || true

    echo "D5.6 llama-cuda: python (JamePeng llama_cpp 0.4.0) + llama-server (GGML_CUDA)."
    echo "  Src: JamePeng fork @ 0.4.0 (5c83af7) with fetchSubmodules (vendor/llama.cpp)."
    echo "  Patches: d5/patches/*.patch (two-patch contract: logits_all_draft + stopping_word; clean_continuation upstream in 0.4.0)."
    echo "  Driver shim: auto on enter; or: court-llama-env <cmd>  (driver libs only)."
    echo "  Try: python -c 'import llama_cpp; print(llama_cpp.__version__, llama_cpp.llama_supports_gpu_offload())'"
    echo "  Try: llama-server -m /path/to/model.gguf -ngl 99  # -ngl guess: offload all layers"
  '';
}
