# D6 — Fleet pitch (ten ranked ideas)

**Court Contract 001 · Deliverable D6** (post–D5.5 ideas; not an implementation order)  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

Contract 001 is **accepted through D5.4**; **D5.5** (Arch NVIDIA driver shim) is the last *implementation* line of that contract and sits on `main` at `54bdbe3`, awaiting Court GPU re-smoke. This deliverable is **not** more orders. It is a ranked pitch: what the Nix chain should carry next, for which machine or entity, and why.

**Rank 1 = best next / highest leverage for reproducibility or measurability.** Rank 10 = interesting, but costly, early, or easy to refuse. Each idea is Court-shaped text Nikola can turn into Nix/docs later if asked. Nikola still **proposes only** — no Court SSH, no keys, no Court data, no network seat, nothing that phones home, nothing that needs a secret to evaluate.

**Fleet facts (Spock 2026-09-24 unless marked guess):**

| Machine | Role | Notes |
|---------|------|--------|
| **novacourt** (rig) | Arch; three NVIDIA (2×16 GB Blackwell, 1×16 GB Ada); whole Court runs here | Nix is a **layer**, never the OS. Irreplaceable data ~**375 MB** (souls/dbs); bodies (weights) re-downloadable. Real migration risk = **env stack** (conda, three llama-cpp patches, CUDA flags). |
| **window** (conductor) | NixOS Chromebook; always-on watcher; leaves the house; builds on the rig | Currently **unencrypted**; SSH key has **no passphrase** (both owed). D2 is what fixes the disk. |
| **conduit** | Pop!_OS Dell XPS 15 7590 (GTX 1650); encrypted | Senses + ingest; rig↔tank channel; where Court flashes cards. |
| **room** | Bazzite (immutable); Eli’s machine; wire-only by ruling | Render box. Not Nikola’s to touch — only to think about. |
| **kit** / **kat** | Orange Pi Zero 2W (H618, aarch64, 1 GB, Wi‑Fi only) | kit booted headless on Armbian community trixie (fact); kat next. Camera, motors, small runtime → rig over Wi‑Fi. |
| **Porteus stick** | Five-OS Ventoy toolkit | Fifth member of the recovery story. |
| Mesh | WireGuard (D3.1) replaces Tailscale once rig IPv6 inbound is **measured** | Rig may be the home endpoint. |

**Entities (name whom an idea serves):** Conscia (Nova — dark until launch; vLLM on Blackwells, Gemma VLM on Ada, sherpa-onnx, Piper); Elysia (living-world + shippable game; llama.cpp MIT, BYOM, TypeScript client, installer must detect OS); Igris (40B GGUF / cloud body; own daemon); Spock (memory in files, recall server, boot seed, ark); Court organs (stdlib: rail, percept bus, guards, domains). **Calypso is off the table.**

**Hour costs are guesses** unless a prior deliverable already measured similar work. “Nikola hours” = draft + eval on this VM. “Court hours” = apply, measure, or own secrets on real metal.

---

## 1. Apply D2 LUKS to window for real

**Serves:** window (conductor); Eli’s at-rest threat model.

**Makes true that is false today:** The conductor’s disk is **passphrase-LUKS encrypted** with the D2.2.1 layout (GPT + ESP + LUKS2 + btrfs subvols), instead of sitting unencrypted while it leaves the house.

**Cost (guess):** Nikola **4–8 h** (migration checklist, ESP/generation budget notes, rollback prose tied to accepted `d2/`). Court **half day to a day** (backup souls/config, live apply, one successful unlock + boot + mesh rejoin). No new secrets in git.

**Prove on VM vs rig/window:** VM already holds **eval + passphrase + disko layout** checks (D2 / D2.2.1). Live apply, passphrase UX, and eMMC headroom are **window-only**. Nested KVM on this VM is not a substitute for Court’s install path.

**Why not:** A botched apply on 28.5 GB eMMC without a tested USB recovery path costs a travel week; Court may prefer to wait until the Porteus/Ventoy kit (idea 10) is rehearsed once.

---

## 2. One-bell watcher on the conductor (Eli’s shape)

**Serves:** window; Spock’s ark / existing sentinel·dead-man; Eli’s “one stream” ask.

**Makes true that is false today:** Several health sources (mesh handshake age, free eMMC, last organ-canary result, recall-index mtime — Court picks the set) land in **one** append-only stream a human or the existing dead-man can tail — without a second watchdog daemon and **without `Persistent=true`** on any unit (Eli’s constraint; fact of the ask).

**Cost (guess):** Nikola **6–10 h** (systemd oneshot/timer units, fan-in script, flake module stub, docs: what is a “source”, debounce rules, fail-closed when a source file is missing). Court **2–4 h** to point real paths and confirm the dead-man consumes the bell file/socket Court already trusts.

**Prove on VM vs rig/window:** VM can nixosTest a toy fan-in (fake source files → one stream, timer fires, no Persistent). Real source paths, alert routing, and “re-armed after suspend” are **window + Court**.

