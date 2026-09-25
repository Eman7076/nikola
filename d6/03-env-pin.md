# D6.3 — Pin the rig’s Court / Conscia env stack (scaffold)

**Court Contract 001 · Deliverable D6.3** (implements D6 pitch idea 3; first cut)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

**Serves:** novacourt (rig); Conscia when she lights; Igris’s local body; anyone who today rebuilds CUDA/conda by memory.

**Hard lines:**

- Weights stay **out of the store** (re-downloadable bodies). This pin is the **recipe**.
- No secrets, no phone-home, no Calypso, no invented conda inventory.
- Nikola does not SSH to Court. This VM has **no NVIDIA** — eval ≠ GPU offload proof.
- First cut is **incomplete on purpose**. Court inventories live truth later.

---

## What landed in-repo

| Path | Role |
|------|------|
| [`env-pin/shell.nix`](./env-pin/shell.nix) | `devShells.court-env` / alias `d6-env` — composes D5 via `inputsFrom` |
| [`env-pin/extra-python-deps.nix`](./env-pin/extra-python-deps.nix) | Hook for Court-listed Python deps (**empty** until inventory) |
| [`env-pin/eval-env-pin.nix`](./env-pin/eval-env-pin.nix) | Cheap check: instantiate shell **name** only |
| [`env-pin/README.md`](./env-pin/README.md) | Short pointer |

Flake outputs:

- `devShells.x86_64-linux.court-env` (primary) / alias `.#d6-env`
- `checks.x86_64-linux.d6-env-pin-eval` — shell name instantiate (no CUDA wheel build)

---

## What is pinned vs explicitly NOT

### Pinned (recipe surface, this cut)

| Item | How | Honesty |
|------|-----|---------|
| JamePeng `llama-cpp-python` **0.4.0** + CUDA | Via D5 package (`d5/llama-cpp-python.nix`) through `inputsFrom` | Fact: D5.6 pin (was 0.3.49 through D5.5) |
| `CUDAARCHS` / cmake arch string (incl. **89 / 120**) | Surfaced as `PASS_THRU_CUDAARCHS` from nixpkgs 25.05 flags; build-time set in D5 | Fact for this nixpkgs pin |
| House patch directory contract | `COURT_LLAMA_PATCHES_DIR` → `d5/patches/` (empty + README; **two** remaining diffs — clean_continuation upstream in 0.4.0) | Fact: hook exists; Court drops logits_all_draft + stopping_word (pitch idea 8) |
| Arch / NixOS **driver-only** shim | Same `court-cuda-driver-shim.sh` as D5.5 (`shellHook` sources it) | Fact: D5.5 lesson — never whole `/usr/lib` |
| nixpkgs channel | Flake input **nixpkgs 25.05** (+ scoped `pkgsCuda` / `allowUnfree`) | Fact for this contractor flake; Court may track 26.05 later |

### Explicitly NOT pinned (and must not sneak in)

| Item | Why |
|------|-----|
| **Model weights / GGUF / HF caches** | Re-downloadable bodies; must not enter the Nix store via this shell |
| **Secrets** (API keys, WireGuard privkeys, soul DB paths with credentials) | Hard line — nothing that needs a secret to evaluate |
| **Calypso** | Off the table (pitch + hard line) |
| **Full Conscia / Court pip freeze or conda `env export`** | Unknown to this VM; Court owns live inventory |
| **vLLM / Gemma VLM / sherpa-onnx / Piper as concrete pins** | **GUESS** they will appear after Court inventory; placeholder only in `extra-python-deps.nix` |
| **Claim that this shell matches today’s live conda** | First cut is a reproducible *shape*, not a measured twin of Court metal |

---

## Relation to D5 (`llama-cpp-python-cuda` + driver shim)

D5 already solved the hardest reusable pieces for “Python that can see CUDA llama”:

1. **Package** — JamePeng 0.4.0 (`5c83af7`), submodules, pillow PBI, sandbox-safe disabledTests, `CUDAARCHS`.
2. **Shell** — `devShells.llama-cuda` / `.#d5` with toolkit + `llama-server` kept.
3. **D5.5 shim** — host driver libs only; Court measured `llama_supports_gpu_offload()` True with that pattern on the rig.

D6.3 **does not fork** those files. `env-pin/shell.nix` uses:

```nix
inputsFrom = [ (import ../../d5/shell.nix { inherit pkgs; }) ];
```

and re-sources the same shim script. Extra Court deps hang off `extra-python-deps.nix` so a later cut can unify into one `python.withPackages` without rewriting D5.

**Enter (scaffold):**

