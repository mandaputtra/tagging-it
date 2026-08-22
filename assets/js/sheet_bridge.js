// Client bridge: reads a batch + its codes from the IndexedDB store, pushes
// them to SheetLive via the `sheet:loaded` event, and renders barcode SVGs
// into the label placeholders (bwip-js vector output — crisp at print DPI).

/**
 * Builds the `sheet:loaded` wire payload from store records.
 * @param {object} batch - batch record from the store
 * @param {Array<object>} codes - code records from the store
 * @returns {{batch: object, codes: Array<object>}}
 */
export function buildSheetPayload(batch, codes) {
  if (codes.some((code) => code.batch_id !== batch.id)) {
    throw new Error("codes reference a different batch than the one loaded");
  }
  return { batch, codes };
}

/**
 * Injects an SVG into every `.barcode[data-code-id]` placeholder in the
 * container. Idempotent: placeholders already holding an `<svg>` are skipped.
 * A throwing renderer leaves an inline error message instead of crashing.
 *
 * @param {HTMLElement} container - element containing the label grid
 * @param {(opts: {bcid: string, text: string}) => string} toSvg - bwip-js `toSVG`
 */
export function renderBarcodes(container, toSvg) {
  container.querySelectorAll(".barcode").forEach((el) => {
    if (el.querySelector("svg")) return;
    const opts = { bcid: el.dataset.bcid || "code128", text: el.dataset.text || "" };
    try {
      el.innerHTML = toSvg(opts);
    } catch (err) {
      el.textContent = `barcode error: ${err.message}`;
    }
  });
}
