// @vitest-environment happy-dom
import { describe, it, expect } from "vitest";
import { buildBatchDetailPayload } from "../js/batch_detail.js";
import type { BatchRecord, CodeRecord } from "../js/types.js";

describe("single-code batch size 1", () => {
  it("builds a batch detail payload with one code (single = batch size 1)", () => {
    const batch: BatchRecord = {
      id: "b-single",
      name: "Single",
      template: { name: "Single", fields: [], strategy: { type: "paste" }, symbology: "qrcode", label_size: "avery5160", show_sequence: true },
      code_ids: ["c-1"],
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      dirty: true,
    };
    const code: CodeRecord = {
      id: "c-1",
      batch_id: "b-single",
      sequence: "1",
      code_data: "MY-VALUE-001",
      symbology: "qrcode",
      fields: [],
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      dirty: true,
    };
    const payload = buildBatchDetailPayload(batch, [code]);
    expect(payload.batch.id).toBe("b-single");
    expect(payload.codes).toHaveLength(1);
    expect(payload.codes[0].code_data).toBe("MY-VALUE-001");
  });
});
