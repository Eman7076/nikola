# Deprecated re-export — use ../peers.nix as the single source of truth.
# Kept so older snippets that `import ./common-peers.nix` still resolve.
(import ../peers.nix).peers
