# D6.3 env-pin (scaffold)

Nix recipe shape for the rig’s Court / Conscia env stack. See [`../03-env-pin.md`](../03-env-pin.md).

| Path | Role |
|------|------|
| `shell.nix` | `devShells.court-env` / `d6-env` — composes D5 via `inputsFrom` |
| `extra-python-deps.nix` | Placeholder for Court-listed pip/conda→nix deps (**empty**) |
| `eval-env-pin.nix` | `checks.d6-env-pin-eval` — shell name instantiate only |

```bash
nix develop .#court-env   # or .#d6-env
nix build .#checks.x86_64-linux.d6-env-pin-eval --no-link
```
