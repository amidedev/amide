# ACRYL-PADSH Constitution

This constitution governs every spec, plan, task, and plugin written in this
repository. It is the executable policy for Spec Kit, Wayfinder, and Matt
Pocock SDD here. If a later document conflicts with this file, this file wins
until it is deliberately amended. It exists alongside, and does not replace,
the full detail in `docs/ACRYL-PADSH Implementation Specification.md` and
`docs/MonotonicPromptArchitecture_quick_overview_in_relation_to_DSH_and_ACRYL_project.md`
(the "Implementation Spec" and "MPA doc" below) — this file states the rules
that govern every task; those files state the target architecture in detail.

## Core Principles

### I. Prime executes, Cordis composes, ACRYL mediates

Prime Agent remains the execution host: daemon supervisor, resident workers,
`AgentSession`, persistent Python kernel, RLM children, skills, TS extensions,
`/reload`, goals, autonomous mode. Cordis becomes the composition and
lifecycle substrate: services, effects, fibers, typed events, waterfalls,
scoping. ACRYL-owned code (`packages/coding-agent/src/acryl/`) mediates
between them. Never build "DSH → Prime → ACRYL" or "Prime → embedded DSH
runtime → ACRYL" — build Prime and Cordis as peers under one ACRYL runtime
host (Implementation Spec §2).

### II. Capabilities may evolve dynamically; the model-facing ABI should not

A new Cordis capability behind `acryl.capabilities.call(...)` does not require
a prompt cache epoch. A new native JSON tool schema does. Prime's persistent
IPython REPL is the primary programmable, model-facing surface; TypeScript
stays authoritative underneath it (Implementation Spec §29–§31, §103).

### III. Within a cache epoch, previously emitted context is immutable

New knowledge is appended, never rewritten. `R_{n+1} = R_n ⊕ Δ_{n+1}` for any
two consecutive requests in an active session, where `⊕` is tail
concatenation (MPA doc §1). Mutable facts (goals, harness refinement, skill
catalogue changes) become new versioned `<system-reminder>`/context entries
that supersede, not overwrite. This is the single most important invariant in
the project — see Implementation Spec §18–§26.

### IV. Do not begin by refactoring `agent-session.ts`

Prime concentrates substantial runtime behavior in `agent-session.ts` and
related core files. Replacing it before proving new seams turns this
experiment into a rewrite. Use the adapter chain instead: Prime implementation
→ ACRYL adapter → Cordis service. Invert ownership only after parity is
proven on a vertical slice (Implementation Spec §3).

### V. Consumers depend on capability definitions, not concrete providers

Every capability has up to three roles: Service Definition, Service Provider,
Consumer. Changing a provider (e.g. `LocalFsProvider` → `SandboxFsProvider`)
must never force a change to the model-facing contract or to consumer code
that only imported the service name. `ctx.inject`-declared dependencies hold
consumers in `PENDING` until satisfied; Cordis auto-reloads them if a
dependency disappears (Implementation Spec §8, §14).

### VI. Every plugin-owned side effect has one lifecycle owner

Timers, watchers, sockets, PTYs, subprocesses, event subscriptions, Python
bridge handlers, daemon/IPC listeners, temporary files, registered
capabilities, and background jobs are acquired inside one owning
`ctx.effect()` and released by its disposer when the Fiber unloads
(Implementation Spec §9–§10).

### VII. Ordinary conversation progress is append-only; structural change is an explicit epoch

Append-safe events (new user prompt, assistant response, tool call/result,
goal update, runtime observation) never bump the cache epoch. Epoch-breaking
events (model/provider switch, base prompt upgrade, native tool schema or
order change, compaction) always do, and must be labeled with a reason —
never misclassified as an MPA bug (Implementation Spec §23, §46).

### VIII. Model-visible state must eventually be reconstructable from durable events

The event log is authoritative; messages are a projection. Migrate to this in
stages — Prime remains authoritative first, ACRYL's event log shadows it,
then the projection is compared, then it becomes the request-builder's
source, and only then does it become the authoritative model-surface source
(Implementation Spec §37–§39, §78–§79). Do not replace Prime persistence in
one step.

