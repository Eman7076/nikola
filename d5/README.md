# D5 — llama.cpp CUDA devShell (rig)

**Court Contract 001 · Deliverable D5 (optional)**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

Optional Nix `devShell` that exposes **llama.cpp built with CUDA** for the Court **rig** (Arch Linux + proprietary NVIDIA). Text/Nix for Spock/Eli to apply — Nikola does not SSH to Court machines and this Grok Bot VM has **no NVIDIA GPU** (no CUDA inference was run here).

## What you get

| Item | Notes |
|------|--------|
| `llama-cli` / `llama` / `llama-server` | From `pkgs.llama-cpp.override { cudaSupport = true; }` (nixpkgs 25.05, llama-cpp ~b5311) |
| `cudaPackages.cudatoolkit` | Merged toolkit (CUDA **12.8** on this pin) — setup hooks set `CUDA_PATH` |
| `pciutils` / `nvtop` (nvidia) | Light host helpers (`lspci`, `nvtop`) |
| Env | Prefer nixpkgs wrappers + `autoAddDriverRunpath` inside the CUDA llama build. No hand-rolled `LD_LIBRARY_PATH` by default. |

**Flake outputs:**

- `devShells.x86_64-linux.llama-cuda` (primary)
- `devShells.x86_64-linux.d5` (alias)
- `checks.x86_64-linux.d5-shell-eval` — instantiates the shell `drvPath` only (no GPU, no full CUDA build required)

Existing `devShells.default` (sandbox tools) is unchanged.

## Enter the shell (on the rig)

```bash
# From this repo, on a machine with Nix + flakes:
nix develop .#llama-cuda
# or:
nix develop .#d5
```

**unfree:** The flake imports a **separate** `pkgsCuda` with `config.allowUnfree = true` **only** for this shell (and its check). Court does **not** need a global `allowUnfree` in `nix.conf` for `nix develop .#llama-cuda` from this flake. If Court re-uses `d5/shell.nix` outside the flake, they must supply a pkgs set with unfree allowed (CUDA toolkit is unfree).

## Example invocations (guesses labeled)

Model path and layer counts are **Court/runtime** — Nikola has no rig inventory of GGUF files.

```bash
# Interactive / one-shot CLI — offload layers to GPU
# GUESS: -ngl 99 ≈ "all layers that fit"; tune down if VRAM OOMs.
llama-cli -m /path/to/model.gguf -ngl 99 -p "Hello from the rig"

# OpenAI-compatible HTTP server (llama-server ships with LLAMA_BUILD_SERVER)
# GUESS: host/port are local-only defaults; bind tighter if exposed on the mesh.
llama-server -m /path/to/model.gguf -ngl 99 --host 127.0.0.1 --port 8080
```

Check the host sees the cards before blaming Nix:

```bash
lspci | rg -i 'nvidia|3d|vga'
nvidia-smi          # proprietary driver userspace; not provided by this shell
nvtop               # from the shell
```

## Multi-GPU (rig: 3× NVIDIA — guess)

**GUESS (hardware labels):** typically **2×16GB Blackwell + 1×16GB Ada**. Confirm with `nvidia-smi -L` on the rig; do not treat these SKUs as certified fact.

Tensor / layer split across GPUs is **Court/runtime config**, not something this shell hard-codes. One clean default tip:

```bash
# GUESS: even-ish split across 3 devices by proportion; adjust to real VRAM.
# llama.cpp flag names drift — check `llama-server --help` on the built binary.
llama-server -m /path/to/model.gguf -ngl 99 \
  --tensor-split 1,1,1 \
  --host 127.0.0.1 --port 8080
```

If mixed Ada/Blackwell behave oddly under one process, Court can pin a single GPU with `CUDA_VISIBLE_DEVICES=0` (or `1` / `2`) for isolation experiments.

## Driver / Nix CUDA matching

- **Assumption:** Arch host runs the **proprietary** NVIDIA driver (not Nouveau).
- Nix CUDA packages expect a **compatible host driver** for the toolkit major (here **12.8** on nixpkgs 25.05). Too-old drivers → runtime failures even when the shell builds cleanly.
- `llama-cpp` with `cudaSupport = true` uses `cudaPackages.flags.cmakeCudaArchitecturesString`. On this pin that includes **75;80;86;89;90;100;120** — so **Ada (8.9)** and **Blackwell (12.0)** are in the default arch list (**fact for this nixpkgs pin**; still verify on rebuild if Court bumps nixpkgs).
- `cudaSupport` defaults from `config.cudaSupport` in nixpkgs; this shell **forces** `cudaSupport = true` via `.override` so Court need not set global `cudaSupport`.

## Honest limitations (Nikola sandbox)

- This VM has **no NVIDIA GPU**. Nikola evaluated the flake output / shell `drvPath`; a **full CUDA llama-cpp build** may be large (toolkit + archs) and was **not** claimed as completed here if too heavy.
- No CUDA inference, no GGUF downloads, no Court SSH, no secrets in this tree.
- Pinned **nixpkgs 25.05** (same as D1–D4), not Court **26.05**.

## Files

| Path | Role |
|------|------|
| `shell.nix` | `mkShell` with CUDA `llama-cpp` + toolkit + light helpers |
| `eval-shell.nix` | Cheap `drvPath` instantiate check |
| `README.md` | This file |

## Verify (sandbox-safe)

```bash
nix eval .#devShells.x86_64-linux.llama-cuda.drvPath
nix build .#checks.x86_64-linux.d5-shell-eval --no-link
# Check only proves the shell *evaluates* (writes shell.name). It does not
# build llama-cpp/CUDA. Optional / heavy on a GPU-less box:
# nix develop .#llama-cuda --command true
```
