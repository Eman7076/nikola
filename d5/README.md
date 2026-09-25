# D5.6 — JamePeng 0.4.0 CUDA pin (Arch driver shim kept)

**Court Contract 001 · Deliverable D5.6** (0.4.0 src bump; builds on accepted D5.5 / D5.5.1)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

House loads models **in-process** via Python bindings (Poet, Familiar, Spockette). Spock: D5 shipped C++ `llama-cpp` binaries only — wrong target. D5.1 added **`llama-cpp-python`** with **CUDA** and a **`d5/patches/`** hook. **D5.2** overrides **`src`** to the **JamePeng fork** at **0.3.49** (House’s tree) so House patches can apply. Keeps **`llama-server`** in the same shell.

**D5.3:** Court's real CUDA build on the rig compiled the fork wheel (~7.5 min) then failed only at `pythonRuntimeDepsCheckHook` (`pillow not installed`). Stock recipe deps stayed at 0.3.9's four packages. **Fact:** `overrideAttrs` on `dependencies` does not stick on this pin; append `pillow` to **`propagatedBuildInputs`** (recipe already mirrors the four into PBI).

**D5.4:** Court build passed runtime-deps then failed checkPhase: 82 passed, 3 ERROR (`LocalEntryNotFoundError` from huggingface_hub — sandbox has no network). Appended `test_grammar_sampling_safety`, `test_logit_bias`, `test_custom_logits_processor` to `disabledTests` (same idiom as stock `test_real_model` / `test_real_llama`). Left `doCheck` on so the rest still run.

**D5.5:** Court measured `llama_supports_gpu_offload()` False with bare nix python because `libggml-cuda.so` resolved `libcuda.so.1` to the nixpkgs **stub**. True when a directory of **driver-only** symlinks from `/usr/lib` (`libcuda`, `libnvidia-ptxjitcompiler`, `libnvidia-ml`, `libnvidia-nvvm`) is prepended to `LD_LIBRARY_PATH`. Do **not** put all of `/usr/lib` (Court: nix python then loads Arch glibc → `GLIBC_PRIVATE`). D5.5 adds a `shellHook` shim (NixOS `/run/opengl-driver/lib` if present, else Arch shim under `$XDG_RUNTIME_DIR`) plus `court-llama-env` wrapper. **Package unchanged.**

**D5.5 accepted on the rig (FACT, Court 2026-09-24 ~22:40):** `nix develop .#llama-cuda` → import `0.3.49`, offload **True**; `ggml_cuda_init` saw all three cards (5070 Ti, 4060 Ti, 5060 Ti). Same shell with `LD_LIBRARY_PATH` cleared → offload **False** (negative control). `court-llama-env` on that cleared env → offload **True** again; driver libs only; sweeps old links first.

**D5.5.1 (prior):** Court found the shim printed "24 links" while the directory held **12**, because on Arch `/usr/lib64` is a symlink to `/usr/lib` and the loop linked every file twice (`ln -sfn` overwrote). Harmless but the count lied ×2. Shim now dedupes search roots by `realpath` and reports the **final** link count in the shim directory. Still untestable for GPU offload on Nikola’s VM (no NVIDIA).

**D5.6 (this commit):** Court moved the house wheel **0.3.49 → 0.4.0** (JamePeng cu131 cp312; sha256 matched the release digest; patched 0.3.49 backed up). Nikola’s pin follows: `src` → rev `5c83af7` (shared tip of all `v0.4.0-*` tags; **FACT:** no plain `v0.4.0` tag on the remote as of 2026-09-25). `fetchSubmodules = true` kept. Driver-only shim **unchanged** (accepted D5.5 / D5.5.1). Patch contract: **`clean_continuation` is upstream** in 0.4.0 (Court); `d5/patches/` now expects **two** remaining House diffs (`logits_all_draft`, `stopping_word`), not three. See [`patches/README.md`](./patches/README.md).

**Court-measured on the rig (FACT, 2026-09-25 — not re-run here):** 0.4.0 MTP via `SpecConfig(spec_type=DRAFT_MTP)` on a Qwen3.8-27B MTP GGUF across two Blackwells: ~30.5 tok/s plain, ~60 with MTP, full 262k context, 0.6/0.4 split. **Nikola VM cannot prove GPU or MTP** — labeled **Court re-smoke** below.



Text/Nix for Spock/Eli to apply — Nikola does not SSH to Court machines and this Grok Bot VM has **no NVIDIA GPU** (no CUDA inference was run here).

## Nikola VM proof (D5.6)

**FACT (2026-09-25, Grok Bot VM — no Court SSH, no CUDA from-source build):**