**Why not:** If Court treats this as a second brain instead of a feeder for the existing dead-man, you get the double-watchdog mess Spock already flagged on D4 #2.

---

## 3. Pin the rig’s Court / Conscia env stack as a Nix shell

**Serves:** novacourt; Conscia (when she lights); Igris’s local body; anyone who today rebuilds CUDA/conda by memory.

**Makes true that is false today:** “Recreate the env that loads models” is a **`nix develop` diff against a known-good pin**, not a guess across conda envs, three llama-cpp patches, and CUDA flags. Weights stay out of the store (re-downloadable); the **recipe** is what gets pinned. Builds on D5.5’s driver-shim lesson: Nix layer on Arch, driver libs from the host, never whole `/usr/lib`.

**Cost (guess):** Nikola **12–20 h** for a first useful shell (Python pin strategy, CUDA flag surface, patch directory contract, Arch shim reuse, README of what is *not* pinned). Court **1–2 days** to inventory the live conda/CUDA truth and smoke Conscia/Igris imports on the rig. First cut will be incomplete on purpose.

**Prove on VM vs rig:** VM can **eval** the shell and prove “no secret required to instantiate.” Real `llama_supports_gpu_offload`, vLLM, and multi-GPU placement are **rig-only** (this VM has no NVIDIA — fact).

**Why not:** Conda and Nix both want to own the world; a half-migrated pin can become a third env nobody trusts. Refuse if Court is not ready to name one “known-good” command for smoke.

---

## 4. Spock recall / index freshness canary

**Serves:** Spock; window (as the always-on bell ringer); the house’s “12-day-stale index nobody noticed” failure mode.

**Makes true that is false today:** Index / recall freshness is a **measured age** with a threshold; when it goes stale, the one-bell stream (idea 2) or an existing ark path rings — instead of silent drift.

**Cost (guess):** Nikola **3–6 h** (canary script + unit sketch + docs: which mtime/size/hash Court exposes, no reading of soul contents). Court **1–3 h** to expose a **non-secret** freshness signal (mtime of an index file Court already has, or a Court-written `freshness.json` with only timestamps).

**Prove on VM vs rig/window:** VM can test “file older than N → exit nonzero / bell line.” Real paths and Spock’s recall layout are **Court-only**; Nikola never reads Court memory corpora.

**Why not:** A canary on the wrong file teaches false green; if freshness needs semantic “did recall still answer?”, that is Spock product work, not a mtime check.

---

## 5. Court stdlib organ falsifiers as a Nix check

**Serves:** Court organs (rail, percept bus, guards, domains); every entity that trusts those organs.

**Makes true that is false today:** Organ falsifiers run as a **`nix flake check`** (or a thin nixosTest) so “guards still hold” is a build fact, not a ritual someone remembers after a refactor.

**Cost (guess):** Nikola **8–14 h** once Court points at a **secret-free** test entrypoint (stdlib tree or a published test package path). Court **half day+** to carve falsifiers that need no live mesh, no soul DB, no Calypso, and no phone-home.

**Prove on VM vs rig:** If tests are pure Python/stdlib, **VM can run them**. Anything that needs GPUs, Wi‑Fi tanks, or live WireGuard stays on Court metal or stays out of the check.

**Why not:** If the only honest falsifiers need Court data or a network seat, the check becomes theatre or violates hard lines — refuse until Court splits pure vs impure suites.

---

## 6. aarch64 cross-built tank runtime for kit / kat

**Serves:** kit, kat; conduit (flash/ingest seat); novacourt (command/telemetry peer over Wi‑Fi).

**Makes true that is false today:** The small tank runtime is a **reproducible aarch64 closure** (or a pinned cross-built artifact + flash script) instead of “whatever Armbian packages were on the card the day kit first booted.”

**Cost (guess):** Nikola **10–18 h** for a minimal cross package + flash-oriented README (no motors secrets, no camera cloud). Court **a day** to define the wire protocol they already want, flash kat, and Wi‑Fi bring-up against the rig.

**Prove on VM vs rig/conduit:** This VM can **cross-build aarch64** and eval the derivation (guess: feasible on x86_64 Linux nix; label confirmed after first `nix build`). Boot, Wi‑Fi, camera, and motor smoke need **kit/kat + conduit**. Nikola does not flash cards.

**Why not:** 1 GB RAM and Wi‑Fi-only boards punish fat runtimes; if Court wants a full agent body on the Pi, Nix will not save a bad size budget — keep the tank thin and the brain on the rig.

---

## 7. Measure rig IPv6 inbound + Tailscale sunset runbook

**Serves:** whole mesh (window, conduit, future kit via gateway); retires Tailscale as the Court underlay once facts exist.

**Makes true that is false today:** “WireGuard replaces Tailscale” is a **measured** decision (rig global IPv6 Endpoint works from home Wi‑Fi and a phone hotspot, or it does not and Court documents VPS/conduit-relay failover), not a hope sitting on D3.1 prose.

