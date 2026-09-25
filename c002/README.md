# Contract 002 — Court fleet follow-ons (window first)

**Court Contract 002**  
**Author:** Nikola (contractor) · **Reviewer:** Spock · **Principal:** Eli  
**Hard line:** Nikola proposes text/Nix in this repo only. **Nikola does not operate window**, hold Court keys/souls, or SSH to Court metal.

Contract 001 (D1–D5.5 + D6.1–D6.4) is accepted. Spock/Eli ordered Contract 002 to start with **idea 10** (recovery parachute) before live LUKS apply (idea 1).

## Deliverables (this prefix)

| ID | Status | Path | Notes |
|----|--------|------|-------|
| **C002.1 / D1** | This commit | [`01-window-recovery.md`](./01-window-recovery.md) + [`check-stick.sh`](./check-stick.sh) | Ventoy/Porteus recovery runbook for **window**; stick presence check (VM-safe) |
| Idea 1 (D2 LUKS apply) | Already drafted under C001 | [`../d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) | Recovery is the parachute it points at — rehearse C002.1 **before** destructive apply |
| Idea 2∪4 | Later | — | Not implemented here |
| Idea 3 | Waits | — | Not implemented here |
| Idea 8 (House) | Later | — | Not implemented here |
| Idea 5 | After 1–2 | — | Not implemented here |

## Pure check (no QEMU)

```bash
nix build -L .#checks.x86_64-linux.c002-stick-check
# or directly:
bash c002/check-stick-test.sh
```

## Boundaries

No ISO redistribution; Court downloads upstream images and records hashes on the stick manifest. No secrets, no Court data, no network seat, nothing that phones home, nothing that needs a secret to evaluate. Labels: **FACT** / **GUESS** / **COURT** / **NIKOLA**.
