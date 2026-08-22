# Research: Browser storage for the unlimited free tier

**Issue:** #4 — "Which browser storage API should hold free-tier user data?"
**Date:** 2026-08-22
**Status:** Recommendation ready for implementation.

## TL;DR

Use **IndexedDB** as the free-tier data store. It is the only credible option that is
"effectively unlimited" (quota is a large fraction of disk, not a small fixed cap), natively
stores structured objects, indexes them for query, and handles bulk writes of hundreds of
records in one fast async transaction. LocalStorage dies at ~5–10 MiB (fails the "unlimited"
requirement outright). OPFS shares IndexedDB's quota but is a file-system API with no query
layer — you would hand-roll serialization and an index. Cache API is for HTTP request/response
pairs (offline assets), not app data.

There is no literal "unlimited" browser storage: every browser enforces a per-origin quota and
can evict data under storage pressure. But with IndexedDB the quota is ~60% of the user's disk
in Chrome/Edge/Safari (up to ~10 GiB best-effort in Firefox), which for this product means
hundreds of thousands of generated-code records — effectively unlimited for the free tier.

## Candidate comparison

| Criterion | **IndexedDB** ✅ | localStorage | OPFS | Cache API |
|---|---|---|---|---|
| Quota / capacity | Large: ~60% of disk per origin (Chrome/Edge, Safari on macOS 14+/iOS 17+); Firefox 10% of disk capped at 10 GiB (best-effort) or 50% capped at 8 TiB (persistent). No prompt in modern browsers. | Hard cap **5 MiB** (localStorage) + 5 MiB (sessionStorage), ≤10 MiB total, in all browsers. Throws `QuotaExceededError`. | Same quota pool as IndexedDB (shares origin quota; visible via `navigator.storage.estimate()`). | Same quota pool as IndexedDB (Cache API + IDB share the origin's storage management). |
| Data model | Structured objects via the structured-clone algorithm: strings, numbers, arrays, objects, Dates, Blobs. | Strings only (must JSON-serialize everything). | Byte-oriented files — you serialize/parse yourself. | HTTP `Request`/`Response` pairs. |
| Bulk write (100s of records) | One `readwrite` transaction with hundreds of `put()`s — async, sub-second, doesn't block main thread. | Sync (blocks main thread); every write rewrites a string; quota dies in a few hundred records. | Fast, especially `createSyncAccessHandle()` in workers, but you manage file layout. | Not designed for record CRUD. |
| Query / delete | Indexes + `IDBKeyRange` (e.g. "all codes in batch X", "codes created in last month"), cursor iteration, `store.clear()`. | Manual full-scan + parse of the string; no ranges. | No query layer — read/parse files or maintain your own index. | Match by Request URL only. |
| API complexity | Verbose, event-based; use a thin promise wrapper (`idb`, ~1.5 kB) or Dexie for richer query ergonomics. | Trivial — but too small to matter. | Moderate; file-handle lifecycle, sync handles only in workers. | Simple, but wrong tool. |
| Browser support | Universal in all modern browsers; works in workers + service workers. | Universal, but irrelevant. | Chrome/Edge 86+, Firefox 111+, Safari 15.2+; secure contexts only. | Universal. |

## The quota landscape (primary sources)

Numbers below are per origin, unless noted. Best-effort storage is the default; `navigator.storage.persist()` can opt an origin into persistent storage that is only removed when the user clears it.

- **Chrome / Edge (Chromium):** an origin may use up to **60% of total disk** (best-effort *and* persistent; the browser itself caps at 80% of disk). Incognito: ~5% of disk; "clear on exit" mode: ~300 MB. ([MDN: Storage quotas and eviction criteria](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [web.dev: Storage for the web](https://web.dev/articles/storage-for-the-web))
- **Firefox:** best-effort = smaller of **10% of disk** or **10 GiB** group (eTLD+1) limit; persistent = **50% of disk, capped at 8 TiB**, exempt from the group limit. ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria))
- **Safari / WebKit (macOS 14+, iOS 17+):** ~**60% of total disk** per origin for browser apps (and installed PWAs); ~15% for embedded WebViews; an overall 80%/20% disk ceiling across all origins. Older Safari: 1 GiB initial quota with a user prompt to grow it. ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [WebKit: Updates to storage policy](https://webkit.org/blog/14403/updates-to-storage-policy/))
- **Eviction reality:** best-effort data is evicted LRU-first under storage pressure; Safari (ITP) proactively deletes script-written storage for origins the user hasn't interacted with in 7 days — **does not apply to installed PWAs**. Chrome-team research shows eviction is rare for sites users visit regularly. ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria), [web.dev: Persistent storage](https://web.dev/articles/persistent-storage))
- **Checking the budget:** `navigator.storage.estimate()` returns `{ usage, quota }` covering IndexedDB + Cache + OPFS; `navigator.storage.persist()` requests eviction protection (auto-approved in Chrome/Safari for engaged users; Firefox shows a prompt). ([MDN: StorageManager](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager))
- **localStorage** is capped at ~5 MiB in every browser — a hard ceiling, not a soft one. ([MDN: Storage quotas](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria))

## Recommendation

**IndexedDB, wrapped with `idb` (or raw IndexedDB if we want zero deps).** Reasons:

1. The requirement "unlimited for free users" is only satisfiable by the quota pool that IndexedDB/OPFS/Cache share — localStorage's 5 MiB cap is disqualifying on its own.
2. Data is naturally structured (code record = symbology + data + label fields + timestamps) — IndexedDB stores objects as-is and lets us index `batchId` and `createdAt` for the list/group views and batch deletion.
3. Bulk generation (100s of records per batch) is one async transaction; no main-thread jank, no string serialization.
4. Export/import is clean because records are pure JSON-able data (see below).
5. Same store will serve the premium tier later — sync becomes a layer on top, not a migration.

**OPFS is the fallback/adjunct**, not the primary: keep it in mind only if we later store large binary artifacts (e.g. cached rendered PNGs of labels). It shares IndexedDB's quota, so it's complementary, not an alternative. Cache API is explicitly the wrong tool (HTTP pairs). SQLite/WASM on OPFS is a credible heavyweight alternative but overkill for a record store of this shape (no joins, no complex SQL).

## Schema sketch

Database `tagging-it`, version 1. Client-generated UUIDs as keys (never server-issued) so records are stable across export/import and future sync. All records are plain JSON-able data — no Blobs — which is what makes JSON export trivial.

**Object store `codes`** (keyPath `id`; indexes: `byBatch` on `batchId`, `byCreated` on `createdAt`, `byUpdated` on `updatedAt`):

```js
{
  id: "018f2d…",            // client UUID — stable PK for export/import + sync
  batchId: "018f2e…" | null, // null = standalone single code
  symbology: "qrcode" | "code128" | "code39" | "ean13" | "ean8" | "upca"
            | "pdf417" | "datamatrix" | "aztec",
  data: "SKU-12345",        // the encoded value
  label: {
    text: "Widget — Size M",   // user-customizable label fields
    fontSize: 12,
    position: "below" | "above"
  },
  count: 1,                 // copies to print per code
  createdAt: "2026-08-22T10:00:00Z",  // ISO 8601
  updatedAt: "2026-08-22T10:00:00Z",
  syncedAt: null,           // premium sync marker (see below)
  dirty: true               // true until synced, for incremental sync
}
```

**Object store `batches`** (keyPath `id`; index `byCreated`):

```js
{
  id: "018f2e…",            // client UUID; referenced by codes.batchId
  name: "August inventory",
  createdAt: "2026-08-22T10:00:00Z",
  updatedAt: "2026-08-22T10:00:00Z",
  recordCount: 250          // denormalized for list views
}
```

**Object store `meta`** (keyPath `key`): `{ key: "schemaVersion", value: 1 }`, plus export metadata if needed.

Bulk insert: one `readwrite` transaction over `codes`, `put()` each record, commit — atomic for the whole batch. Batch delete: `IDBKeyRange` on `byBatch` + cursor delete in one transaction.

## Export / import (JSON backup & restore)

- **Export:** one readonly transaction across `batches` + `codes`; iterate with cursors; assemble `{ app: "tagging-it", formatVersion: 1, exportedAt, batches: [...], codes: [...] }`; download via `Blob` + object URL. No Blobs are stored, so everything serializes to JSON directly — barcodes are deterministically renderable from `symbology` + `data`, so rendered images are never persisted and nothing is lost in a text-only backup.
- **Import:** parse + validate (`formatVersion`, required fields, symbology whitelist), then one `readwrite` transaction per store using `put()` (upsert semantics — client UUIDs make restores idempotent; a re-import overwrites, never duplicates).
- **Quota failure UX:** wrap writes in `try/catch`/`onabort` and surface `QuotaExceededError` with a "export your data" escape hatch — export is also the answer to "unlimited": the hard reality is a large quota, not infinity, and the UI should never let users silently lose data to eviction.

## Free-tier data model, with later sync in mind

Design the schema now so premium sync is additive:

1. **Client-generated UUIDs** as PKs — the server can adopt them as-is or map them; no re-keying at upgrade time.
2. **`updatedAt` + `dirty` flag** on every record → incremental sync = push `dirty` records since `syncedAt`, flip on ack. No schema migration required later.
3. **Free tier = same store, no sync layer.** Premium enables a sync module that reads/writes the same object stores; the free tier simply never runs it. `batchId` keeps codes addressable in groups for both local and server round-trips.
4. Add `navigator.storage.persist()` at first write to reduce eviction risk for free-tier data (it is the only thing between "free users" and silent data loss).

## Sources

- [MDN: Storage quotas and eviction criteria](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria)
- [MDN: IndexedDB API](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
- [MDN: StorageManager (estimate/persist)](https://developer.mozilla.org/en-US/docs/Web/API/StorageManager)
- [MDN: Origin Private File System](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API/Origin_private_file_system)
- [web.dev: Storage for the web](https://web.dev/articles/storage-for-the-web)
- [web.dev: Persistent storage](https://web.dev/articles/persistent-storage)
- [WebKit blog: Updates to storage policy](https://webkit.org/blog/14403/updates-to-storage-policy/)