### IX. A hard security denial cannot be relaxed by downstream middleware

Waterfall order is: extensible pre-execute hooks, then monotonic hard guards,
then execution. A strict `DENIED` from a hard guard may never be turned into
`ALLOW` by a later plugin in the chain (Implementation Spec §34, §57–§58).

### X. Unknown side-effect outcome after crash must not be blindly replayed

If recovery finds a tool call was recorded as started but has no durable
result, record `TOOL_OUTCOME_UNKNOWN` and make the agent reason about
idempotency — never auto-retry a possibly-already-executed destructive action
(Implementation Spec §42).

## What this project does NOT do (scope discipline)

Both directions of scope creep are explicitly forbidden, not just discouraged:

- **Not embedding DSH as a sub-runtime.** Do not port DSH's LLM adapters
  wholesale (Prime's `pi-ai` already has broad provider support — wrap it if
  needed), DSH's concrete agent loop (Prime's RLM-aware `AgentSession` is the
  product), DSH's web client, or DSH goals/schedules merely to duplicate what
  Prime already does (Implementation Spec §68).
- **Not moving old-ACRYL product surfaces here yet.** Electron desktop, Web
  UI, Development Canvas, the DSH web client, DSH-patched client packages,
  marketplace UI, and desktop packaging are out of scope for this PoC. The
  surface is Prime TUI + Prime CLI only, until the runtime architecture is
  proven (Implementation Spec §67).
- **Not rewriting Prime/Pi's TypeScript extension system.** Bridge existing
  registrations into Cordis ownership via `PrimeExtensionAdapter`; `/reload`
  must keep working for hand-written extensions (Implementation Spec §15).

## Licensing and upstream discipline

Prime Agent, Pi, DeepSeek Harness, and `acryldev/acryl` are all MIT.
ACRYL-PADSH stays MIT. When source is copied or adapted, retain required
upstream copyright/license notices and record the origin in
`THIRD_PARTY_NOTICES.md`. Every substantial port from `acryldev/acryl` or
DeepSeek Harness gets an entry in `UPSTREAMS.md`: what was ported, from which
commit, and what changed locally (Implementation Spec §99–§100).

## Execution discipline

- High-risk migrations (Cordis mount, MPA assembler, event log, capability
  gateway, dynamic Cordis plugins) start behind a feature flag
  (`ACRYL_CORDIS`, `ACRYL_MPA`, `ACRYL_EVENT_LOG`, `ACRYL_CAPABILITY_GATEWAY`,
  `ACRYL_DYNAMIC_CORDIS`) and only lose the flag after a parity test proves no
  regression (Implementation Spec §97).
- Every milestone leaves the workspace green: build, typecheck, tests, and
  Prime's basic TUI/Python/RLM functionality all still work (Implementation
  Spec §96).
- Architecture tests are executable, not just documentation — e.g. "Prime TUI
  package may not import the dynamic plugin runner," "Capability consumers
  may not import concrete providers" (Implementation Spec §98).
- Follow `docs/workmethodology/acryl-hybrid-engineering-methodology.md` for
  the Spec Kit lifecycle (specify → clarify → plan → tasks → analyze →
  implement → converge), vertical-slice execution, RED-GREEN-REFACTOR, and
  Ponytail minimalism. That file is the operating method; this constitution
  is the set of rules it must never violate for this specific project.

## Governance

This constitution supersedes ad hoc practice. Amend it only with an explicit
decision recorded in `specs/000-wayfinding/map.md`, citing the Implementation
Spec or MPA doc section that motivates the change, or recording a new
project-specific decision if neither source doc covers it. A milestone's
acceptance criteria (Implementation Spec §101) is the definition of done for
the PoC as a whole; do not declare success on partial evidence.

**Version**: 1.0.0 | **Ratified**: 2026-09-04 | **Last Amended**: 2026-09-04
