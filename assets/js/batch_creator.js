// Client-side batch creation handoff: receives the `batch:created` payload
// from BatchFormLive, persists batch + codes in IndexedDB, and navigates to
// the sheet. Free tier never sends this data to the server.
import { putBatch, putCodes } from "./batch_store.js";

/**
 * Persists a created batch + codes and navigates to its sheet.
 * @param {object} batch - wire batch (from the `batch:created` push)
 * @param {Array<object>} codes - wire codes
 * @returns {Promise<void>}
 */
export async function persistAndGo(batch, codes) {
  if (!batch?.id) throw new Error("persistAndGo: missing batch");
  if (!Array.isArray(codes)) throw new Error("persistAndGo: codes must be a list");

  await putBatch(batch);
  await putCodes(codes);
  window.location.href = `/sheet/${batch.id}`;
}
