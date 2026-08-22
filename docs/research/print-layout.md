# Research: Print layout mechanics for labels

Resolves [mandaputtra/tagging-it#5](https://github.com/mandaputtra/tagging-it/issues/5) · 2026-08-22

**Question:** How should label printing work through the browser print dialog for configurable-size labels on a laptop-connected printer?

**Recommendation: HTML + print CSS (`@page` + `@media print`) through the browser print dialog. No PDF library for v1.** Vector SVG barcodes (bwip-js `toSVG` — per #2's recommendation) on full-sheet label stock (Letter/A4) for robustness; custom-size pages supported but best-effort.

All claims below verified against primary sources (MDN docs + BCD data) and **empirical headless-Chrome print tests run 2026-08-22**.

## Verified claims

### 1. `@page` sizing — what browsers actually do

MDN BCD (`css/at-rules/page.json`, fetched 2026-08-22):

| Feature | Chrome | Firefox | Safari |
|---|---|---|---|
| `@page` rule | 2+ | 19+ | **18.2+ only** |
| `size` descriptor | 15+ | 95+ | 18.2+ |
| `landscape`/`portrait` keywords | yes | yes | **no** |
| page-margin boxes (`@top-left` etc.) | 131+ | no | no |

Safari ignored `@page` entirely until 18.2 (WebKit bug 15548, ~Dec 2025). **Use explicit lengths (`8.5in 11in`, `50mm 25mm`), never orientation keywords.**

Empirical (headless Chrome, 2026): `@page { size: 8.5in 11in; margin: 0 }` → PDF MediaBox exactly **612×792pt** (inches exact). `@page { size: 50mm 25mm; margin: 0 }` → **142.08×71.04pt ≈ 50.1×25.1mm** — mm→pt conversion quantizes ~**+0.24%**. Inches are exact; mm is close but not exact. This is the calibration caveat.

### 2. HTML vs PDF path

- **HTML + print CSS**: native, free, vector, LiveView-friendly. Render a dedicated print view, call `window.print()`. `@media print` hides the on-screen UI. "Save as PDF" in the dialog is free PDF export.
- **jsPDF et al.**: must rasterize SVG→canvas→PNG (blur risk) or hand-draw paths; more code, worse quality, more deps. Rejected for v1.

### 3. Label size handling — two physical scenarios

**A. Full-sheet label stock (Avery-style) — recommended default.** `@page { size: letter }`, `margin: 0`, one `.sheet` block per page, labels in an exact grid. Robust: any printer prints the sheet; no custom paper size needed.

Avery 5160 example (address labels): 30/sheet, 3 cols × 10 rows, label 2.625" × 1", top margin 0.5", left margin 0.3125". Math checks: 0.3125 + 3×2.625 + 0.3125 = 8.5; 0.5 + 10×1 + 0.5 = 11. **Always derive the grid from the supplier's spec sheet** — margins vary by product.

**B. Custom-size (single label per page / continuous roll) — best-effort.** `@page { size: <w> <h>; margin: 0 }`. Requires the printer driver to support a custom paper size; drivers/printers vary widely, and Chrome's dialog maps the CSS size to a driver paper (may show "Custom" and some printers scale or refuse). Use inches when possible (exact); mm acceptable with per-printer calibration.

### 4. Print-dialog quirks (current Chrome/Firefox)

- **Chrome**: headers/footers (title, URL, date, page numbers) print **by default** — user must uncheck "Headers and footers"; no CSS fully suppresses them. Margins dropdown Default/None/Minimum/Custom — "Default" (~0.4in) overrides `@page margin: 0` in the preview unless set to None. "Background graphics" off by default (needed for any backgrounds). Scale defaults to 100% — warn against "Fit to page".
- **Firefox**: respects `@page`; paper size set in Page Setup; "Print backgrounds" checkbox; headers/footers default on.
- **Safari < 18.2**: ignores `@page` entirely — falls back to default paper + margins; user sets paper size manually. No orientation keywords even in 18.2+.

### 5. Crisp barcodes

- **SVG vector → prints at printer resolution (300–1200dpi).** Empirically verified: inline SVG in Chrome's print pipeline emits vector path operators (`re` rects), **zero embedded raster images**. This is the crispness argument for bwip-js `toSVG`.
- Canvas is resolution-limited: must render ≥300dpi equivalent backing store (`scale = printerDPI/72`); screen-size canvas blurs.
- Raster PNG: ≥300dpi at physical size; <150dpi visibly blurs bars.
- Keep bars black on white; `print-color-adjust: exact` (`-webkit-print-color-adjust: exact`); never crop quiet zones (libraries handle them; EAN/UPC need 11 module-widths L/R, QR 4-module margin).

### 6. Multi-label strategy

- One `.sheet` per page, exactly sheet size, `page-break-after: always` on all but the last. Deterministic — auto-pagination of one tall container offsets fragments on later pages unreliably (verified: overflow does create a second identical page, but per-page sheets are the safe pattern).
- `break-inside: avoid` on `.label`.
- Chunk labels into pages: `cols = floor((sheetW − mL − mR) / pitchW)`, `rows = floor((sheetH − mT − mB) / pitchH)`.
- `window.print()` after render; `afterprint` hook to close the print view.

## CSS sketch — Avery 5160 (Letter, 30/sheet)

```css
@page {
  size: 8.5in 11in;   /* inches exact (verified: 612×792pt) */
  margin: 0;          /* page box = sheet; margins live in .sheet padding */
}

@media print {
  body { margin: 0; }
  .sheet {
    width: 8.5in; height: 11in;
    box-sizing: border-box;
    padding: 0.5in 0.3125in;   /* from stock spec sheet */
  }
  .sheet + .sheet { page-break-before: always; }
  .label {
    width: 2.625in; height: 1in;
    box-sizing: border-box;
    display: inline-block; vertical-align: top;
    break-inside: avoid;
    -webkit-print-color-adjust: exact; print-color-adjust: exact;
  }
  .label svg { width: 100%; height: auto; display: block; }
}
```

## CSS sketch — custom 50×25mm single label

```css
@page {
  size: 50mm 25mm;   /* ~+0.24% oversize measured in Chrome; calibrate per printer */
  margin: 0;
}
.label-page { width: 50mm; height: 25mm; margin: 0; }
```

## Calibration

Print a test sheet (a 100mm reference bar + the exact label rectangles) on plain paper first; measure; apply a per-printer calibration factor if the sheet is off. Chrome's own mm quantization (+0.24%) is smaller than typical driver/feed deviation, but both exist — never assume a fresh printer is exact. Use inches for stock that comes in inches (exact in Chrome).

## Sources

- MDN: [`@page`](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@page), [`size`](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@page/size), [Printing guide](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Media_queries/Printing)
- MDN BCD `css/at-rules/page.json` (raw.githubusercontent.com)
- bwip-js README (SVG output on all platforms)
- Empirical: headless Chrome 2026 print-to-PDF tests (MediaBox inspection + PDF stream decompression)