```bash
nix develop .#court-env
# or:
nix develop .#d6-env
# D5-only still works:
nix develop .#llama-cuda
```

**Rig smoke (Court; GUESS until re-measured after this cut):** same as D5.5 reminder —

```bash
python -c 'import llama_cpp; print(llama_cpp.__version__, llama_cpp.llama_supports_gpu_offload())'
# expect: 0.4.0 True  — with proprietary driver present + shim
```

---

## Court inventory checklist (live truth — Court fills)

Nikola cannot prove these on this VM. Court should record answers (even as a short note outside this repo if paths are sensitive) before treating `court-env` as the known-good smoke command.

### Conda / Python envs

- [ ] Name the **one** “loads models” conda (or venv) env that Conscia/Igris actually use today
- [ ] `conda env export --from-history` **or** `pip freeze` from that env (Court redacts secrets)
- [ ] Which packages are **CUDA wheels** vs pure Python vs system (Arch) libs
- [ ] Whether House still expects **in-process** `llama_cpp` (D5 target) vs HTTP `llama-server` only vs both

### CUDA / GPU flags

- [ ] Confirm `nvidia-smi -L` labels (pitch **GUESS:** 2×16 GB Blackwell + 1×16 GB Ada)
- [ ] Confirm driver major vs toolkit **12.8** on nixpkgs 25.05 (shim lesson still holds?)
- [ ] Any Court-specific `CUDA_VISIBLE_DEVICES` / tensor-split habits for multi-GPU
- [ ] Re-smoke: `llama_supports_gpu_offload()` under `nix develop .#court-env` (expect True)

### Two llama patches → `d5/patches/` (D5.6)

Pitch idea 8 / D5 hook. Court 2026-09-25: **`clean_continuation` is upstream in 0.4.0** — contract is **two**, not three.

- [x] `clean_continuation` — upstream in 0.4.0 (do not re-drop)
- [ ] `logits_all_draft` — still applies / still passes (Court)
- [ ] `stopping_word` — still applies / still passes (Court)

Drop the two remaining real `.patch` files against rev `5c83af7` into [`d5/patches/`](../d5/patches/). See [`d5/patches/README.md`](../d5/patches/README.md). Dummy hunks stay in `d5/patches-dummy/` only.

### Conscia / Igris extras (after base smoke)

- [ ] vLLM (Blackwells) — version + CUDA build story
- [ ] Gemma VLM on Ada — version + entrypoint
- [ ] sherpa-onnx / Piper — versions
- [ ] Any Court stdlib import path that must be on `PYTHONPATH` (secret-free only)

### Known-good command (refuse half-migration)

Pitch **why not:** conda and Nix both want to own the world. Court should name **one** smoke command, e.g.:

```text
nix develop .#court-env --command <Court-chosen-smoke>
```

…before operators delete the old conda env.

---

## Labeled guesses (VM cannot prove)

| Claim | Label |
|-------|--------|
| Multi-GPU tensor-split `1,1,1` still sensible on three 16 GB cards | **GUESS** (D5 README) |
| Conscia will need vLLM + VLM + speech stacks in the same pin eventually | **GUESS** from pitch entity notes |
| Court tracks nixpkgs **26.05** on the rig while this flake is on **25.05** | **GUESS** — confirm; may need a Court overlay later |
| Empty `extra-python-deps.nix` is enough for a first `nix develop` that only proves D5 llama import | **Intent of this cut** — not a completeness claim |
| GPU offload / vLLM placement on this scaffold | **Unproven here** — no NVIDIA on Nikola VM |

---

## Verify (sandbox-safe)

```bash
nix eval .#devShells.x86_64-linux.court-env.drvPath
nix eval .#devShells.x86_64-linux.d6-env.name
nix build .#checks.x86_64-linux.d6-env-pin-eval --no-link
# Do NOT require a full CUDA wheel rebuild on this VM.
```

What the eval proves: the shell **name** instantiates with no secret and without needing an NVIDIA device.

What it does **not** prove: matching live conda, GPU offload, Conscia import graph, or House patch apply.

---

## Blockers / next Court hours

1. **Inventory** (checklist above) — 1–2 days class from pitch.
2. **House patches** as real diffs (idea 8) — unblocks “patched wheel” half of the env story.
3. **Unify Python** — when extras are known, prefer one `python.withPackages` that includes `llama-cpp-python-cuda` + Court deps (avoid two interpreters long-term).
4. Optional: Court nixpkgs 26.05 vs this flake’s 25.05 skew note after first rig smoke.

No security certification claim. Guesses are labeled. This document does not claim the scaffold equals Court’s live conda today.
