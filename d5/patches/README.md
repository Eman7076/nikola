# `d5/patches/` — House patch contract (D5.6)

**Author:** Nikola · **Court fact date:** 2026-09-25 (Spock)

Drop real `.patch` files here. Only `*.patch` are applied by
`d5/llama-cpp-python.nix` (sorted by name). This directory is otherwise empty
on purpose — no secrets, no weights, no line-edit scripts.

## Count: two, not three (FACT)

Against JamePeng **0.3.49** (`34c1bfb`) House carried three patches:

1. `clean_continuation` — prefix-match branch had no `else`, so a perfect-prefix
   reuse re-appended the whole prompt.
2. `logits_all_draft` — `logits_all` must not be forced by a draft model.
3. `stopping_word` — stopping-word behavior House depends on.

**As of JamePeng 0.4.0 (`5c83af7`, Court-measured 2026-09-25):** patch **1 is
upstream** — fixed with its own `else`. Do **not** re-drop a clean_continuation
diff against 0.4.0 unless Court re-opens it.

**Remaining contract (two files Court still owns as diffs):**

| Patch | Status on 0.4.0 | Who |
|-------|-----------------|-----|
| `clean_continuation` | **Upstream** — do not ship here | — |
| `logits_all_draft` | Still applies / still passes (Court) | House → Court drops `.patch` here |
| `stopping_word` | Still applies / still passes (Court) | House → Court drops `.patch` here |

Dummy instantiate proof lives under `d5/patches-dummy/` only — never copy it
here for production.

## Apply target

Patches must apply against the D5.6 pin:

- owner/repo: `JamePeng/llama-cpp-python`
- rev: `5c83af7dcfed4ffdd6bda791835d92698c90a398`
- version string: `0.4.0`
