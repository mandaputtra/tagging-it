// @vitest-environment happy-dom
import { describe, it, expect, beforeEach } from "vitest";
import { buildBatchDetailPayload } from "../js/batch_detail.js";
import type { BatchRecord, CodeRecord } from "../js/types.js";

const template = {
  name: "T",
  fields: [] as { name: string; value: string }[],
  strategy: { type: "pattern" as const },
  symbology: "qrcode",
  label_size: "avery5160" as const,
  show_sequence: true,
};

describe("buildBatchDetailPayload", () => {
  it("shapes batch + codes into the wire payload", () => {
    const batch: BatchRecord = {
      id: "b-1",
      name: "Batch One",
      template,
      code_ids: ["c-1", "c-2"],
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      dirty: true,
    };
    const codes: CodeRecord[] = [
      {
        id: "c-1",
        batch_id: "b-1",
        sequence: "ITEM00000120260101",
        code_data: "ITEM00000120260101",
        symbology: "qrcode",
        fields: [],
        created_at: "2026-01-01T00:00:00.000Z",
        updated_at: "2026-01-01T00:00:00.000Z",
        dirty: true,
      },
      {
        id: "c-2",
        batch_id: "b-1",
        sequence: "ITEM00000220260101",
        code_data: "ITEM00000220260101",
        symbology: "qrcode",
        fields: [],
        created_at: "2026-01-01T00:00:00.000Z",
        updated_at: "2026-01-01T00:00:00.000Z",
        dirty: true,
      },
    ];
    expect(buildBatchDetailPayload(batch, codes)).toEqual({ batch, codes });
  });

  it("throws when codes reference a different batch", () => {
    const batch: BatchRecord = {
      id: "b-1",
      name: "Batch One",
      template,
      code_ids: ["c-1"],
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      dirty: true,
    };
    const codes: CodeRecord[] = [
      {
        id: "c-1",
        batch_id: "b-2",
        sequence: "ITEM00000120260101",
        code_data: "ITEM00000120260101",
        symbology: "qrcode",
        fields: [],
        created_at: "2026-01-01T00:00:00.000Z",
        updated_at: "2026-01-01T00:00:00.000Z",
        dirty: true,
      },
    ];
    expect(() => buildBatchDetailPayload(batch, codes)).toThrow(/batch/i);
  });

  it("allows empty codes (batch with no codes)", () => {
    const batch: BatchRecord = {
      id: "b-1",
      name: "Empty",
      template,
      code_ids: [],
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      dirty: true,
    };
    expect(buildBatchDetailPayload(batch, [])).toEqual({ batch, codes: [] });
  });
});
