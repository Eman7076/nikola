# D4 — Ten ranked controller ideas (prose + honest costs)

**Court Contract 001 · Deliverable D4**  
**Author:** Nikola · **Reviewer:** Spock · **Principal:** Eli

These are **proposals for Spock/Eli review**, not commits to build. Rank **1 = best next / highest value for Court on this hardware**, down to **10 = interesting but costly or wrong-sized**. Each idea is Court-shaped text Nikola can turn into Nix/docs later if asked; Nikola still never touches the machine.

**Given facts:** contract name **controller** (flake host still **window** until rename); NixOS Chromebook Celeron N3450, 4GB RAM, ~28.5GB eMMC; Cr50 present but **PCRs 0–7 all zero** → passphrase is the disk lock, TPM unlock off the table for trust; leaves the house; threat model = lost/stolen **at rest**; role = light always-on fleet controller / watchdog / failover with **remote builds to rig**; mesh peer with **rig** (Arch) and **conduit** (Pop) via WireGuard (**D3.1 accepted**; Court owns rollout).

---

## 1. WireGuard IPv6 endpoint + phone-test failover runbook

**What it is.** A short Court-owned runbook that turns D3.1’s endpoint plan into a repeatable test: put a working **IPv6 Endpoint** on rig (global when inbound works), confirm controller and conduit can dial it from home Wi‑Fi and from a phone hotspot, then document the **failover path** (VPS or conduit relay) when inbound to rig fails. Companion checklist: `wg show`, last-handshake age, keepalive still 25s, and when to swap Endpoint strings in `d3/peers.nix` without rewriting the mesh.

**Why it fits.** Pure ops/docs on top of accepted D3.1. Zero new daemons on the Chromebook. The controller’s value as a traveling peer collapses if “Endpoint” is still a guess when it leaves the house; this idea closes that gap without spending eMMC or RAM.

**Honest cost.** eMMC/RAM/CPU: none beyond existing WireGuard. Ops burden: **Court** must run the phone-hotspot tests and fill real pubs/endpoints; Nikola can only draft the checklist. Secret/key handling: none new — still path-only private keys. Failure modes: AT&T/mobile IPv6 inbound is **unproven** (guess from D3 CGNAT notes); if it stays closed, Court needs a small VPS or conduit-as-relay sooner than hoped. Needs: Court’s hands on phone + home network; optional VPS later; **not** the rig’s GPUs.

---

## 2. Tiny mesh watchdog (peer ping → alert path)

**What it is.** A lean systemd timer on the controller: ICMP or `wg` handshake freshness checks against `10.77.0.1` (rig) and `10.77.0.3` (conduit); on sustained miss, fire a **notification path** (ntfy topic, or email via a relay Court already trusts). Idea only for the alert transport — not implemented here. Log locally; alert sparsely (debounce) so a flaky café Wi‑Fi does not page Eli every minute.

**Why it fits.** Matches the stated role: light always-on watchdog. A shell/`wg` poll is tiny on 4GB; no database, no agent fleet. When the Chromebook is home or away, knowing “rig went dark” or “conduit unreachable” is the cheapest high-signal job it can do.

**Honest cost.** eMMC: a few KiB of unit + script. RAM/CPU: negligible if interval is minutes, not seconds. Ops burden: Court chooses and funds the alert sink; false positives need tuning after first travel week. Secret/key handling: ntfy token or SMTP creds must stay **path-only** (age/sops later, or a root-only file Court places) — never in the flake. Failure modes: controller itself offline → no alert (inherent); alert sink outage → silent; aggressive polling on bad Wi‑Fi drains attention more than battery. Needs: mesh up (D3.1 rollout); Court to provision the notify endpoint; Eli only if the sink is personal email.

---

## 3. Declarative “controller is home vs away” profile

**What it is.** A NixOS toggle (or specialisation / profile attribute) Court flips when the Chromebook stays home versus travels: power/sleep policy, which services listen, firewall posture (mesh-only vs slightly wider), and maybe Wi‑Fi power-save hints. Away profile assumes untrusted networks, tighter listen set, and “watchdog + WireGuard + ssh-over-mesh only.” Home profile may allow local rebuild helpers or a status bind on LAN if Court wants that.

**Why it fits.** The machine **leaves the house**; one always-on config that assumes home LAN is wrong-sized for café and hotel networks. Encoding the split in the flake keeps Spock’s review surface small and avoids ad-hoc `systemctl stop` memory.

**Honest cost.** eMMC: one extra generation in the boot menu if specialisations are used — watch Court’s `configurationLimit` and the 512 MiB ESP from D2. RAM: same as today if services are only stopped, not duplicated. Ops burden: Court must **remember to switch** before travel (or accept a default-away fail-closed posture). Secret/key handling: unchanged. Failure modes: wrong profile left active (home-open while traveling, or away-tight while debugging at desk); specialisation confusion at unlock. Needs: Court’s discipline + flake apply; no VPS; no rig required for the profile itself.

