# AMIDE Roadmap

This is the global navigator for this repository: product direction,
milestone sequencing, and the invariants that must not be violated. It is not
a task tracker — individual implementation tasks live in Spec Kit
`specs/<NNN-feature>/tasks.md` when a milestone below is actually planned. For
full architectural detail, read
`docs/AMIDE Implementation Specification.md` (103 sections; cited as
"Spec §N" below) and
`docs/MonotonicPromptArchitecture_quick_overview_in_relation_to_DSH_and_AMIDE_project.md`
("MPA doc"). This roadmap changes only when product direction or a governing
constraint changes, per `docs/workmethodology/acryl-hybrid-engineering-methodology.md` §2.1.

This document describes **this repository's** direction only. It is unrelated
to `docs/ACRYL-ROADMAP.md`, which describes the current, separately shipping
`acryldev/acryl` product on its own DSH/Tauri foundation.

## Product vision

**AMIDE — Adaptive Machine Intelligence Development Engine.** AMIDE combines
three proven lineages rather than inventing a fourth from scratch:

- **Pi's self-extensibility** — a coding agent that can be extended with
  hand-written TypeScript extensions and reloaded live, no rebuild required.
- **Prime Agent's execution model** — daemon-backed resident workers, a
  persistent Python (RLM) kernel, recursive subagents, goals, schedules, and
  autonomous mode that survive terminal detach.
- **Cordis and DeepSeek Harness's Monotonic Prompt Architecture (MPA)** —
  lifecycle-managed composition and the discipline that keeps every request
  to a model append-only within a cache epoch, so long sessions stay
  prefix-cache-efficient instead of degrading into the token-bloat pattern
  Prime Agent has been publicly criticized for (HN/Reddit) as sessions grow.
  Token efficiency isn't a side effect here — it's a stated differentiator.

This repository keeps Prime as the execution host (daemon supervisor,
resident workers, persistent Python kernel, RLM children, skills, TypeScript
extensions, goals, autonomous mode — Spec §3) while adopting Cordis as the
internal composition/lifecycle substrate and MPA as the discipline governing
every model request (Spec §18–§26).

**Forward direction, not yet built:** AMIDE is intended to become
multi-surface — one central driving agent that can extend itself with new
capabilities and drive multiple presentation surfaces (an Electron GUI, a
web-app server) rather than owning a single fixed UI, in the spirit of
Cordis's and Pi's own extensibility philosophy. This is stated product
direction for later milestones, not a claim about current code — nothing in
this repository implements a second surface yet. Treat it as context for
why the Cordis composition layer (Milestone 1+) matters beyond the TUI.

If this architecture proves out, it may absorb or replace the parallel
`acryldev/acryl` product (a DSH/Tauri-based effort at the same underlying
goal) — that decision is explicitly not made yet; both continue in parallel
for now. If it doesn't prove out, nothing here is load-bearing outside this
repository (Spec §1, §102).

```text
              Prime Agent
       long-running RLM runtime
                   |
                   v
            AMIDE Runtime Host
                   |
                   v
                 Cordis
     lifecycle + composition + services
                   |
     +-------------+--------------+
     |             |              |
     v             v              v
 Session Log      MPA        Capabilities
     |             |              |
     |             |              v
     |             |       stable Python ABI
     |             |              |
     |             +------+-------+
     |                    |
     v                    v
 durable truth          LLM
                         |
                         v
               high prefix-cache reuse
```

Do not build `DSH -> Prime -> ACRYL` or `Prime -> embedded DSH runtime ->
ACRYL`. Build Prime execution and Cordis composition as peers under one ACRYL
runtime host (Spec §2).

## What stays, what's added, what's ported

Condensed from the full innovations matrix (Spec §4) and migration rules
(Spec §66–§68):

**KEEP from Prime, unchanged, first PoC:** persistent RLM Python, resident
daemon workers, durable RLM children, Pi TypeScript extensions, `/reload`,
Python-backed skills, goals/autonomy, provider integrations (Spec §3).

