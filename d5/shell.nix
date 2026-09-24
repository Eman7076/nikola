# D5.2 — llama-cpp-python (JamePeng 0.3.49 CUDA) + llama-server (CUDA llama-cpp).
# Imported by flake with a pkgs set that has config.allowUnfree = true
# (CUDA toolkit is unfree). Do not use the flake's default pkgs here.
#
# Target (guess, labeled): Arch + proprietary NVIDIA driver;
# typically 2×16GB Blackwell + 1×16GB Ada. This expression is text for
# Spock/Eli to apply on the rig — Nikola's sandbox VM has no NVIDIA GPU.
{ pkgs }:
let
  llamaCuda = pkgs.llama-cpp.override { cudaSupport = true; };
  llamaCppPython = import ./llama-cpp-python.nix {
    inherit pkgs;
    patchesDir = ./patches;
  };
  # python3 with llama-cpp-python on site-packages (in-process bindings).
  pythonEnv = pkgs.python3.withPackages (_ps: [ llamaCppPython ]);
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
  ];

  # Prefer nixpkgs wrappers + autoAddDriverRunpath. shellHook only reminds;
  # no hand-rolled LD_LIBRARY_PATH unless Court hits a missing-lib on Arch.
  shellHook = ''
    echo "D5.2 llama-cuda: python (JamePeng llama_cpp 0.3.49) + llama-server (GGML_CUDA)."
    echo "  Src: JamePeng fork @ 0.3.49 with fetchSubmodules (vendor/llama.cpp)."
    echo "  Patches: d5/patches/*.patch applied at build (empty by default)."
    echo "  Host: Arch + proprietary NVIDIA driver must match nixpkgs CUDA (see d5/README.md)."
    echo "  Try: python -c 'import llama_cpp; print(llama_cpp.__version__)'  # smoke, labeled"
    echo "  Try: llama-server -m /path/to/model.gguf -ngl 99  # -ngl guess: offload all layers"
  '';
}