| Check | Result |
|-------|--------|
| Published wheel | `llama_cpp_python-0.4.0+cu131-cp312-cp312-linux_x86_64.whl` from JamePeng release `v0.4.0-cu131-linux-20260919` |
| Wheel sha256 | `c31ced51b0de0b9534df4f6ec2cfcc2e3f23f310cbbeea8ed5b5b4f3c4e4cf58` — **matched** Court digest |
| Nix pin eval | `nix eval .#packages.x86_64-linux.llama-cpp-python-cuda.version` → `0.4.0` (drv evaluated; **not** a full CUDA build) |
| Import | python3.12 venv + published wheel: `import llama_cpp` → `__version__ == '0.4.0'` |
| `llama_supports_gpu_offload()` | **False** on this VM (no NVIDIA drivers/GPUs) |
| Driver shim | `d5/court-cuda-driver-shim.sh` **unchanged** (git diff empty) |

**Intentional split:** Nix pin stays **SOURCE** (patches need the tree). VM import proof uses the published **WHEEL** (do not compile multi-arch CUDA here).

**Court re-smoke only (not claimed here):** GPU offload True under shim; MTP (`SpecConfig(spec_type=DRAFT_MTP)`); two remaining House patches applying on `5c83af7`.

## House fork pin (fact)