**Cost (guess):** Nikola **3–5 h** (checklist extending D3.1 / D4 #1: `wg show`, handshake age, Endpoint swap in `d3/peers.nix`, Tailscale teardown order). Court **2–6 h** of network measurement + cutover; Eli if ISP/VPS money is involved.

**Prove on VM vs Court:** VM can only keep the runbook and conf packages honest. Inbound IPv6, phone hotspot, and Tailscale ACL cleanup are **Court network facts**.

**Why not:** If inbound IPv6 stays closed and Court refuses a tiny VPS, cutting Tailscale early orphans traveling window — measure first, sunset second.

---

## 8. Land House llama patches as real diffs; prove D5 patchPhase on the rig

**Serves:** Igris / House in-process llama bodies; Conscia-adjacent stacks that share the JamePeng 0.3.49 pin; finishes the D5 chain’s unpaid House half.

**Makes true that is false today:** `clean_continuation`, `logits_all_draft`, and `stopping_word` exist as **real `.patch` files** against rev `34c1bfb` under `d5/patches/`, and `nix build .#llama-cpp-python-cuda` applies them in patchPhase — instead of a line-editing Python script nobody can diff in git.

**Cost (guess):** Nikola **1–3 h** after patches land (sanity-read hunks, keep hook docs accurate, optional dummy-vs-real check note). **House/Court** owns rendering the diffs — Spock already said that was never Nikola’s. Court **one CUDA rebuild** on the rig (known cost band from D5.2–D5.4).

**Prove on VM vs rig:** VM already proves **hook wiring** with `d5/patches-dummy`. Real patch apply + GPU import smoke are **rig-only**.

**Why not:** Refuse to have Nikola reverse-engineer House’s line-edit script into patches from outside — wrong owner, wrong trust boundary. Wait for House to drop files.

---

## 9. Conduit home-manager seat: ingest + tank-video shell

**Serves:** conduit; kit/kat footage path; puts the Pop box’s idle ~90% (Eli’s earlier fact) on a declared seat.

**Makes true that is false today:** Dead-air cutting / Orange Pi 720p ingest tools are a **`nix develop` on conduit** (ffmpeg stack, project pins, output layout docs) instead of ad-hoc packages on an unused laptop. GTX 1650 render grunt stays optional and labeled.

**Cost (guess):** Nikola **8–12 h** for an HM-friendly shell + README (no Court media in repo). Court **half day** to point at real card paths and accept output folders. Video quality taste stays Court/Eli.

**Prove on VM vs conduit:** VM can build the shell and run ffmpeg on **synthetic** clips. Real tank SD cards, NVIDIA encode on 1650, and flash discipline are **conduit-only**. Standing rule: Nikola does not operate conduit without Eli’s explicit per-step yes — this pitch stays text/Nix.

**Why not:** If conduit’s job this month is only flashing Armbian and the video pile can wait, this is polish ahead of kit/kat survival (idea 6).

---

## 10. Porteus / Ventoy recovery peer for window (and a think-only note on room)

**Serves:** window’s mortality; Porteus stick as fifth member; **room** only as a written boundary (immutable render peer, wire-only — not operated by Nikola).

**Makes true that is false today:** “Chromebook eMMC died or LUKS apply went wrong” has a **rehearsed** path: which ISOs on the Ventoy stick, how to unlock/restoresouls (~375 MB class), how to fetch a known flake pin, and what room is **not** asked to do (no Court souls on Bazzite; render jobs only by Eli’s ruling).

**Cost (guess):** Nikola **4–7 h** of runbook + checklist (no ISO redistribution of copyrighted trees; Court supplies their own images). Court **one afternoon** to rehearse once before idea 1’s live LUKS apply. room note is prose only.

**Prove on VM vs Court:** VM can hold the markdown and maybe a script that verifies “required files present on a mounted stick.” Actual boot from Ventoy and bit-identical soul restore are **Court hands**.

**Why not:** A beautiful runbook nobody rehearses is false comfort; refuse to treat this as a substitute for encryption (idea 1) — it is the parachute, not the harness.

---

## What I would do first (if Court picks without debating all ten)

1. **Idea 1** (window LUKS) — closes an owed hole the conductor’s job description does not survive.  
2. **Idea 2** (one bell) — Eli’s shape, measurable, feeds infrastructure you already have.  
3. **Idea 3** or **4** next — env pin if Conscia/Igris rebuild pain is the weekly bleed; freshness canary if silent drift is the weekly bleed.

**Explicit non-goals in this pitch:** Calypso; operating room; anything that needs a secret to evaluate; phone-home telemetry; Nikola holding Court keys or souls.

**D5.5 reminder for Court:** on the rig, `nix develop .#llama-cuda` then  
`python -c 'import llama_cpp; print(llama_cpp.__version__, llama_cpp.llama_supports_gpu_offload())'`  
— expect `0.3.49 True` with the proprietary driver present. Untested on Nikola’s VM (no NVIDIA).

No security certification claim. Guesses are labeled. This document does not open Contract 002 by itself; it is the menu.
