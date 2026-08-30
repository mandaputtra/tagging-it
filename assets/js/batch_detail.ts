// Client bridge: validates batch + codes before pushing `detail:loaded` to BatchDetailLive.
import type { BatchRecord, CodeRecord, BatchDetailWire } from "./types.js";

export function buildBatchDetailPayload(
  batch: BatchRecord,
  codes: CodeRecord[],
): BatchDetailWire {
  if (codes.some((code) => code.batch_id !== batch.id)) {
    throw new Error("codes reference a different batch than the one loaded");
  }
  return { batch, codes };
}
