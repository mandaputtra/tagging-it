# TaggingIt

Freemium QR/barcode label generator. Create codes one-by-one or in bulk, each with a user-customizable text label, then print via the browser print dialog to any laptop-connected printer.

- **Free tier** — 100% client-side: codes and batches live in IndexedDB in the browser, no server sync.
- **Premium tier** — server sync (planned; see [architecture](#architecture)).

## Stack

- **Phoenix 1.7** (Elixir, Bandit, LiveView) — server + LiveView UI. No Ecto, no asset build pipeline (`--no-ecto --no-assets`).
- **bwip-js** (client-side, MIT) — barcode/QR rendering for all 9 v1 symbologies: QR, Code 128, Code 39, EAN-13, EAN-8, UPC-A, PDF417, DataMatrix, Aztec. Rendered as SVG via `bwipjs.toSVG()` for crisp print.
- **IndexedDB** via the `idb` wrapper — free-tier storage: `batches`, `codes`, `meta` stores; client UUID primary keys; `updatedAt` + dirty flag for future delta sync.
- **Tailwind CSS v4** — theme tokens in `assets/css/app.css` (`@theme`); print CSS hand-rolled in the sheet view.

## Setup

```bash
mix setup        # deps + assets
mix phx.server   # http://localhost:4000
```

Assets build with `npm` (esbuild + Tailwind CLI) into `priv/static/assets`:

```bash
cd assets && npm run build    # typecheck (tsc --noEmit) + CSS + JS
cd assets && npm run css      # CSS only (dev loop)
cd assets && npm test         # vitest for the client JS modules
```

## Tests

```bash
mix test          # Elixir/LiveView tests (Phoenix testing best practices)
cd assets && npm test   # client TS: vitest + tsc --noEmit gate
```

TDD is the standing preference: write failing tests before implementation.

## Architecture

The server is a thin LiveView shell; the free tier's data never leaves the browser.

```
Browser "/"  → LandingLive (sticker home: hero + Recent Batches)
  → CTA → /batches/new → BatchFormLive (create batch, pick symbology)
  → /sheet/:batch_id → SheetLive (print sheet, live-editable fields)
Client hooks (assets/js):
  RecentBatches → batch_store (IndexedDB) → push "recent:loaded"
  BatchCreator → persist batch + codes in IndexedDB → navigate to sheet
  SheetLoader → read batch/codes → render bwip-js SVGs
```

- `lib/tagging_it/` — domain: `Batch`, `Code`, `Template`, `BatchSerializer` (structured payloads, not image bytes).
- `lib/tagging_it_web/live/` — LiveViews: `LandingLive`, `BatchFormLive`, `SheetLive`.
- `assets/js/` — TypeScript (strict) client: `batch_store.ts` (IndexedDB), `batch_creator.ts`, `sheet_bridge.ts`, `recent_batches.ts`, `types.ts` (compile-checked wire contracts).
- `lib/tagging_it_web/controllers/print_prototype*` — throwaway print-flow prototypes (`/prototype/print`, `/prototype/home`); delete before v1.

### Domain terms

Defined in `CONTEXT.md` — **Code**, **Batch**, **Field**, **Field map**, **Label**, **Code data**, **Sync**. Four fields per code: Code ID (UUID v7), Sequence, Value (encoded content), Metadata (field map). Everything is a batch — a single code is a batch of size 1.

## Design system

- **Home** — playful sticker identity (pen.dev design, `/Users/mandaputra/Design/tagging-it.pen`): cream `#FFF8EC`, ink `#2B2A3D`, hard shadows + thick outlines, Baloo 2 / Fredoka. Tokens: `sticker-*` in `assets/css/app.css`.
- **App UI** — Notion-style tokens from `docs/notion-DESIGN.md`: signature purple `#5645d4` for the primary CTA only, navy hero bands, 8px-rounded buttons, 4px spacing grid.

## Wayfinder map

This project is charted on GitHub issues. The map is **issue #1** (`wayfinder:map`); tickets are its child issues (`wayfinder:research|grilling|prototype|task` labels). Work one ticket per session; claim before starting.

## Research docs

`docs/research/` — one markdown per resolved research ticket: client barcode library, Elixir-side generation, browser storage, print layout, premium architecture. Source of the architecture decisions above.
