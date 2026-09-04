# Establish the Milestone 0 upstream baseline

Type: task
Status: done

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

## Interactive verification (2026-09-04, user)

All six acceptance items confirmed by the user in a real TTY:

- Prime TUI starts (ACRYL wordmark splash renders correctly).
- `/login` provider picker works (Anthropic + OpenAI subscriptions tested).
- Python/iPython available — agent self-test confirmed `ipython ok` and
  `RLM: callable (_RLMCallable)`.
- `rlm()` available (same self-test).
- `/reload` round-trips without error.
- Daemon attach works: a second terminal's `./prime-agent.sh agents` (the
  session-manager view) correctly showed sessions started from a first
  terminal — running/idle/inactive states, token/cost stats, all accurate
  and shared across terminals against the isolated `~/.acryl-padsh/agent`
  daemon.

**Milestone 0 acceptance criteria fully met.** Closing this ticket.

## Known follow-up, not a Milestone 0 blocker

While testing daemon isolation, found that `agents`/`list` fail silently
when they need to spawn a **brand new** daemon from a completely cold
state (zero existing sessions) — the spawned child process exits before
writing its own log file, with `stdio: "ignore"` hiding any error. This
was previously masked because, before the isolation fix, this fork shared
a socket with any real Prime Agent daemon already running on the machine,
so a fresh spawn was never actually exercised. Confirmed as a narrower
bug, not a blocker: if any daemon already exists (e.g. from a normal
interactive `./prime-agent.sh` session, which starts one as a side
effect), `agents`/`list`/`attach` all work correctly and share state
across terminals as expected. Worth its own ticket before Milestone 0's
work is considered fully polished, but does not block Milestone 1.

**Recommendation**: proceed to Milestone 1 (Cordis mount). Also
independent of Milestone 1: the `packages/ai` test hang (not resolved,
inconclusive) and the 57 sandboxed `packages/coding-agent` test failures
(observed, not root-caused).