**ADD from Cordis/DSH:** services + `inject`, effects/fibers, typed events,
waterfall interception, `extend/isolate/intercept` scoping, HMR-aware plugin
tree, capability seams, declarative profiles/patches, event-sourced sessions
(shadow-first), reconstructable requests, deterministic prompt/tool ordering,
append-only context, cache-aware compaction, the MPA engine itself, the DSH
tool-execution pipeline, dynamic Cordis plugins, provider-neutral subagents,
output spill, read-before-write freshness, session search/query, generic
background jobs.

**ADAPT for Prime, not ported literally:** DSH's PTC/"code mode" idea becomes
Prime's existing persistent Python REPL exposing `acryl.capabilities.*`
instead of a new `run_code` tool (Spec §36). Sandboxing and the semantic LSP
seam are added later, after the execution pipeline is stable (Spec §35,
§60).

**Port from `acryldev/acryl`:** `acryl-control`'s provider-neutral
agent-control concepts (provider registry, worker identities, lifecycle
ownership, contracts, events), the principle behind
`acryl-harness-runtime/session-bridge.ts` (presentation derives from durable
session state, not the other way around, adapted to Prime types),
`durable-message.ts`'s surface-to-durable-port pattern, and the
repository-owned composition-over-upstream-capabilities pattern from
`coding-capabilities.ts` (Spec §66).

**Do NOT move yet:** Electron desktop, Web UI, Development Canvas, DSH web
client, DSH-patched client packages, marketplace UI, desktop packaging (Spec
§67). The PoC surface is Prime TUI + Prime CLI only.

**Do NOT port from DSH:** its concrete LLM adapters (Prime's `pi-ai` already
has broad provider support), its concrete agent loop (Prime's `AgentSession`
is the product), its web client, its goals/schedules (Prime already has
these), or DSH itself as an embedded sub-runtime (Spec §68).

## Milestones

