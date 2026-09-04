/**
 * Pre-rendered ASCII splash marks.
 *
 * `PRIME_BUTTERFLY_LOGO` is the upstream Prime Agent mark (source:
 * assets/brand/prime-butterfly.svg; re-render at any width with
 * `uv run scripts/render-logo.py --width N`), kept for attribution/reference.
 * `ACRYL_GEM_LOGO` is this fork's ACRYL splash mark: a filled diamond,
 * chosen over a pixel-font wordmark for guaranteed row-by-row symmetry.
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

/** 11 rows × 11 cols, symmetric. This fork's ACRYL splash mark (source: assets/brand/acryl-gem.svg). */
export const ACRYL_GEM_LOGO = `     █
    ███
   █████
  ███████
 █████████
███████████
 █████████
  ███████
   █████
    ███
     █     `;
