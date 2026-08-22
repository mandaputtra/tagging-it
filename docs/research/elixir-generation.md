# Research: Elixir-side generation path for premium sync

**Issue:** #3 — "Research: Elixir-side generation path for premium sync"
**Date:** 2026-08-22
**Scope:** Server-generated barcode/QR images for synced (premium) codes, against the v1 symbology set: QR, Code 128, Code 39, EAN-13, EAN-8, UPC-A, PDF417, DataMatrix, Aztec.

## Bottom line

- **Store structured data in the sync payload (symbology + text + render options), not image bytes.** Images are derived state: the client already renders barcodes for the print flow, and any server-side renderer can produce them on demand from the structured record. Storing bytes duplicates data, bloats the DB, needs invalidation on every edit, and couples storage to one renderer.
- **Server-side generation should not be built for v1** unless a server-rendered surface exists (email/PDF export, API image endpoints, server-side thumbnails). The free tier and the browser print flow are 100% client-side.
- **If/when server-side generation is needed, the pragmatic path is a `bwip-js` (Node) sidecar service**, not pure Elixir: it is the only option covering the full v1 set with actively maintained, spec-compliant output (PNG + SVG). Pure-Elixir coverage is fragmented across 5+ single-symbology libraries with gaps (no EAN-8 or UPC-A renderer) and mixed maintenance.

## Library coverage (verified on hex.pm / hexdocs / GitHub, 2026-08-22)

> Note: `barcodes` (named in the issue) does **not** exist on hex.pm. The nearest real packages are `barlix`, `bark`, and `barcoder`.

### Pure-Elixir image renderers

| Symbology | Library | Latest / date | Output | Maintenance |
|---|---|---|---|---|
| QR | [`qr_code`](https://hex.pm/packages/qr_code) (iodevs, ex-sunboshan) | 3.2.0 / 2025-02 | SVG + PNG (+ base64) | Active; 1.2M downloads; BSD-4 |
| Code 128 | [`barlix`](https://hex.pm/packages/barlix) (ananthakumaran) | 0.6.4 / 2025-06 | PNG, SVG, UTF | Active; MIT |
| Code 128 (alt) | [`bark`](https://hex.pm/packages/bark) | 0.1.1 / 2019-11 | SVG, text | Stale/unmaintained |
| Code 128 (alt) | [`ex_barcode`](https://hex.pm/packages/ex_barcode) | 0.1.0 / 2026-05 | bar patterns (renderer-agnostic) | New; ExPDF umbrella |
| Code 39 | `barlix` (same) | — | PNG, SVG, UTF | Active |
| Code 39 (alt) | [`barcoder`](https://hex.pm/packages/barcoder) | 0.1.0 / 2025-06 | Code 39 only | New, single-symbology |
| EAN-13 | `barlix` (EAN13 encoder) | — | PNG, SVG, UTF | Active |
| EAN-8 | — | — | — | **No pure-Elixir renderer found** |
| UPC-A | — | — | — | **No pure-Elixir renderer found** (barlix has UPC-E only; workaround: encode as EAN-13 with leading `0`, identical encodation, but HRI text needs care) |
| PDF417 | [`pdf417`](https://hex.pm/packages/pdf417) (jackpocket) | 0.4.0 / 2025-11 | PNG | Active-ish; text + large-number modes only (no binary mode) |
| DataMatrix | [`datamatrix`](https://hex.pm/packages/datamatrix) (0x8b) | 0.1.3 / 2020-02 | DataMatrix ECC200 | **Stale** (last release 2020) |
| Aztec | [`aztec_ex`](https://hex.pm/packages/aztec_ex) | 0.1.1 / 2026-02 | SVG, text | New, active; encodes + decodes (ISO/IEC 24778) |

Not renderers (data-level only, excluded): `gs1_barcode` (GS1 code detection/validation/GTIN generation, no images), `barcode_generator` (GTIN number sequences + check digits, no images).

**Takeaway:** covering the full v1 set in pure Elixir means stitching together 5+ libraries (`qr_code` + `barlix` + `pdf417` + `datamatrix` + `aztec_ex`) with **hard gaps at EAN-8 and UPC-A**, a stale DataMatrix option, and PDF417 limited to text/numeric payloads. That is a lot of moving parts for a core feature.

### Full-coverage options (not pure Elixir)

| Option | v1 coverage | Output | Runtime cost | Maintenance |
|---|---|---|---|---|
| [`bwip-js`](https://github.com/metafloor/bwip-js) (Node) | 100+ symbologies, incl. all 9 v1 | PNG (node), SVG (all platforms) | Node runtime; run as a small persistent sidecar HTTP service | **Very active**: v4.11.4 released 2026-08-19; BWIPP lineage (spec-compliant) |
| ZXing (Java) | all 9 v1 | PNG/SVG via Java2D | JVM + interop (erlport / ElixirJavaPorts) | Mature but heavier ops footprint |

## Recommendation

### 1. Sync payload: store structured data, regenerate on demand

Store `{symbology, text, options}` (options: scale/module size, colors, label/HRI settings), **not** image bytes and **not** pre-rendered SVG strings.

Reasoning:

- **Single source of truth.** Editing a label must update the barcode everywhere; with stored images you need re-upload + cache invalidation on every edit. With structured data the edit is one row update and every surface re-renders.
- **No duplication / no blob store.** A print-scale PNG is ~1–50 KB per code depending on symbology; storing bytes means DB blobs (or a file/object store) for data the client can already produce. Structured data is a few hundred bytes of JSON.
- **Client needs it anyway.** The print flow (browser print dialog, per v1 decision) renders client-side from exactly this data. Shipping the data back to the client is required regardless of any server-side renderer.
- **Renderer-agnostic.** Structured data survives renderer/library changes on either side; stored SVG strings or PNGs freeze in one renderer's output and font/version quirks.
- If a server-rendered surface becomes hot later, add a cache keyed by a hash of the structured record (e.g. `:erlang.phash2` or SHA-256 of the JSON) — a cheap optimization, not a storage design change.

### 2. Server-side generation: defer; if needed, use a bwip-js sidecar

- **v1:** don't build server-side rendering. All v1 surfaces (web UI, browser print) are client-side; the free tier already proves client-side generation works (see `client-barcode-library.md`).
- **When a server-rendered surface appears** (email attachments, PDF export, public API image endpoints, server-rendered thumbnails), run `bwip-js` as a small Node HTTP sidecar (persistent process, one endpoint: `{bcid, text, options} → PNG/SVG`). One dependency covers the entire v1 set with spec-compliant, actively maintained output — strictly better than five pure-Elixir libs with gaps.
- **Only if Node is unacceptable** on the deployment: assemble `qr_code` + `barlix` + `pdf417` + `datamatrix` + `aztec_ex`, and accept the EAN-8/UPC-A gap (UPC-A via EAN-13 leading-zero workaround; EAN-8 would need a new encoder) and the stale DataMatrix option.
- **Avoid ZXing/JVM** unless both Node and pure-Elixir are ruled out; the JVM is a heavier dependency than the problem warrants.

## Open questions for the implementation ticket

- Do any v1 premium features need server-rendered images (email/PDF/API)? If no, server-side generation is a non-requirement for v1 and only the payload shape matters.
- Print-quality rendering at high DPI is a client-side concern today; if server rendering is added later, pin module-size (scale) options per symbology so server and client outputs match.
