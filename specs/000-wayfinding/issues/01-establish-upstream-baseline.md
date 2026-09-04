# Establish the Milestone 0 upstream baseline

Type: task
Status: open

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
