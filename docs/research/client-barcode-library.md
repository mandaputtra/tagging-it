# Research: Client-side barcode/QR library for the v1 standard set

Resolves [mandaputtra/tagging-it#2](https://github.com/mandaputtra/tagging-it/issues/2) · 2026-08-22

**Question:** Which client-side JavaScript library generates the v1 standard set in-browser — QR, Code 128, Code 39, EAN-13, EAN-8, UPC-A, PDF417, DataMatrix, Aztec?

**Recommendation: [`bwip-js`](https://github.com/metafloor/bwip-js) (v4.11.4, MIT). Runner-up: [`zxing-wasm`](https://github.com/Sec-ant/zxing-wasm) (v3.1.3, MIT).** For 1D-only workloads, `jsbarcode` is the lightweight alternative but cannot cover the 2D half of the set.

All claims below verified against primary sources (npm registry, GitHub, package tarballs, project READMEs) on 2026-08-22.

## Comparison

| | **bwip-js** 4.11.4 | **zxing-wasm** 3.1.3 | **jsbarcode** 3.12.3 | **qrcode** 1.5.4 |
|---|---|---|---|---|
| QR | ✅ | ✅ | ❌ | ✅ |
| Code 128 | ✅ | ✅ | ✅ | ❌ |
| Code 39 | ✅ | ✅ | ✅ | ❌ |
| EAN-13 | ✅ | ✅ | ✅ | ❌ |
| EAN-8 | ✅ | ✅ | ✅ | ❌ |
| UPC-A | ✅ | ✅ | ✅ | ❌ |
| PDF417 | ✅ | ✅ | ❌ | ❌ |
| DataMatrix | ✅ | ✅ | ❌ | ❌ |
| Aztec | ✅ | ✅ | ❌ | ❌ |
| **Coverage of v1 set** | **9/9** | **9/9** | 5/9 (1D only) | 1/9 (QR only) |
| Output formats | canvas, SVG, PNG (via canvas `toDataURL`), raw drawing context; 100+ symbologies (BWIPP) | SVG string, PNG `Blob`, raw `ImageData`; read **and** write | canvas, SVG, PNG (via canvas) | canvas, data URL, SVG (`toString`), terminal |
| Runtime | Pure JS, **synchronous**, zero deps | **WASM (Emscripten)**, async init + fetch of `.wasm` file | Pure JS, synchronous, zero deps | Pure JS, 3 small deps (`pngjs`, `yargs`, `dijkstrajs`) |
| Browser support | All modern browsers, no special serving requirements | All modern browsers, but must serve ~648 KB `zxing_writer.wasm` (345 KB gzip) | All modern browsers | All modern browsers |
| Bundle (gzip) | ~277 KB full browser bundle; **tree-shakable ESM** with per-encoder named exports | ~355 KB writer-only (345 KB wasm + 9 KB js, both gzip) | ~11 KB full bundle | ~9 KB |
| Maintenance | Very active: v4.11.4 published 2026-08-19; repo pushed 2026-08-19, 2.4k stars | Active: v3.1.3 published 2026-08-14; repo pushed 2026-08-14 | Low churn but alive: 3.12.3 published 2026-01-07; repo pushed 2026-06-23, 5.9k stars | Stable/complete: 1.5.4 published 2024-08-05, 8.2k stars; no new features expected |
| License | MIT | MIT | MIT | MIT |
| Types | TS types shipped (`dist/bwip-js.d.ts`) | First-class TS types | Community `@types/jsbarcode` | `@types/qrcode` |

Sources: npm registry metadata (`registry.npmjs.org`), GitHub API + READMEs (`metafloor/bwip-js`, `Sec-ant/zxing-wasm`, `lindell/JsBarcode`, `soldair/node-qrcode`), tarball inspection (`bwip-js`, `zxing-wasm` dist files), bundlephobia (`jsbarcode`, `qrcode`).

## Other options considered (rejected)

- **Native `BarcodeDetector` API** — Chromium-only, and it *decodes*, it does not generate. Not usable for this app.
- **`@zxing/library`** — TypeScript port focused on **reading**; no writers for this set.
- **Single-symbology libs** (`pdf417.js`, `datamatrix.js`, various aztec encoders) — each covers 1 of the 3 hard 2D formats and several are stale; would need 3–4 libraries, inconsistent APIs and styling, more maintenance.
- **`node-qrcode` (the `qrcode` pkg)** — excellent QR-only lib, useful only if the set were QR-only.

## Why bwip-js

1. **Only credible library covering 9/9 with one API.** It embeds the BWIPP encoder suite (100+ symbologies, including GS1 variants, HIBC, Micro variants as future headroom — e.g. `gs1qrcode`, `gs1datamatrix` are free upgrades).
2. **Print-friendly by design.** Options are in physical units (`height` in mm, `scale` as pixels/mm), `includetext` renders human-readable text inside the symbol (critical for EAN-13/UPC-A retail labels), quiet zones are handled correctly per symbology — all of which matters for a print-dialog v1.
3. **Synchronous, zero-dependency pure JS** — no WASM to serve, no async init, trivially fast for bulk: 100s of codes is a single synchronous loop; BWIPP encoders run in well under a millisecond per symbol for typical inputs.
4. **Tree-shaking.** Import only the 9 encoders (`import { qrcode, code128, ... } from 'bwip-js'`) and the full 277 KB bundle shrinks to roughly the encoders actually used; SVG output needs the named `drawingSVG` import.
5. **Maintained and typed.** Active releases through Aug 2026, TS types shipped.

### API shape

```js
// QR — canvas
import bwipjs from 'bwip-js'; // or tree-shaken: import { qrcode } from 'bwip-js';

const canvas = bwipjs.toCanvas('qr-canvas', {
  bcid: 'qrcode',
  text: 'https://example.com/label/42',
  scale: 4,                    // pixels per module (print: match printer DPI)
  includetext: false,
});
// canvas auto-resizes to the symbol; PNG via canvas.toDataURL('image/png')

// 1D — Code 128, canvas (same call shape for code39, ean13, ean8, upca,
// pdf417, datamatrix, azteccode — only `bcid` + options change)
bwipjs.toCanvas('barcode-canvas', {
  bcid: 'code128',             // 'ean13' | 'ean8' | 'upca' | 'code39' | 'pdf417' | 'datamatrix' | 'azteccode'
  text: '0123456789',
  height: 12,                  // bar height in mm — print-friendly
  scale: 3,
  includetext: true,           // human-readable text under the bars
  textxalign: 'center',
});

// SVG variant (all platforms, synchronous)
const svg = bwipjs.toSVG({ bcid: 'qrcode', text: 'hi', scale: 4 });
```

Notes: checksums for EAN-13/EAN-8/UPC-A are computed automatically. `toCanvas()` accepts a canvas id string or a canvas element. Errors throw synchronously — wrap in try/catch.

### Known gaps / caveats

- **None in the 9-format set** — all nine are first-class BWIPP encoders.
- Full `toSVG()` links every encoder and disables tree-shaking; use named encoder imports + `drawingSVG` if bundle size matters.
- No native "barcode as PNG data URL" helper; it's `canvas.toDataURL('image/png')` (one line).
- Print scaling is manual: pick `scale` so modules land on printer pixels (e.g. 4 px/module @ 96dpi ≈ 0.94 mm/module; for crisp 1D bars at 203dpi use a scale ≈ 8.5). No PDF export — browser print dialog handles output, as already decided for v1.

## Runner-up: zxing-wasm

- Only other library covering **9/9 with write support** (verified in its README format table: Read+Write for `Code39`, `Code128`, `EAN13`, `EAN8`, `UPCA`, `PDF417`, `Aztec`, `QRCode`, `DataMatrix`).
- Outputs SVG string, PNG `Blob`, or raw `ImageData` from `writeBarcode()` — no canvas needed; useful for `<img>` printing.
- Costs vs bwip-js: async `Promise` per code (awkward for a synchronous bulk loop, though `Promise.all` over hundreds is fine), must serve a 648 KB `.wasm` file (345 KB gzip) and call async init, fewer styling options (no mm-based bar height / HRI positioning equivalent beyond `addHRT`).

```js
import { writeBarcode } from 'zxing-wasm/writer';

const { svg, image, symbol } = await writeBarcode('0123456789', {
  format: 'Code128',        // 'QRCode' | 'EAN13' | 'EAN8' | 'UPCA' | 'Code39' | 'PDF417' | 'DataMatrix' | 'Aztec'
  scale: 3,
  addHRT: true,
});
```

## Lightweight mention: jsbarcode

Best-in-class for the 5 linear formats (11 KB gzip, `JsBarcode("#el", "text", { format: "EAN13" })`, canvas/SVG/PNG) — but it has **no 2D support at all** (QR, PDF417, DataMatrix, Aztec), so it cannot satisfy the v1 set alone. A 4-lib composite would be needed; not worth it.

## Decision

Use **bwip-js** for v1: one dependency, one API, 9/9 coverage, print-oriented options, synchronous bulk generation, no WASM serving, active maintenance, MIT. Keep **zxing-wasm** in mind as the fallback if a future need for decoding or WASM-based encoding arises.
