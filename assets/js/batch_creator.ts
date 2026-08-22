// Client-side batch creation handoff: receives the `batch:created` payload
// from BatchFormLive, persists batch + codes in IndexedDB, and navigates to
// the sheet. Free tier never sends this data to the server.
import { putBatch, putCodes, deleteBatch, listBatches } from "./batch_store.js";
import type { BatchRecord, CodeRecord } from "./types.js";

/**
 * Deletes a batch (cascade: codes too) from IndexedDB and returns the
 * remaining batches for the landing list re-render.
 */
export async function deleteBatchAndRefresh(batchId: string): Promise<BatchRecord[]> {
  if (!batchId) throw new Error("deleteBatchAndRefresh: missing batch id");

  await deleteBatch(batchId);
  return listBatches();
}

/**
 * Persists a created batch + codes and navigates to its sheet.
 */
export async function persistAndGo(batch: BatchRecord, codes: CodeRecord[]): Promise<void> {
  if (!batch?.id) throw new Error("persistAndGo: missing batch");
  if (!Array.isArray(codes)) throw new Error("persistAndGo: codes must be a list");

  await putBatch(batch);
  await putCodes(codes);
  window.location.href = `/sheet/${batch.id}`;
}