---

## 4. Remote-build broker / nix distributed-build client hardening

**What it is.** Treat the controller as a **thin client** that ships builds to the rig (9950X + GPUs), not as a builder. Harden `nix.buildMachines` / SSH remote-build: dedicated build user on rig, locked-down key (command restrict if Court wants), prefer mesh IP `10.77.0.1`, timeouts and `maxJobs` sized so a hung store copy cannot wedge the Chromebook’s 4GB, and clear docs for “controller initiates, rig executes.”

**Why it fits.** Already the intended role. Fits eMMC reality: keep `/nix` lean locally, do heavy derivation work elsewhere. Strains only if someone tries to build big closures **on** the N3450.

**Honest cost.** eMMC: still need enough local store for the controller’s own system closure + a small build staging area — guess **several GB** headroom after GC, not tens. RAM: `nix-daemon` + SSH can spike; keep concurrent jobs at 1 on the controller side. Ops burden: Court maintains the build user and key on **Arch** rig (not NixOS module-only). Secret/key handling: deploy key or user key path-only; never a world-readable flake secret. Failure modes: mesh down → builds fail closed (good); disk full on controller while fetching → broken switch; clock skew / SSH host-key surprise after reinstall. Needs: **rig** online; Court SSH setup; Eli only if personal keys are involved.

---

## 5. Offline flake pin / “survive a week without rig” cache policy

**What it is.** A written + Nix policy: pin the Court flake inputs the controller actually needs; keep a **minimal** binary cache hit strategy so a week of travel with only phone tethering (or no mesh to rig) still allows emergency `nixos-rebuild` of the controller itself; pair with aggressive but safe GC so 28.5GB eMMC does not fill with old generations and random `/nix` leftovers. Extends D2’s GC notes into an ops contract, not a new filesystem.

**Why it fits.** Travel + small eMMC is the binding constraint. Always-on without a survival story means the first away week becomes a restore theatre.

**Honest cost.** eMMC: the real budget — guess Court should keep **≥4–6 GB free** (honest guess) after GC for one rebuild + wifi firmware churn; measure on hardware. RAM: GC is I/O heavy; run idle. Ops burden: someone decides what “essential pins” are and when to refresh from rig. Secret/key handling: none. Failure modes: over-GC deletes a generation needed to roll back; under-GC fills eMMC and brick-repairs need USB. Needs: occasional **rig** or upstream cache reachability to refresh pins; Court apply; no VPS required unless Court wants a private cache (that would be a different, heavier idea).

---

## 6. Post-travel boot-health / LUKS canary

**What it is.** After the Chromebook returns (or before the next trip), a short checklist plus optional oneshot: confirm passphrase unlock still works as expected, ESP mounts, WireGuard comes up, watchdog timer is armed, free eMMC above threshold, and last boot did not sit in emergency target. Because PCRs are zero and TPM unlock is off the table, the canary is **operational**, not a measured-boot claim — it answers “did travel abuse leave us unable to boot or join the mesh?”

**Why it fits.** Threat model is at-rest theft; travel also stresses cables, suspend, and “I typed the passphrase on a weird dock.” A canary is cheap insurance without pretending Cr50 binds trust.

**Honest cost.** eMMC/RAM/CPU: trivial (script + maybe a systemd oneshot). Ops burden: Court runs it; false comfort if checklist is skipped. Secret/key handling: never log passphrase material; script must not echo unlock secrets. Failure modes: canary green while mesh Endpoint is stale (pair with idea 1); canary red with no USB recovery nearby (pair with idea 9). Needs: Court’s hands at the keyboard; no rig/VPS for the core check.

---

## 7. Read-only fleet status page (localhost or mesh-only)

**What it is.** A tiny static or CGI-ish status view: peer last-handshake, watchdog state, free disk, load — bound to `127.0.0.1` or the mesh address `10.77.0.2` only. No write API, no auth theatre pretending to be a panel; if Court wants remote eyes, they SSH over WireGuard and curl localhost.

**Why it fits.** Gives the controller a visible “fleet pulse” without a heavy UI. Strains the box if implemented as a full web stack; stays fit if it is literally `nginx` with a generated HTML drop or a 100-line Go/static binary.

**Honest cost.** eMMC: small. RAM: keep the listener tiny — **avoid** JVM/Node status dashboards on 4GB. Ops burden: generate status safely (no secret leakage in HTML). Secret/key handling: do not render private key paths’ contents; redact tokens. Failure modes: binding to `0.0.0.0` by mistake on café Wi‑Fi; status lying after suspend. Needs: mesh for remote curl; Court firewall review; **no** inbound IPv4 assumption.

