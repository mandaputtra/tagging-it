// Client entry — LiveSocket + SheetView bridge.
// Built with esbuild: `npm run build` in assets/ → priv/static/assets/app.js.
import { Socket } from "phoenix";
import { LiveSocket, type Hook } from "phoenix_live_view";
import { getBatch, codesByBatch, getCode, codesByValue } from "./batch_store.js";
import { persistAndGo, deleteBatchAndRefresh } from "./batch_creator.js";
import { buildSheetPayload, renderBarcodes } from "./sheet_bridge.js";
import { buildBatchDetailPayload } from "./batch_detail.js";
import { RecentBatches, recentBatchesPayload } from "./recent_batches.js";
import { toSVG } from "bwip-js/browser";
import type { BatchCreatedWire } from "./types.js";

declare global {
  interface Window {
    liveSocket: LiveSocket;
  }
}

const Hooks: Record<string, Hook> = {};

Hooks.RecentBatches = RecentBatches;

// Landing recent-batch cards: delete from IndexedDB (cascade codes), then
// push the refreshed list back to the server for re-render.
Hooks.BatchDelete = {
  mounted() {
    this.el.addEventListener("click", async (ev: Event) => {
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
    this.el.addEventListener("click", async (ev: Event) => {
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
    this.handleEvent("batch:created", async ({ batch, codes }: BatchCreatedWire) => {
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

// BatchDetail: same store bridge but for the detail view (per #18/#20).
Hooks.BatchDetailLoader = {
  async mounted() {
    const batchId = this.el.dataset.batchId;
    if (!batchId) return;
    try {
      const [batch, codes] = await Promise.all([getBatch(batchId), codesByBatch(batchId)]);
      if (!batch) return;
      this.pushEvent("detail:loaded", buildBatchDetailPayload(batch, codes));
    } catch (err) {
      console.error("BatchDetailLoader: failed to load batch from store", err);
    }
  },
};
// Scan: Variant A — input pivot + camera placeholder. On Verify, lookup
// codesByValue (DB v2 indexes) and either navigate to /verified/:id or show
// the miss popup via pushEvent. Camera is a future enhancement per #19.
Hooks.ScanLoader = {
  mounted() {
    const input = this.el.querySelector("#scan-input") as HTMLInputElement | null;
    const btn = this.el.querySelector("#scan-verify") as HTMLElement | null;
    if (!input || !btn) return;
    const verify = async () => {
      const value = input.value.trim();
      if (!value) {
        this.pushEvent("scan:miss", { value: "" });
        return;
      }
      try {
        const hits = await codesByValue(value);
        if (hits.length === 0) {
          this.pushEvent("scan:miss", { value });
        } else {
          window.location.href = `/verified/${hits[0].id}`;
        }
      } catch (err) {
        console.error("ScanLoader: lookup failed", err);
        this.pushEvent("scan:miss", { value });
      }
    };
    btn.addEventListener("click", verify);
    input.addEventListener("keydown", (e: KeyboardEvent) => {
      if (e.key === "Enter") {
        e.preventDefault();
        verify();
      }
    });
  },
};

// Verified: hydrate code + batch from IndexedDB and push to VerifiedLive; render barcode.
Hooks.VerifiedLoader = {
  async mounted() {
    const codeId = this.el.dataset.codeId;
    if (!codeId) return;
    try {
      const code = await getCode(codeId);
      if (!code) return;
      const batch = await getBatch(code.batch_id);
      if (!batch) return;
      this.pushEvent("verified:loaded", { batch, code });
    } catch (err) {
      console.error("VerifiedLoader: failed to load", err);
    }
  },
  updated() {
    const el = this.el.querySelector(".barcode");
    if (!el || el.querySelector("svg")) return;
    const htmlEl = el as HTMLElement;
    const bcid = htmlEl.dataset.bcid || "code128";
    const text = htmlEl.dataset.text || "";
    try {
      el.innerHTML = toSVG({ bcid, text });
    } catch (err) {
      el.textContent = `barcode error: ${err instanceof Error ? err.message : String(err)}`;
    }
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