| Field | Value |
|-------|--------|
| Upstream stock (nixpkgs 25.05) | `abetlen/llama-cpp-python` **0.3.9** |
| House / D5.6 `src` | [`JamePeng/llama-cpp-python`](https://github.com/JamePeng/llama-cpp-python) **0.4.0** |
| Pinned `rev` | `5c83af7dcfed4ffdd6bda791835d92698c90a398` |
| Prior pin (D5.2–D5.5) | 0.3.49 @ `34c1bfbce3ad485d31e67039fa9200e6ab49882e` |
| Tag note | **No plain `v0.4.0` tag** on the remote (FACT, 2026-09-25). All `v0.4.0-*` platform tags (incl. `v0.4.0-cu131-linux-20260919`, Court’s cu131 line) share this rev. Court named “tag v0.4.0”; we pin the shared tip. |
| `__version__` in tree | `"0.4.0"` (confirmed in fetched tree) |
| Patch contract | **Two** remaining (`logits_all_draft`, `stopping_word`). `clean_continuation` upstream in 0.4.0 (Court). |

### Submodules — required (fact)

The fork vendors **llama.cpp** as a git submodule at `vendor/llama.cpp` (→ `ggml-org/llama.cpp`).  

**`fetchFromGitHub` must set `fetchSubmodules = true`.** Without it the fetch has an empty `vendor/llama.cpp` and the scikit-build / CMake CUDA build has **no C++ tree**. Prefetch hash for this pin (incl. submodule payload): `sha256-nxLy/hxfdxFToHihGTqbKIwBofCH5wnessvUQkKenh0=` (matches `d5/llama-cpp-python.nix`).

## What you get (unchanged from D5.1 except src)

| Item | Notes |
|------|--------|
| `python` + `llama_cpp` | CUDA override + **JamePeng 0.4.0 src (submodules)** + local patches + `CUDAARCHS` (incl. **89 / 120**) |
| `llama-cli` / `llama-server` | Still from `pkgs.llama-cpp.override { cudaSupport = true; }` (kept) |
| `cudaPackages.cudatoolkit` | Merged toolkit (CUDA **12.8** on this pin) — setup hooks set `CUDA_PATH` |
| `pciutils` / `nvtop` (nvidia) | Light host helpers |
| `d5/patches/` | Empty by default (`.gitkeep` only). **Court drops House’s real `.patch` files here** (House converts their line-edit scripts — not Nikola’s job) |

**Flake outputs:**

- `devShells.x86_64-linux.llama-cuda` (primary) / alias `.#d5`
- `packages.x86_64-linux.llama-cpp-python-cuda` — the python package alone (empty `patches/`)
- `checks.x86_64-linux.d5-shell-eval` — shell name instantiate
- `checks.x86_64-linux.d5-python-eval` — python CUDA drv instantiate (**empty** `patches/`)
- `checks.x86_64-linux.d5-python-with-dummy-patch` — same with `d5/patches-dummy/0001-nikola-dummy.patch`

Existing `devShells.default` (sandbox tools) is unchanged.

## Court next step (first real patchPhase)

```bash
# Court copies the two remaining House patches (clean_continuation is upstream in 0.4.0):
cp /path/to/house-patches/{logits_all_draft,stopping_word}.patch d5/patches/
# First real patchPhase proof on the rig (GPU box; multi-GiB CUDA):
nix build .#llama-cpp-python-cuda
# Or enter the shell after a successful build / with substituters:
nix develop .#llama-cuda
```

- Only `*.patch` files are applied (`.gitkeep` ignored).
- Dummy proof lives under **`d5/patches-dummy/`** — do **not** copy it into `patches/` for production; it is only for the `d5-python-with-dummy-patch` check (instantiate wiring).
- Nikola sandbox **aborts** multi-GiB CUDA builds; Court runs the real build on the rig.

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
python -c 'import llama_cpp; print(llama_cpp.__version__)'  # expect 0.4.0 after build
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
- Arch string on this pin includes **75;80;86;89;90;100;120** — **Ada (8.9)** and **Blackwell (12.0)** covered (**fact for this nixpkgs pin**). D5 sets `CUDAARCHS` (CMake 3.24+ env) to the same string — stock nixpkgs CUDA python build omitted arch flags; SKBUILD_CMAKE_ARGS cannot embed semicolon-rich values cleanly.
- `cudaSupport` forced via `.override` — Court need not set global `cudaSupport`.

## Package skew — labeled guesses (stock 0.3.9 vs fork 0.4.0)

Nikola **adjusted what instantiate needs** (`version` + `src` + `fetchSubmodules`). **No claim** that the full CUDA wheel builds clean on this VM.

| Item | Stock (nixpkgs 25.05) | Fork 0.4.0 | Nikola action / guess |
|------|----------------------|-------------|------------------------|
| `src` owner | abetlen | JamePeng | **Done** — override `src` (D5.6 → 0.4.0 tip) |
| `version` | 0.3.9 | 0.4.0 | **Done** — set `version = "0.4.0"` |
| Submodules | already `true` upstream | required | **Done** — keep `fetchSubmodules = true` |
| `scikit-build-core` | 0.11.1 on pin | pyproject wants `>=0.9.2` | **GUESS: OK** — pin satisfies |
| `numpy` | 2.2.5 | `>=1.21.6,<=2.3.2` | **GUESS: OK** — within upper bound |
| `Pillow` | not in stock 0.3.9 deps | `Pillow>=9.5.0` in pyproject | **Fact (Court D5.2 build):** hook failed `pillow not installed`. **D5.3:** append to **`propagatedBuildInputs`** (measured: `dependencies` overrideAttrs does not stick; PBI does). |
| setuptools / scikit-build pins | stock build-system list | fork uses scikit-build-core only | **GUESS: stock build-system still works** (same backend); watch for stricter cmake floor |
| House patches vs tree | target 0.4.0 | 0.4.0 | **Fact D5.6** — empty `patches/` until Court drops the **two** remaining diffs |
| Dummy hunk | was `"0.3.49"` | `"0.4.0"` | **Done** — dummy retargeted; check still instantiate-only |

## Honest limitations (Nikola sandbox)

- This VM has **no NVIDIA GPU**. Nikola **evaluated** flake outputs / drvPaths for empty-patches and dummy-patch variants. A **full CUDA build** is multi-GiB and was **not** completed here — do **not** treat eval as “patched wheel built on rig.”
- No CUDA inference, no GGUF downloads, no Court SSH, no secrets in this tree.
- Pinned **nixpkgs 25.05** (same as D1–D4), not Court **26.05**.
- First real **`patchPhase` proof** is Court: drop House `.patch` files → `nix build .#llama-cpp-python-cuda` on the rig.

## Files

| Path | Role |
|------|------|
| `shell.nix` | `mkShell`: python+llama_cpp (CUDA) + llama-server + toolkit |
| `llama-cpp-python.nix` | JamePeng 0.4.0 src (submodules) + CUDA + `patchesDir` + arch flags |
| `patches/` | Court drops **two** remaining House patches here (README + `.gitkeep`) |
| `patches-dummy/0001-nikola-dummy.patch` | Trivial no-op for check only (0.4.0 hunk) |
| `eval-shell.nix` / `eval-python.nix` / `eval-python-dummy.nix` | Cheap instantiate checks |
| `README.md` | This file |

## Verify (sandbox-safe)

```bash
nix eval .#devShells.x86_64-linux.llama-cuda.drvPath
nix build .#checks.x86_64-linux.d5-shell-eval --no-link
nix build .#checks.x86_64-linux.d5-python-eval --no-link
nix build .#checks.x86_64-linux.d5-python-with-dummy-patch --no-link
# Heavy on a GPU-less box (multi-GiB CUDA) — Court/rig only:
# nix build .#packages.x86_64-linux.llama-cpp-python-cuda
# nix develop .#llama-cuda --command python -c 'import llama_cpp; print(llama_cpp.__version__)'
```