Each milestone leaves the workspace green (build, typecheck, tests, and
Prime's basic TUI/Python/RLM functionality all still work — Spec §96) and
starts high-risk work behind a feature flag where noted (Spec §97). Full
acceptance criteria for each milestone are in the cited spec section; only
the gate is summarized here.

| # | Milestone | Gate | Spec |
|---|---|---|---|
| M0 | Upstream baseline | `amide == working Prime Agent`, no functional changes, upstream commit recorded in `UPSTREAMS.md` | §70 |
| M1 | Cordis runtime with zero behavior change | One root Cordis context per worker reaches `ACTIVE`; survives TUI detach; clean `DISPOSED` on shutdown | §71 |
| M2 | Migrate `acrAgentControl` | Prime becomes the first registered provider; register/attach/dispatch/dispose all tested | §72 |
| M3 | MPA observability before changing behavior | `/cache` command; systemHash/toolHash/messageHash/LCP/first-difference captured; baseline established, nothing optimized yet | §73 |
| M4 | `PromptBlock` assembler | `ACRYL_MPA=1` flag; new assembler reproduces old rendered prompt exactly before separating planes | §74 |
| M5 | Stable context ordering | Stable session-start context moves before the variable user prompt; dynamic per-turn data stays out of the stable prefix | §75 |
| M6 | Append-only context updates | `ContextMessage` version/supersedes; goal state, harness refinement, skill/runtime changes stop rewriting the system prompt | §76 |
| M7 | Stable capability gateway | New Cordis capability loads with unchanged native tool schema and unchanged cache epoch; Python can discover/use it — core PoC criterion | §77 |
| M8 | Shadow event log | ACRYL event log mirrors user/assistant/tool/context/request-header/agent events; `deriveMessages()` output matches Prime's real history | §78 |
| M9 | Reconstructable requests | Every routed request has enough recorded state (system, tools, surface, provider/model, settings, epoch) for deterministic replay tests | §79 |
| M10 | Cache-aware compaction | Summary request reuses the exact warm prefix; the original sequence is an exact prefix of the summary request | §80 |
| M11 | Dynamic Cordis plugins | Agent inspects runtime, defines/mounts/updates/stops a capability through Python; effects clean up correctly; session continues | §81 |
| M12 | Execution policies | Timeout guard, repeat-call detector, parallel/exclusive scheduling, output spill — before any sandboxing work | §82 |
| M13 | Filesystem observation guard | Read records version; edit compares; external modification between them yields `FS_STALE_VERSION`, never a silent overwrite | §83 |
| M14 | Sandbox/approval | `read-only` / `workspace-write` / `danger-full-access` modes; one-shot escalation; unauthorized side-effect paths tested extensively | §84 |
| M15 | Session query | Bounded event/session reads through Python first, optional SQLite FTS later — not five new native schemas | §85 |
| M16 | Presets and profiles | `base`/`minimal`/`coding`/`research`/`reviewer`; `--profile`/`--dump-config`; per-agent `agent.cordis.yml` | §86 |

## MPA in one page

The MPA doc's tighter 4-phase porting table maps directly onto the milestones
above — read it as the concrete implementation angle on the same work:

| MPA doc phase | Deliverable | Maps to |
|---|---|---|
| Phase 1: Core Determinism | Port `DeterministicPromptEngine` and sorted tool-schema builder; replace Prime's legacy prompt assembly | M4 |
| Phase 2: Monotonic Ingestion | `<system-reminder>` late-ingestion pipeline; `AGENTS.md`/workspace discoveries become append-only history entries, never system-prompt rewrites | M5–M6 |
| Phase 3: Warm Compaction | `WarmPrefixCompactor` replaces the standard summarizer; enforce warm-prefix replay during truncation | M10 |
| Phase 4: Auditing & Cordis Kernel | Cordis kernel into Prime's daemon/REPL loop; `EnvelopeAuditor`; step-by-step cache telemetry (`StepCacheTelemetry`, the `/cache`-style terminal report) | M1, M3 |

The MPA doc's core invariant governs every one of these phases: for any two
consecutive requests, `R_{n+1} = R_n ⊕ Δ_{n+1}` — the next request is the
previous request plus a strictly-appended tail, never a rebuild (MPA doc §1).

## Hard invariants

Reproduced in full from Spec §95 — these are short, load-bearing, and belong
directly in the navigator, not just the long spec:

1. TUI never owns durable execution.
2. Cordis worker context survives TUI detach.
3. Every plugin-owned side effect has one lifecycle owner.
4. Consumers depend on capability definitions, not providers.
5. Model-visible state must eventually be reconstructable from durable events.
6. Ordinary conversation progress is append-only.
7. An append-safe transition may not modify an earlier request prefix.
8. Prompt/tool order is deterministic.
9. Dynamic runtime capability != dynamic model schema.
10. Python is a programmable facade. TypeScript/Cordis remains authoritative.
11. `/reload` must dispose old registrations before mounting replacements.
12. A hard security denial cannot be relaxed by downstream middleware.
13. Unknown side-effect outcome after crash must not be blindly replayed.
14. Large data should be addressable externally instead of repeatedly injected.

## PoC success criteria

The experiment succeeds when all of the following hold (Spec §101):

- **Prime capabilities remain intact:** TUI, daemon sessions, detach/attach,
  persistent Python, RLM children, `/reload`, TS extensions, Python skills,
  `/refine`, `/goal`, autonomous mode.
- **Cordis works as runtime substrate:** services, `inject`, fibers, effects,
  typed events, waterfall, scope, hot replacement, diagnostics.
- **MPA works:** deterministic system sections, deterministic tool schemas,
  stable context before user prompt, append-only runtime updates, explicit
  cache epochs, request-shape recorder, monotonicity tests, cache-aware
  compaction.
- **Self-extension works:** model can inspect the Cordis runtime, create and
  mount a capability, use it through Python, keep the model ABI unchanged,
  and update/dispose the plugin safely.
- **Session architecture works:** append-only event log, derived model
  surface, request headers, deterministic replay, crash semantics.

## Upstream strategy

Three conceptual sources, kept distinct (Spec §99):

- **Prime upstream** — execution/RLM/product base.
- **DSH upstream** — architectural reference plus selectively ported MIT
  code, via `acryldev/acryl`'s existing Cordis experiments.
- **`acryldev/acryl`** — already-proven Cordis/control-plane patterns to
  port, not re-derive from scratch.

Actual commits, ported files, and local modifications are recorded in
`UPSTREAMS.md`, not here.
