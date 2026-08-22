// Client entry — LiveView socket + SheetView bridge.
// Built with esbuild: `npm run build` in assets/ → priv/static/assets/app.js.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { getBatch, codesByBatch } from "./batch_store";
import { persistAndGo, deleteBatchAndRefresh } from "./batch_creator";
import { buildSheetPayload, renderBarcodes } from "./sheet_bridge";
import { RecentBatches, recentBatchesPayload } from "./recent_batches";
import { toSVG } from "bwip-js/browser";

let Hooks = {};

Hooks.RecentBatches = RecentBatches;

// Landing recent-batch cards: delete from IndexedDB (cascade codes), then
// push the refreshed list back to the server for re-render.
Hooks.BatchDelete = {
  mounted() {
    this.el.addEventListener("click", async (ev) => {
      ev.preventDefault();
      const id = this.el.dataset.batchId;
      if (!id) return;
      if (!window.confirm("Delete this batch and its labels?")) return;
      try {
        const remaining = await deleteBatchAndRefresh(id);
        this.pushEvent("recent:loaded", { batches: recentBatchesPayload(remaining) });
      } catch (err) {
        console.error("BatchDelete: failed to delete batch", err);
      }
    });
  },
};

// Sheet toolbar: delete the batch and return to the landing page.
Hooks.SheetDelete = {
  mounted() {
    this.el.addEventListener("click", async (ev) => {
      ev.preventDefault();
      const id = this.el.dataset.batchId;
      if (!id) return;
      if (!window.confirm("Delete this batch and its labels?")) return;
      try {
        await deleteBatchAndRefresh(id);
        window.location.href = "/";
      } catch (err) {
        console.error("SheetDelete: failed to delete batch", err);
      }
    });
  },
};

// BatchForm: when the server pushes a created batch, persist it in IndexedDB
// and navigate to its sheet. Free tier stores everything client-side.
Hooks.BatchCreator = {
  mounted() {
    this.handleEvent("batch:created", async ({ batch, codes }) => {
      try {
        await persistAndGo(batch, codes);
      } catch (err) {
        console.error("BatchCreator: failed to persist batch", err);
      }
    });
  },
};

// SheetView: free tier is browser-only. On mount, read the batch + codes from
// IndexedDB and push them to SheetLive; after each morph, draw the barcode SVGs.
Hooks.SheetLoader = {
  async mounted() {
    const batchId = this.el.dataset.batchId;
    if (!batchId) return;
    try {
      const [batch, codes] = await Promise.all([
        getBatch(batchId),
        codesByBatch(batchId),
      ]);
      if (!batch) return; // SheetLive shows its own empty/loading state
      this.pushEvent("sheet:loaded", buildSheetPayload(batch, codes));
    } catch (err) {
      console.error("SheetLoader: failed to load batch from store", err);
    }
  },
  updated() {
    // Runs after each server morph — barcode placeholders exist here.
    renderBarcodes(this.el, (opts) => toSVG(opts));
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});
liveSocket.connect();

window.liveSocket = liveSocket;
