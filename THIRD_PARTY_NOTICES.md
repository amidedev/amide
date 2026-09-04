# Third-Party Notices

AMIDE is MIT-licensed and built on other MIT-licensed work. This file
records the required attribution for that upstream work, per
`docs/AMIDE Implementation Specification.md` §100. See `UPSTREAMS.md`
for the exact commits and what has been ported.

## Prime Agent / Pi

- Prime Agent — Copyright (c) 2026 Prime Intellect —
  <https://github.com/PrimeIntellect-ai/prime-agent> — MIT License.
- Pi (`@earendil-works/pi-*` packages: `packages/tui`, `packages/agent`,
  `packages/ai`) — Copyright (c) 2025 Mario Zechner —
  <https://github.com/earendil-works/pi> — MIT License.

The full upstream license text is preserved in this repository's `LICENSE`
file.

## DeepSeek Harness / Cordis

- DeepSeek Harness (including the Cordis plugin kernel) —
  <https://github.com/deepseek-ai/deepseek-harness> — MIT License.

Architectural patterns (Cordis composition, Monotonic Prompt Architecture,
capability seams, event-sourced sessions) are referenced and, where noted in
`UPSTREAMS.md`, source is adapted with attribution. DeepSeek Harness itself is
not embedded as a sub-runtime.
