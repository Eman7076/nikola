# D5.1 — llama-cpp-python CUDA + patches/ (rig)

**Court Contract 001 · Deliverable D5.1** (addresses Spock’s D5 review)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

House loads models **in-process** via Python bindings (Poet, Familiar, Spockette). Spock: D5 shipped C++ `llama-cpp` binaries only — wrong target. D5.1 adds **`llama-cpp-python`** with **CUDA** and a **`d5/patches/`** hook applied before build. Keeps **`llama-server`** in the same shell (one model served over HTTP).

Text/Nix for Spock/Eli to apply — Nikola does not SSH to Court machines and this Grok Bot VM has **no NVIDIA GPU** (no CUDA inference was run here).

## What you get

| Item | Notes |
|------|--------|
| `python` + `llama_cpp` | `pkgs.python3Packages.llama-cpp-python.override { cudaSupport = true; }` + local patches + `CMAKE_CUDA_ARCHITECTURES` (incl. **89 / 120**) |
| `llama-cli` / `llama-server` | Still from `pkgs.llama-cpp.override { cudaSupport = true; }` (kept) |
| `cudaPackages.cudatoolkit` | Merged toolkit (CUDA **12.8** on this pin) — setup hooks set `CUDA_PATH` |
| `pciutils` / `nvtop` (nvidia) | Light host helpers |
| `d5/patches/` | Empty by default (`.gitkeep` only). Drop House’s three patches here; rebuild picks them up |

**Flake outputs:**

- `devShells.x86_64-linux.llama-cuda` (primary) / alias `.#d5`
- `packages.x86_64-linux.llama-cpp-python-cuda` — the python package alone (empty `patches/`)
- `checks.x86_64-linux.d5-shell-eval` — shell name instantiate
- `checks.x86_64-linux.d5-python-eval` — python CUDA drv instantiate (**empty** `patches/`)
- `checks.x86_64-linux.d5-python-with-dummy-patch` — same with `d5/patches-dummy/0001-nikola-dummy.patch`

Existing `devShells.default` (sandbox tools) is unchanged.

## Court: drop patches

```bash
# Default tree ships empty patches/ (only .gitkeep). Court copies three local patches:
cp /path/to/house-patches/*.patch d5/patches/
# Rebuild / re-enter shell — overrideAttrs appends every *.patch (sorted) before build.
nix develop .#llama-cuda
```

- Only `*.patch` files are applied (`.gitkeep` ignored).
- Dummy proof lives under **`d5/patches-dummy/`** — do **not** copy it into `patches/` for production; it is only for the `d5-python-with-dummy-patch` check.

## Enter the shell (on the rig)

```bash
nix develop .#llama-cuda
# or:
nix develop .#d5
```

**unfree:** Flake uses a **separate** `pkgsCuda` with `config.allowUnfree = true` **only** for D5 (shell, package, checks). No global `allowUnfree` required for `nix develop .#llama-cuda` from this flake.

## Python smoke (labeled guess)

```bash
# GUESS / smoke only — proves the binding imports. Not an inference claim.
python -c 'import llama_cpp; print(llama_cpp.__version__)'
# Optional: llama_cpp.llama_supports_gpu_offload()  # may reflect build flags; verify on rig
```

## llama-server (kept)

```bash
# GUESS: -ngl 99 ≈ "all layers that fit"; tune down if VRAM OOMs.
llama-server -m /path/to/model.gguf -ngl 99 --host 127.0.0.1 --port 8080
```

```bash
lspci | rg -i 'nvidia|3d|vga'
nvidia-smi          # proprietary driver userspace; not provided by this shell
nvtop               # from the shell
```

## Multi-GPU (rig: 3× NVIDIA — guess)

**GUESS (hardware labels):** typically **2×16GB Blackwell + 1×16GB Ada**. Confirm with `nvidia-smi -L` on the rig.

```bash
# GUESS: even-ish split; flag names drift — check llama-server --help.
llama-server -m /path/to/model.gguf -ngl 99 \
  --tensor-split 1,1,1 \
  --host 127.0.0.1 --port 8080
```

## Driver / Nix CUDA matching

- **Assumption:** Arch host runs the **proprietary** NVIDIA driver (not Nouveau).
- Toolkit major here: **12.8** on nixpkgs 25.05.
- Arch string on this pin includes **75;80;86;89;90;100;120** — **Ada (8.9)** and **Blackwell (12.0)** covered (**fact for this nixpkgs pin**). D5.1 sets `CUDAARCHS` (CMake 3.24+ env) to the same string — stock nixpkgs CUDA python build omitted arch flags; SKBUILD_CMAKE_ARGS cannot embed semicolon-rich values cleanly.
- `cudaSupport` forced via `.override` — Court need not set global `cudaSupport`.

## Honest limitations (Nikola sandbox)

- This VM has **no NVIDIA GPU**. Nikola **evaluated** flake outputs / drvPaths for empty-patches and dummy-patch variants. A **full CUDA build** is multi-GiB and was **not** completed here — do **not** treat eval as “patched wheel built on rig.”
- No CUDA inference, no GGUF downloads, no Court SSH, no secrets in this tree.
- Pinned **nixpkgs 25.05** (same as D1–D4), not Court **26.05**.
- Dummy patch is a **no-op comment** against upstream `llama_cpp/__init__.py` for v0.3.9 — if Court bumps the package version, re-check the dummy hunk.

## Files

| Path | Role |
|------|------|
| `shell.nix` | `mkShell`: python+llama_cpp (CUDA) + llama-server + toolkit |
| `llama-cpp-python.nix` | CUDA override + `patchesDir` hook + arch flags |
| `patches/` | Court drops House patches here (empty + `.gitkeep`) |
| `patches-dummy/0001-nikola-dummy.patch` | Trivial no-op for check only |
| `eval-shell.nix` / `eval-python.nix` / `eval-python-dummy.nix` | Cheap instantiate checks |
| `README.md` | This file |

## Verify (sandbox-safe)

```bash
nix eval .#devShells.x86_64-linux.llama-cuda.drvPath
nix build .#checks.x86_64-linux.d5-shell-eval --no-link
nix build .#checks.x86_64-linux.d5-python-eval --no-link
nix build .#checks.x86_64-linux.d5-python-with-dummy-patch --no-link
# Heavy on a GPU-less box (multi-GiB CUDA):
# nix build .#packages.x86_64-linux.llama-cpp-python-cuda
# nix develop .#llama-cuda --command python -c 'import llama_cpp; print(llama_cpp.__version__)'
```
