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
