/**
 * Pre-rendered ASCII splash marks.
 *
 * `AMIDE_LOGO` is the upstream Prime Agent mark (source:
 * assets/brand/prime-butterfly.svg; re-render at any width with
 * `uv run scripts/render-logo.py --width N`), kept for attribution/reference
 * — AMIDE is a fork of Prime Agent, not the same project.
 * `AMIDE_WORDMARK_LOGO` is this project's own splash mark: a 5x7
 * block-letter wordmark, built programmatically (5-column letter grids
 * joined with a single-space separator, verified 29 columns per row)
 * rather than hand-transcribed, to avoid ASCII-art alignment errors.
 */

/** ~10 rows × 32 cols. Upstream Prime Agent mark — half-block butterfly. */
export const AMIDE_LOGO = `                          ▄▄███▀
    ▄▄▄▄▄              ▄█████▀
    ██████▄         ▄██████▀
   ▄███▀███▄     ▄███▀▄██▀
   ███ ▄████▄▄▄████▀▄▄██
  ▀██  ▀█████████▀▀▀▀▀▀
  ▄██   ██████▀▀ ▄███
 █████    ▀█▄▄▄█████▀
███████▄  ████████▀
▀███▀▀    █████▀`;

/**
 * 7 rows × 29 cols. AMIDE's own splash mark — a block-letter wordmark.
 * The real brand mark is assets/brand/amide-logo.svg (white) /
 * amide-logo-black.svg (black), used in README/docs/marketing. The TUI
 * can only paint terminal character cells, not real vector graphics, so
 * this is a from-scratch block-letter interpretation for that constraint,
 * not a direct rendering of the SVG.
 */
export const AMIDE_WORDMARK_LOGO = ` ███  █   █ █████ ████  █████
█   █ ██ ██   █   █   █ █
█   █ █ █ █   █   █   █ █
█████ █   █   █   █   █ ████
█   █ █   █   █   █   █ █
█   █ █   █   █   █   █ █
█   █ █   █ █████ ████  █████`;
