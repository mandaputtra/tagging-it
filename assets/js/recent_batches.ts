// Recent-batches section of the landing page: reads batches from IndexedDB
// (client-side store), maps them to a compact wire payload, and pushes it to
// LandingLive for server-side rendering. Free tier: data never leaves the
// browser.
import type { Hook } from "phoenix_live_view";
import { listBatches } from "./batch_store.js";
import type { BatchRecord, RecentBatchWire } from "./types.js";

const MAX_RECENT = 6;

/** Maps stored batches to the payload LandingLive renders. Pure, testable. */
export function recentBatchesPayload(batches: BatchRecord[]): RecentBatchWire[] {
  return [...batches]
    .sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)))
    .slice(0, MAX_RECENT)
    .map((b) => ({
      id: b.id,
      name: b.name,
      symbology: b.template?.symbology ?? "",
      created_at: b.created_at,
      updated_at: b.updated_at,
      code_count: (b.code_ids ?? []).length,
    }));
}

/** LiveView hook: on mount, load recent batches from IndexedDB and push them. */
export const RecentBatches: Hook = {
  mounted() {
    listBatches()
      .then((batches) => {
        this.pushEvent("recent:loaded", { batches: recentBatchesPayload(batches) });
      })
      .catch((err) => {
        console.error("RecentBatches: failed to load batches from store", err);
      });
  },
};
