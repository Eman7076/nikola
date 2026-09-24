# Cheap check: force-evaluate the D5 CUDA shell expression (name only).
# Does NOT realize CUDA toolkit / llama-cpp — safe on a GPU-less sandbox.
# Wired as checks.x86_64-linux.d5-shell-eval
{ pkgs }:
let
  shell = import ./shell.nix { inherit pkgs; };
  # mkShell .name is a plain string (no derivation string context).
  # Do NOT interpolate shell.drvPath / shell here — that carries context and
  # forces `nix build` to realize the full CUDA + llama-cpp closure.
  proof = "d5-shell-eval-ok name=${shell.name}";
in
pkgs.writeText "d5-shell-eval" proof
