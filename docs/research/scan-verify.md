# Research: scan-to-verify implementation path (camera, decode, lookup)

Resolves [mandaputtra/tagging-it#19](https://github.com/mandaputtra/tagging-it/issues/19) · 2026-08-30

**Question:** How should **Scan Label (IMofJ)** → **Verified Code (tZkkH)** work entirely client-side (free tier is browser-only, `IndexedDB` via `idb`)?

## TL;DR

**Manual input is the v1 path; camera is progressive enhancement behind a text fallback.** Decode via **`zxing-wasm`** (`readBarcode`) as the single decode dep (covers the 9-format v1 set, same runner-up as #2, ~600 KB WASM, MIT) with **`BarcodeDetector`** as a fast-path where available (Chromium secure context). Lookup is a bare `code_data`/`sequence` string with no `batch_id` — add **secondary indexes** `code_data` + `sequence` on the `codes` store (DB v2 migration) and query both; fall back to full scan for existing v1 stores. Miss → **modal popup**, not full-page 404, per user story (“pop up errors”).

## Capture: camera vs input

| | **Manual text input** (v1 default) | **Camera + decode** (enhancement) |
|---|---|---|
| UX | Type/scan with external USB scanner that keystrokes the value (common for Code 128 on laptop) or paste the printed string. Works on every laptop, no permission, no HTTPS. | `getUserMedia` → `<video>` → decode loop. Needs HTTPS (except `localhost`), user permission, and a usable laptop camera angle (awkward for flat labels — mobile is easier). |
| Reliability | 100% — no camera, no decode fragility. | Fragile on laptop: glare, focus, low light. Good as an optional path, not the only path. |
| Recommendation | **Ship input + “Scan with camera” button that *enhances* the same pivot.** Input is always visible; camera is a progressive enhancement, not a gate. This matches herdr laptop reality and the pen.dev `IMofJ` frame (large viewport + fallback). |

**Decision:** Scan view has a single pivot input (`code_data` string, `autofocus`, `enter→verify`) plus a “Use camera” affordance that opens the viewport only on demand. The verifier does not care how the string arrived.

## Decode: what turns a camera frame into a string

`bwip-js` is **encode-only** — it cannot decode. The decode side must be a separate lib. Candidates that cover the v1 set (9/9: QR, Code 128, Code 39, EAN-13, EAN-8, UPC-A, PDF417, DataMatrix, Aztec):

| | **zxing-wasm** 3.1.3 | **html5-qrcode** 2.3.8 | **Native `BarcodeDetector`** |
|---|---|---|---|
| Coverage | 9/9 decode (same as encode) — verified in README format table | 9/9 via `zxing` under the hood, but QR-focused docs; EAN/2D decode works but less explicit | 9/9 per spec, but impl varies; Chrome/Edge ship most, Safari 17+ ships only QR/EAN/Code128 subset |
| Runtime | WASM (Emscripten), async `readBarcode(ImageData)`; ~648 KB `zxing_reader.wasm` (345 KB gzip), one-time fetch + init | JS + WASM, heavier bundle (~150 KB + dynamic), built-in UI widget (viewport + overlay) | Native, zero bundle, synchronous where available |
| Browser | All modern (needs `fetch` for `.wasm`), no permission | All modern | **Chromium-only** for full set; Safari limited; Firefox behind flag. **SecureContext required** everywhere. Not usable alone. |
| Bundle cost | Shared cost with #2 runner-up — if decode ships, this is the same dep family as the writer fallback; keep one zxing version | Extra dep beyond zxing-wasm; couples UI and decode | Zero |
| API shape | `import { readBarcode } from 'zxing-wasm/reader'; const { text, format } = await readBarcode(imageData)` | `new Html5Qrcode("el").start({facingMode:"environment"}, {fps:10, qrbox:250}, onScan)` | `new BarcodeDetector({formats:['qr_code','code_128',...]}); const barcodes = await detector.detect(video)` |

**Recommendation:** **`zxing-wasm` reader** as the single decode dep. Reasons:

1. Only other 9/9 lib besides `bwip-js` (already the #2 runner-up) — one mental model for both directions; no 3–4-lib composite.
2. `BarcodeDetector` is a **fast-path**, not a baseline: where it exists, try it first (zero cost, no fetch), fall back to `zxing-wasm`. Feature-detect:

```ts
const hasDetector = 'BarcodeDetector' in window
  && (await BarcodeDetector.getSupportedFormats?.() ?? []).includes('qr_code');
```

3. `html5-qrcode` is not needed — its viewport/overlay is 20 lines of `<video>` + CSS; coupling UI to decode is unnecessary weight when we already own the sticker shell.

**Serving note:** `zxing_reader.wasm` must be served from the same origin (`priv/static/assets/` or CDN) with `application/wasm` and fetched once; `esbuild` needs `loader: {'.wasm':'file'}` or a `fetch('/assets/zxing_reader.wasm')` path — verify in assets build (similar to #2 writer WASM note).

## Lookup: bare string → Code (+ Batch) in IndexedDB

Current `TaggingItSchema` (`batch_store.ts` v1): `codes` store keyed by `id`, single index `batchId → batch_id`. No index on the scanned value.

A scan arrives as a bare `code_data` string (or `sequence` — per #14 `code_data` defaults to `sequence` but may diverge). No `batch_id` travels with the scan. Resolution must be **global**.

### Options

1. **Full scan** (`listCodes` → `filter`): `await db.getAll('codes')` then `find(c => c.code_data === input || c.sequence === input)`. OK for hundreds, but O(N) for 10k+ and blocks the main thread on large stores.
2. **Secondary indexes** (`code_data`, `sequence`): `codes.createIndex('code_data','code_data')` + `codes.createIndex('sequence','sequence')`; query via `getAllFromIndex`. O(log N), dedupes ambiguous hits (two codes sharing a `code_data` — possible if user pasted duplicates).

**Recommendation:** **DB v2 adds both indexes with migration**, lookup queries both:

```ts
// batch_store.ts v2
upgrade(db, oldVersion) {
  // v1 stores already exist
  if (oldVersion < 2) {
    const codes = db.transaction.objectStore('codes');
    if (!codes.indexNames.contains('code_data')) codes.createIndex('code_data', 'code_data');
    if (!codes.indexNames.contains('sequence')) codes.createIndex('sequence', 'sequence');
  }
}
export async function codesByValue(input: string): Promise<CodeRecord[]> {
  const db = await open();
  const a = await db.getAllFromIndex('codes', 'code_data', input);
  if (a.length) return a;
  return db.getAllFromIndex('codes', 'sequence', input);
}
// Graceful fallback for v1 stores that haven't upgraded yet: if index missing, catch and full-scan.
```

- Handles ambiguous `code_data` (returns all hits — Verified view shows disambiguation list; single hit → direct verify).
- Existing v1 stores migrate on next `open()` — no data loss; new installs get indexes immediately.
- TDD: `fake-indexeddb` tests cover `codesByValue` with v1→v2 upgrade, hit/miss/ambiguous, unicode, empty store.

## Verdict UX: hit vs miss

- **Hit:** navigate to Verified (`tZkkH`) — `bwip-js.toSVG` render of the code, `Sequence` / `Value` / field map, breadcrumb to `Batch Detail (pfdS7)`, Print action same as Detail.
- **Miss:** **modal popup** (pen.dev `tZkkH` error variant, sticker modal: cream card, hard shadow, outline, Baloo 2 heading “Code not found”, body shows scanned string, actions **Try again** (close modal, refocus input) + **Go to batches**). Do **not** push a full-page 404 — user story is “if its not then pop up errors” and stays on Scan to retry. The popup is dismissible by overlay/Esc.

This matches the prototype plan in #21 (Scan A/B/C + Verified + popup) and the task slice in #22 (lookup + verified route).

## What this unblocks

- #21 (Prototype) can now build variants with the input+camera pivot and popup miss, knowing the lookup key is `code_data`/`sequence` and decode is `zxing-wasm` (+ `BarcodeDetector` fast-path).
- #22 (Task) can implement `codesByValue`, the scan hook, and the verified route with TDD (hit/miss/ambiguous, popup focus trap).

## Sources (2026-08-30)

- `docs/research/client-barcode-library.md` (bwip-js 9/9, zxing-wasm runner-up, native BarcodeDetector note)
- `docs/research/browser-storage.md` + `assets/js/batch_store.ts` v1 schema
- MDN: `BarcodeDetector` (Chromium secure-context, format support), `MediaDevices.getUserMedia` (permission/HTTPS), `IndexedDB` `createIndex`/`getAllFromIndex`
- npm: `zxing-wasm` 3.1.3 reader (`readBarcode(ImageData)`), `html5-qrcode` 2.3.8 (wrapper over zxing)
- pen.dev app state frames `IMofJ` (Scan Label), `tZkkH` (Verified Code), `pfdS7` (Batch Detail) — live in app state, not yet flushed to `/Users/mandaputra/Design/tagging-it.pen`
