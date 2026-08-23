// Typed test fixtures matching the wire contract (see js/types.ts).
import type { BatchRecord, CodeRecord } from "../js/types.js";

const now = () => new Date().toISOString();

export function makeBatch(id: string = "b1", name: string = "Batch One"): BatchRecord {
  return {
    id,
    name,
    template: {
      name,
      fields: [{ name: "item", value: "widget" }],
      strategy: { type: "pattern", prefix: "ITM", start: 1, count: 2, date: "2026-08-22" },
      symbology: "qr",
      label_size: "avery5160",
      show_sequence: true,
    },
    code_ids: ["c1", "c2"],
    created_at: now(),
    updated_at: now(),
    dirty: true,
  };
}

export function makeCode(id: string, batchId: string, codeData: string): CodeRecord {
  return {
    id,
    batch_id: batchId,
    sequence: codeData,
    code_data: codeData,
    symbology: "qr",
    fields: [{ name: "item", value: "widget" }],
    created_at: now(),
    updated_at: now(),
    dirty: true,
  };
}
