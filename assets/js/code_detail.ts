// Client bridge: validates a code + its batch before pushing `code:loaded` to
// CodeDetailLive (#24). Mirrors batch_detail.ts / sheet_bridge.ts — the wire
// payloads are validated in pure, unit-tested builders.
import type { BatchRecord, CodeRecord, CodeDetailWire } from "./types.js";

export function buildCodeDetailPayload(batch: BatchRecord, code: CodeRecord): CodeDetailWire {
  if (code.batch_id !== batch.id) {
    throw new Error("code references a different batch than the one loaded");
  }
  return { batch, code };
}
