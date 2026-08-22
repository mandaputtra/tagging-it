// Client bridge: reads a batch + its codes from the IndexedDB store, pushes
// them to SheetLive via the `sheet:loaded` event, and renders barcode SVGs
// into the label placeholders (bwip-js vector output — crisp at print DPI).
import type { BatchRecord, CodeRecord, SheetLoadedWire } from "./types.js";

/** bwip-js `toSVG` options — the subset the sheet uses. */
export interface BarcodeOpts {
  bcid: string;
  text: string;
}

/**
 * Builds the `sheet:loaded` wire payload from store records.
 */
export function buildSheetPayload(batch: BatchRecord, codes: CodeRecord[]): SheetLoadedWire {
  if (codes.some((code) => code.batch_id !== batch.id)) {
    throw new Error("codes reference a different batch than the one loaded");
  }
  return { batch, codes };
}

/**
 * Injects an SVG into every `.barcode[data-code-id]` placeholder in the
 * container. Idempotent: placeholders already holding an `<svg>` are skipped.
 * A throwing renderer leaves an inline error message instead of crashing.
 */
export function renderBarcodes(
  container: HTMLElement,
  toSvg: (opts: BarcodeOpts) => string,
): void {
  container.querySelectorAll(".barcode").forEach((el) => {
    if (el.querySelector("svg")) return;
    const opts: BarcodeOpts = {
      bcid: (el as HTMLElement).dataset.bcid || "code128",
      text: (el as HTMLElement).dataset.text || "",
    };
    try {
      el.innerHTML = toSvg(opts);
    } catch (err) {
      el.textContent = `barcode error: ${err instanceof Error ? err.message : String(err)}`;
    }
  });
}
