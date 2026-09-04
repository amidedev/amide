# Mount a Cordis runtime host with zero behavior change

Type: task
Status: open

## Question

Nothing to decide on direction — this is Milestone 1 from
`docs/ACRYL-PADSH Implementation Specification.md` §71. Blocked on
Milestone 0 (`01-establish-upstream-baseline.md`) landing first, and on
locating the exact Prime resident-worker startup path this must hook into
(see "Not yet specified" in `map.md`) before a Spec Kit `plan.md` can name
concrete files.

## Research (2026-09-04)

Located the candidate files for where `AcrylRuntimeHost` mounts. Not read in
full yet — both are large enough (`daemon-supervisor.ts` 6937 lines,
`daemon-mode.ts` 7547 lines) that reading and planning against them deserves
its own session with full context budget and a proper `/speckit-plan`, not a
rushed pass at the tail of a long bootstrap session:

- `packages/coding-agent/src/modes/daemon/daemon-supervisor.ts` — the daemon
  supervisor itself (owns worker processes, likely where "one root Cordis
  context per Prime resident worker" per Implementation Spec §6.1 needs to
  hook in).
- `packages/coding-agent/src/modes/daemon/daemon-mode.ts` — the daemon-mode
  entry point.
- `packages/coding-agent/src/cli/owned-session-worker.ts` (532 lines,
  already read) is a **different, unrelated** thing: ephemeral
  print/json/rpc-mode worker subprocesses, not the persistent daemon-backed
  resident worker that survives TUI detach. Do not confuse the two.
- `packages/coding-agent/src/core/kernel/bootstrap.ts` (916 lines) is the
  general startup path — worth checking for where daemon/worker mode
  branches, before diving into the two large files above.

Next action for whoever picks this up: read `bootstrap.ts` first to find the
actual branch point into daemon/resident-worker startup, then read only the
relevant sections of `daemon-supervisor.ts`/`daemon-mode.ts` (not the whole
files) before writing a `/speckit-plan` for this milestone.

Do, once unblocked:

1. Install/reuse `@deepseek-ai/cordis`.
2. Create `AcrylRuntimeHost` (Implementation Spec §7) and mount exactly one
   root Cordis context per Prime resident worker — not in the TUI, not in the
   daemon supervisor.
3. Create a session child context per `mountSession()`.
4. Make no model-behavior changes in this task.

Acceptance (Implementation Spec §71):

- Worker starts → Cordis reaches `ACTIVE`.
- TUI detaches → worker remains, Cordis remains.
- Worker shutdown → all Cordis fibers reach `DISPOSED`, no timer/listener
  leaks.
