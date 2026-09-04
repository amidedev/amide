# Wayfinder map: ACRYL-PADSH — Prime × Cordis × MPA architectural PoC

Labels: `wayfinder:map`

## Destination

Prove the ACRYL-PADSH success criteria in
`docs/ACRYL-PADSH Implementation Specification.md` §101: Prime's existing
capabilities remain fully intact, Cordis works as the runtime composition
substrate (services, `inject`, fibers, effects, typed events, waterfalls,
scope, hot replacement, diagnostics), the Monotonic Prompt Architecture (MPA)
holds (deterministic ordering, append-only updates, explicit cache epochs,
request-shape recording, monotonicity tests, cache-aware compaction), Prime
can self-extend through a stable Python capability ABI without breaking that
ABI, and the session architecture becomes an append-only event log with a
derived model surface. If this PoC succeeds, its architecture becomes the new
engineering basis for `acryldev/acryl`; if it fails, this repository is
disposable and nothing here is load-bearing for the shipped product.

## Notes

- Domain: experimental fork of `PrimeIntellect-ai/prime-agent`, absorbing
  architectural ideas from DeepSeek Harness / Cordis (via `acryldev/acryl`)
  without embedding DSH as a sub-runtime. See constitution Principle I.
- Always read: `.specify/memory/constitution.md`,
  `docs/ACRYL-PADSH Implementation Specification.md`,
  `docs/MonotonicPromptArchitecture_quick_overview_in_relation_to_DSH_and_ACRYL_project.md`,
  `docs/ACRYL-PADSH-ROADMAP.md`,
  `docs/workmethodology/acryl-hybrid-engineering-methodology.md`.
- Skills: `/speckit-constitution`, `/speckit-specify`, `/speckit-plan`,
  `/speckit-tasks`, `/speckit-clarify`, `/speckit-analyze`, `/speckit-implement`,
  `/speckit-converge`.
- The two docs above are the detailed architectural spec and the tighter MPA
  technical spec, respectively. `docs/ACRYL-PADSH-ROADMAP.md` is the
  navigator built from both; treat it as the milestone-sequencing source of
  truth and the two spec docs as the reference for implementation detail.
- This repo's `docs/ACRYL-ROADMAP.md` describes the current, still-active
  `acryldev/acryl` product (DSH + Tauri/Electron foundation) and was copied
  in only as reference context. It does not describe this project's
  direction — do not treat it as authoritative here.

## Decisions so far

- [Bootstrap this Wayfinder map, constitution, and roadmap](../../docs/ACRYL-PADSH-ROADMAP.md) —
  user directive 2026-09-04: initialize the same Spec Kit + Wayfinder +
  Ponytail methodology already used in `acryldev/acryl`, before any
  Milestone-0-and-beyond implementation work starts.
- **First implementation slice is Milestone 0 — upstream baseline**
  (Implementation Spec §70): the repository must equal a working, unmodified
  Prime Agent before any Cordis/MPA work begins. No functional changes yet.
  Acceptance: Prime TUI starts, Python works, `rlm()` works, `/reload` works,
  daemon attach works, existing Prime tests are green, and the upstream
  commit is recorded in `UPSTREAMS.md`.
- **A light, surface-only rebrand to ACRYL happens now, in parallel with
  Milestone 0** — user directive 2026-09-04: repo identity (root
  `package.json` name, `README.md` header, `LICENSE` notice, `UPSTREAMS.md`,
  `THIRD_PARTY_NOTICES.md`, TUI startup banner) becomes ACRYL-branded
  immediately. The deep internal rename (the ~15+ literal "Prime Agent"
  strings inside `packages/coding-agent/src/**` business logic,
  `PRIME_AGENT_*` env vars, `prime-agent.sh`, `install.sh`) is explicitly
  deferred to later, gradual work — it is not part of Milestone 0's "no
  functional changes" acceptance bar and must not be conflated with it.

## Not yet specified

- The exact upstream commit `7b72016` ("init acryl-padsh") was imported
  from. Verified `7b72016` is close to, but not identical to, upstream tag
  `v0.9.1` (real diffs in `agent-session.ts`, `event-log.ts`,
  `semantic-edges.ts`, and others) — see `UPSTREAMS.md`. Not bisected to an
  exact commit; low priority unless a future port needs to diff against a
  precise upstream point.
- Exact `AcrylRuntimeHost` mount point inside Prime's resident-worker startup
  path (Implementation Spec §7) — needs a source-level read of
  `packages/coding-agent/src/core/kernel/bootstrap.ts` and the daemon
  supervisor before Milestone 1 can be planned in Spec Kit.
- Where Prime's own TUI startup banner/logo is actually rendered from — not
  yet located (checked `packages/coding-agent/src/modes/shared/startup-notices.ts`,
  which only holds an unrelated update-notice string). Needed before the
  banner-swap part of the rebrand can be implemented.
- The exact Cordis service names/shapes for `ctx.acrCapabilities`,
  `ctx.acrSessionLog`, `ctx.acrAgentControl`, etc. (Implementation Spec §8.1)
  — deferred to Milestone 1/2 `plan.md`, not decided here.
- Whether `acryl-control`'s existing provider-neutral `acrAgentControl`
  concepts (Implementation Spec §54, §66) port cleanly onto Prime's
  `AgentConnection`/`AgentSession` split, or need a different seam — a
  research question for Milestone 2.

## Out of scope

- Embedding DeepSeek Harness itself as a sub-runtime, or porting its concrete
  agent loop, LLM adapters, web client, or goals/schedules wholesale
  (Implementation Spec §68).
- Electron desktop, Web UI, Development Canvas, DSH web client, DSH-patched
  client packages, marketplace UI, desktop packaging (Implementation Spec
  §67) — the PoC surface is Prime TUI + Prime CLI only.
- Rewriting `agent-session.ts` directly, or replacing Prime's persistence
  model in one step, before an adapter proves the seam (Implementation Spec
  §3, §38 — constitution Principles IV and VIII).
- The deep "Prime Agent" → ACRYL internal string/env-var rename (see
  Decisions so far) — tracked as later, gradual work, not part of any
  current milestone.
- Sandboxing and the semantic LSP seam before the basic execution pipeline
  and MPA are stable (Implementation Spec §35, §60, §82 — Milestones 12/14
  come after 3–11).