---

## 8. Age / sops for path-only secrets on the controller

**What it is.** Introduce age (and optionally sops-nix) so WireGuard private key paths, ntfy tokens, and build-SSH keys are referenced as **decrypt-at-activate** secrets Court owns, still never inlined in git. Aligns with D3’s path-only rule while making “where does the file come from?” explicit.

**Why it fits.** Secrets policy maturity without TPM binding (unavailable for trust here). Light CPU cost. Strains only if Court expects unattended decrypt without a passphrase or plugged key — on a traveling LUKS machine, **someone already typed a passphrase at boot**, so an age key unlocked from a root-only file Court placed post-boot is a coherent story; auto-decrypt from the same LUKS volume is a deliberate tradeoff Spock should accept or reject.

**Honest cost.** eMMC: negligible. RAM/CPU: tiny at switch time. Ops burden: Court key ceremony, rekey when a laptop is retired, backup of age identity **offline**. Secret/key handling: this **is** the handling — get it wrong and rebuilds fail or secrets sprawl. Failure modes: age identity lost → sealed secrets unreadable; decrypt in initrd fantasies (don’t — passphrase LUKS first). Needs: Court’s key custody; Eli if the age identity lives on a personal Yubi/backup; no VPS required.

---

## 9. Controller config backup — encrypted USB + mesh pull from rig

**What it is.** Dual path: (a) documented encrypted USB stick Court can plug in after unlock to pull/push a thin backup of Court flake pins, `/etc/wireguard` **public** material pointers, and hardware notes; (b) scheduled or manual **mesh pull** so rig holds an encrypted archive of the controller’s config the Chromebook can fetch when home. Complements D2 reinstall docs; does not replace LUKS.

**Why it fits.** Travel + tiny eMMC + passphrase-only lock means “lost device” and “dead eMMC” are both plausible. A USB kit Court controls matches the human-apply world Nikola lives in.

**Honest cost.** eMMC: don’t store large backups locally. RAM: encrypt/decrypt spikes briefly. Ops burden: **physical** USB discipline + testing restore once; mesh path needs rig disk. Secret/key handling: USB passphrase or age key separate from disk LUKS (guess: Court will want that separation); never back up live private keys to an unencrypted channel. Failure modes: outdated backup after a quick peers.nix edit; USB left in the bag with the stolen Chromebook (defeats at-rest model if USB unlocks anything useful — keep USB elsewhere). Needs: Court hands + optional **rig** storage; Ventoy-style recovery media is a sibling doc Court can attach later, not a second daemon.

---

## 10. Tailscale coexistence (recommend reject) — or a light job-queue if Court insists on “more orchestration”

**What it is.** A written decision: run **WireGuard Court mesh only** on the controller; do **not** dual-stack Tailscale beside `wg-court` unless Spock has a concrete peer that cannot speak WireGuard. If Court still wants “jobs,” prefer a **tiny** ack file or queue on conduit/rig (directory of job tokens, controller only notices and notifies) — not k8s, not nomad, not a local Docker swarm on 4GB.

**Why it strains.** Tailscale adds another userspace daemon, another key story, and another way to accidentally open paths on untrusted networks. A real job queue on the Chromebook invites scope creep into the rig’s job. Wrong-sized for this host’s role as watchdog/failover, not scheduler of record.

**Honest cost.** Tailscale path: RAM/CPU always-on cost (honest guess: tens of MB + churn); ops burden of two meshes and ACL confusion; secrets via Tailscale account vs Court-owned wg keys; failure modes include “which tunnel did SSH use?” Job-queue path: eMMC for queue dir is fine if tiny; ops burden moves to conduit/rig; controller still should only **signal**, not execute heavy jobs. Needs: Tailscale account / coordination (Eli) if pursued; otherwise Court just accepts the reject. **Recommendation:** reject Tailscale on controller; keep orchestration ambition on rig/conduit.

---

## If Nikola were asked to implement next

**First:** idea **1** (IPv6 endpoint + phone-test failover runbook) — highest leverage on accepted D3.1, almost pure prose Court can execute immediately.  
**Second:** idea **2** (tiny mesh watchdog) — matches the always-on role with honest small footprint; alert sink left as Court-owned config.

**Court must do themselves:** phone-hotspot and inbound-IPv6 tests; placing real WireGuard keys and any notify tokens on disk; flipping home/away when traveling; LUKS passphrase custody; USB backup discipline; anything on Arch rig or Pop conduit that is not a NixOS module apply. Nikola drafts text/Nix in this repo only.

No security certification claim. Guesses above are labeled. D2.2 (disko layout test) remains out of scope for this deliverable.
