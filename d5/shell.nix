# D5 — optional llama.cpp CUDA devShell for the Arch rig.
# Imported by flake with a pkgs set that has config.allowUnfree = true
# (CUDA toolkit is unfree). Do not use the flake's default pkgs here.
#
# Target (guess, labeled): Arch + proprietary NVIDIA driver;
# typically 2×16GB Blackwell + 1×16GB Ada. This expression is text for
# Spock/Eli to apply on the rig — Nikola's sandbox VM has no NVIDIA GPU.
{ pkgs }:
let
  llamaCuda = pkgs.llama-cpp.override { cudaSupport = true; };
in
pkgs.mkShell {
  name = "nikola-d5-llama-cuda";

  packages = [
    llamaCuda
    # Merged toolkit (cuda-merged-* on 25.05); setup hooks set CUDA_PATH.
    pkgs.cudaPackages.cudatoolkit
    pkgs.pciutils
    pkgs.nvtopPackages.nvidia
  ];

  # Prefer nixpkgs wrappers + autoAddDriverRunpath (wired inside llama-cpp
  # when cudaSupport=true). shellHook only reminds; no hand-rolled
  # LD_LIBRARY_PATH unless Court hits a missing-lib on the Arch host.
  shellHook = ''
    echo "D5 llama-cuda: llama-cli / llama-server (GGML_CUDA)."
    echo "  Host: Arch + proprietary NVIDIA driver must match nixpkgs CUDA (see d5/README.md)."
    echo "  Try: llama-server -m /path/to/model.gguf -ngl 99  # -ngl guess: offload all layers"
  '';
}
