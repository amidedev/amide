/**
 * Pre-rendered ASCII splash marks.
 *
 * `PRIME_BUTTERFLY_LOGO` is the upstream Prime Agent mark (source:
 * assets/brand/prime-butterfly.svg; re-render at any width with
 * `uv run scripts/render-logo.py --width N`), kept for attribution/reference.
 * `ACRYL_WORDMARK_LOGO` is this fork's ACRYL splash mark: a 5x7 block-letter
 * wordmark, built programmatically (5-column letter grids joined with a
 * single-space separator, verified 29 columns per row) rather than
 * hand-transcribed, to avoid ASCII-art alignment errors.
 */

/** ~10 rows × 32 cols. Upstream Prime Agent mark — half-block butterfly. */
export const PRIME_BUTTERFLY_LOGO = `                          ▄▄███▀
    ▄▄▄▄▄              ▄█████▀
    ██████▄         ▄██████▀
   ▄███▀███▄     ▄███▀▄██▀
   ███ ▄████▄▄▄████▀▄▄██
  ▀██  ▀█████████▀▀▀▀▀▀
  ▄██   ██████▀▀ ▄███
 █████    ▀█▄▄▄█████▀
███████▄  ████████▀
▀███▀▀    █████▀`;

/** 7 rows × 29 cols. This fork's ACRYL splash mark — a block-letter wordmark. */
export const ACRYL_WORDMARK_LOGO = ` ███   ████ ████  █   █ █
█   █ █     █   █ █   █ █
█   █ █     █   █  █ █  █
█████ █     ████    █   █
█   █ █     █ █     █   █
█   █ █     █  █    █   █
█   █  ████ █   █   █   █████`;
