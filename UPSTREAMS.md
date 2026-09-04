# Upstreams

ACRYL-PADSH combines three upstream sources. This file records exactly which
commit of each was used, and what has been ported or changed locally, per
`docs/ACRYL-PADSH Implementation Specification.md` §99–§100.

## Prime Agent (execution/RLM/product base)

- Repository: `PrimeIntellect-ai/prime-agent` (also incorporates
  `earendil-works/pi` as the `@earendil-works/pi-*` workspace packages —
  `packages/{tui,agent,ai}` — see `docs/ACRYL-PADSH Implementation Specification.md`
  §15 for why these stay untouched).
- `git remote add upstream https://github.com/PrimeIntellect-ai/prime-agent.git`
  is configured in this checkout.
- **Verified, not assumed** (`git diff --stat`, 2026-09-04): `7eda78d`
  ("Initial commit") is an empty 3-file placeholder (`.gitignore`, `LICENSE`,
  `README.md`) — not real Prime Agent content, despite being this repo's
  first commit. The actual import landed in `7b72016` ("init acryl-padsh",
  1239 files). Its `package.json` version (`0.9.1`) matches upstream tag
  `v0.9.1` (`81ae3cb34d27d38ee37f9e205a1e73694993b344`), but the two are
  **not identical** — `git diff --stat 7b72016 v0.9.1` shows real behavioral
  differences in core files (e.g. `packages/coding-agent/src/core/agent-session.ts`,
  `event-log.ts` removed, `semantic-edges.ts` removed, `agents-view-state.ts`),
  not just cosmetic ones. `7b72016` looks like an import from a pre-`v0.9.1`
  snapshot with the version field bumped, or from a differently-configured
  branch — **not yet bisected to an exact upstream commit**. Do not treat
  `v0.9.1` as this fork's precise base until that's resolved; treat `7b72016`
  itself as the authoritative base for now.
- License: MIT.

## DeepSeek Harness / Cordis (architectural reference)

- Repository: `deepseek-ai/deepseek-harness`.
- Reference commit at the time this fork's methodology/roadmap was written:
  `cd5ef8148158c3a752a658978873241fdf8e2bbc` (`dsh-v0.1.2-alpha.1`), as pinned
  in `acryldev/acryl`'s `upstream.json` at the same time.
- Not embedded as a sub-runtime. Only architectural patterns and, where
  explicitly ported, MIT-licensed source are used — see
  `docs/ACRYL-PADSH Implementation Specification.md` §68 for what is
  deliberately not ported.
- License: MIT.

## `acryldev/acryl` (proven Cordis/control-plane experiments)

- Repository: `acryldev/acryl`.
- Source commit this fork drew methodology, roadmap structure, and
  architectural reference from: `fa9a1c3` ("fix(release): exclude colliding
  per-target receipt/checksum files from GitHub release assets").
- License: MIT.

## Ported files/concepts

Nothing has been ported into source yet — this fork is currently at
Milestone 0 (upstream baseline, no functional changes). This section will be
updated as each Spec Kit ledger under `specs/` lands a port from
`acryldev/acryl` or DeepSeek Harness, naming the exact source path, the
destination path, and what changed locally.

## Local modifications so far

- `docs/workmethodology/acryl-hybrid-engineering-methodology.md`,
  `.specify/memory/constitution.md`, `specs/000-wayfinding/`,
  `docs/ACRYL-PADSH-ROADMAP.md`: Spec Kit + Wayfinder + Ponytail methodology
  bootstrap, adapted from `acryldev/acryl`'s equivalent setup.
- `package.json`, `README.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`: surface
  rebrand to ACRYL-PADSH identity. No internal Prime Agent source, env vars,
  or install scripts were touched — see `specs/000-wayfinding/map.md`
  "Decisions so far" for the deferred deep-rename scope.
