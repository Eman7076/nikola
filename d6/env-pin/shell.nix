# D6.3 — Court / Conscia env-pin scaffold (first cut).
# Pitch idea 3: recreate "env that loads models" as nix develop against a pin.
#
# Composes with D5.5 llama-cuda shell via inputsFrom — does NOT duplicate
# llama-cpp-python.nix, CUDAARCHS, or the driver shim body.
# Weights stay out of the store. Secrets / Calypso stay out of this tree.
#
# Imported by flake with pkgsCuda (allowUnfree) — same as D5.
# Nikola VM: no NVIDIA; shell name must evaluate; GPU offload is rig-only.
{ pkgs }:
let

  # Reuse D5 shell wholesale for packages (python+llama_cpp, llama-server,
  # cudatoolkit, pciutils, nvtop, court-llama-env). Relative paths inside
  # d5/shell.nix resolve against d5/.
  d5Shell = import ../../d5/shell.nix { inherit pkgs; };

  # Court inventory hook — empty until Court lists live deps.
  extraPythonDeps = import ./extra-python-deps.nix { inherit pkgs; };

  # Optional tip env for Court-listed extras only. First cut: empty list →
  # still build a withPackages so the hook is wired and evaluate-able.
  # When Court fills deps, this becomes the place to `nix develop` smoke them
  # alongside D5's llama python (two pythons until a later unified cut).
  extraPythonEnv = pkgs.python3.withPackages (ps: extraPythonDeps ps);

  # Same driver-shim fragment D5.5 uses (do not vendor a second copy of logic).
  driverShimLib = pkgs.writeText "court-cuda-driver-shim.sh" (
    builtins.readFile ../../d5/court-cuda-driver-shim.sh
  );

  # Documented patch dir contract (House patches land under d5/patches/).
  patchesDirHint = ../../d5/patches;
in
pkgs.mkShell {
  name = "nikola-d6-court-env";

  # Pull D5 CUDA python + toolkit + shim wrapper without re-declaring them.
  inputsFrom = [ d5Shell ];

  packages = [
    # Placeholder surface: Court extras env (may be empty packages tip).
    extraPythonEnv
  ];

  # Surface for Court/docs/CI: CUDA arch string already set by D5 package build;
  # echo here so operators see the pin without reading d5/llama-cpp-python.nix.
  # Fact for nixpkgs 25.05: cmakeCudaArchitecturesString includes 89 / 120.
  PASS_THRU_CUDAARCHS = pkgs.cudaPackages.flags.cmakeCudaArchitecturesString;

  # Path string only — does not copy patch contents into the store as weights.
  COURT_LLAMA_PATCHES_DIR = toString patchesDirHint;

  shellHook = ''
    # D5.5 lesson: driver libs from host, never whole /usr/lib.
    # shellcheck source=/dev/null
    source ${driverShimLib}
    court_cuda_driver_shim_setup || true

    echo "D6.3 court-env (scaffold / first cut — incomplete on purpose)"
    echo "  Serves: novacourt; Conscia when lit; Igris local body"
    echo "  Base: D5.5 llama-cuda via inputsFrom (JamePeng 0.3.49 + driver shim)"
    echo "  Patches dir (House → Court): $COURT_LLAMA_PATCHES_DIR"
    echo "  CUDAARCHS (from nixpkgs pin): $PASS_THRU_CUDAARCHS"
    echo "  Extra Python deps: d6/env-pin/extra-python-deps.nix (empty until Court inventory)"
    echo "  NOT pinned: model weights, secrets, Calypso, live conda freeze"
    echo "  Try (rig): python -c 'import llama_cpp; print(llama_cpp.__version__, llama_cpp.llama_supports_gpu_offload())'"
    echo "  VM note: no NVIDIA here — eval ≠ GPU offload proof"
  '';
}
