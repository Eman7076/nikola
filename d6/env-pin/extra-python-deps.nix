# D6.3 — placeholder hook for Court-listed Python deps (Conscia / Igris / Court organs).
#
# Returns a function: pythonPackages → [ package … ]
# First cut: EMPTY on purpose. Nikola does not invent a pip freeze.
# Court inventories live conda/pip truth on the rig, then fills this list
# (or replaces it with a generated overlay). Do not vendor model weights here.
#
# Examples of what Court might eventually list (GUESS labels only — not pinned):
#   - vLLM / transformers / torch CUDA stack for Conscia Blackwells
#   - sherpa-onnx / Piper bindings for speech
#   - House-adjacent helpers that today live in a conda env
#
# Until Court names packages + versions, keep this empty so `nix develop .#court-env`
# still evaluates without pretending completeness.
{ pkgs }:
_pythonPackages:
[
  # Court fills real pins below. Leave commented until measured on the rig.
  # _pythonPackages.numpy  # already via D5 llama stack — example only
]
