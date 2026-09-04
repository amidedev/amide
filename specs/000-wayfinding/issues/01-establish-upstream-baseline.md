# Establish the Milestone 0 upstream baseline

Type: task
Status: in-progress

## Question

Nothing to decide — this is Milestone 0 from
`docs/ACRYL-PADSH Implementation Specification.md` §70, and it is the
required first slice before any Cordis or MPA work begins.

Do:

1. Confirm `PrimeIntellect-ai/prime-agent` is configured as an upstream
   remote (or record the exact commit this fork started from if a remote
   isn't wired up yet).
2. Make no functional changes to Prime's own code in this task.
3. Run Prime's complete existing CI/test suite and record the result.
4. Record the upstream commit, and this repo's starting commit, in
   `UPSTREAMS.md`.

Acceptance (Implementation Spec §70):

- Prime TUI starts.
- Python works.
- `rlm()` works.
- `/reload` works.
- Daemon attach works.
- Existing tests are green.

## Evidence (2026-09-04)

Verified so far, done in this order because they're independently checkable
without a real interactive session:

- **Upstream remote**: `git remote add upstream
  https://github.com/PrimeIntellect-ai/prime-agent.git`, fetched. See
  `UPSTREAMS.md` and `map.md` "Not yet specified" for what this fetch
  revealed: this fork's actual content commit is `7b72016`, not `7eda78d`
  (which is an empty 3-file placeholder) — a correction to what was
  originally recorded, caught by diffing against the fetched upstream
  rather than assumed.
- **No functional changes made** in this task — confirmed by `git status`/
  `git diff` showing nothing beyond `UPSTREAMS.md` and this file.
- **Per-package test suites** (`npx vitest run` / `node --test`, not the
  root `npm test` alias, per this repo's `AGENTS.md`):
  - `packages/agent`: 70/70 pass.
  - `packages/tui`: 750/750 pass.
  - `packages/coding-agent` (`npm run test:ci`, excluding
    `test/daemon-supervisor-process.test.ts` per its own CI script): 57
    failed / 4646 passed / 53 skipped (4756 total). Failures concentrate in
    `test/extensions-discovery.test.ts` (23), `test/extensions-runner.test.ts`
    (21), `test/extensions-input-event.test.ts` (7),
    `test/resource-loader.test.ts` (4), and daemon-spawning regression
    tests (`4600-supervisor-singleton`, `4685-daemon-client-modes`) — a
    pattern consistent with this sandboxed environment restricting real
    child-process spawning and some filesystem extension-discovery
    behavior, not a regression introduced here (no coding-agent source was
    touched before this run). **Not yet root-caused against a real
    unsandboxed environment** — recorded as observed, not diagnosed.
  - `packages/ai`: **inconclusive**. The run made almost no CPU progress
    over ~7 minutes and was killed rather than left to chase further —
    likely a network-dependent provider test with a long timeout in an
    environment with no configured API keys, but not confirmed.

Not yet verified (needs a real interactive terminal session, which this
harness doesn't have): Prime TUI actually starts and renders, Python REPL
works, `rlm()` spawns a working subagent, `/reload` round-trips, daemon
attach/detach works. These are the acceptance criteria's actual substance
and this ticket should stay `in-progress`, not closed, until a human (or an
agent with a real TTY) runs through them manually.

**Recommendation**: don't block Milestone 1 (Cordis mount) on fully
resolving the `packages/ai` hang or root-causing the 57 sandboxed failures
— they're independent of anything Milestone 1 touches. Do resolve the
interactive-session checklist above before calling Milestone 0 complete.
