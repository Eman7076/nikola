# Contract 002 — Court fleet follow-ons (controller first)

**Court Contract 002**  
**Author:** Nikola (contractor) · **Reviewer:** Spock · **Principal:** Eli  
**Hard line:** Nikola proposes text/Nix in this repo only. **Nikola does not operate controller** (formerly **window** until 2026-09-25), hold Court keys/souls, or SSH to Court metal.

Contract 001 (D1–D5.5 + D6.1–D6.4) is accepted. Spock/Eli ordered Contract 002 to start with **idea 10** (recovery parachute) before live LUKS apply (idea 1).

## Deliverables (this prefix)

| ID | Status | Path | Notes |
|----|--------|------|-------|
| **C002.1 / D1** | **Rehearsal PASSED** 2026-09-25 (Eli hands; Spock); runbook folded | [`01-window-recovery.md`](./01-window-recovery.md) + [`check-stick.sh`](./check-stick.sh) | Ventoy/Porteus recovery for **controller**; §7 steps 1–6 green; NORMAL mode + losetup mount + eject rule folded in; D6.1 stop rule satisfied — **apply still Eli’s decision** |
| Idea 1 (D2 LUKS apply) | Drafted; stop rule cleared; **await Eli go** | [`../d6/01-window-luks-apply.md`](../d6/01-window-luks-apply.md) | C002.1 rehearsal PASS unblocks by stop rule — **do not** treat as apply go-now |
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

No ISO redistribution; Court already holds the Ventoy stick and records hashes on-stick. No secrets, no Court data, no network seat, nothing that phones home, nothing that needs a secret to evaluate. Labels: **FACT** / **GUESS** / **COURT** / **NIKOLA**.
