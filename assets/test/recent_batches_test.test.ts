// @vitest-environment happy-dom
import { describe, it, expect } from "vitest";
import { recentBatchesPayload } from "../js/recent_batches.js";
import type { BatchRecord } from "../js/types.js";

describe("recentBatchesPayload", () => {
  const batches: BatchRecord[] = [
    {
      id: "b-1",
      name: "Products",
      template: { name: "T", fields: [], strategy: { type: "pattern" }, symbology: "code128", label_size: "avery5160" },
      code_ids: ["c1", "c2", "c3"],
      created_at: "2026-08-01T00:00:00.000Z",
      updated_at: "2026-08-22T10:00:00.000Z",
      dirty: true,
    },
    {
      id: "b-2",
      name: "Old labels",
      template: { name: "T", fields: [], strategy: { type: "pattern" }, symbology: "code128", label_size: "avery5160" },
      code_ids: ["c4"],
      created_at: "2026-08-01T00:00:00.000Z",
      updated_at: "2026-08-01T10:00:00.000Z",
      dirty: true,
    },
  ];

  it("maps batches to id, name, updated_at, code_count", () => {
    expect(recentBatchesPayload(batches)).toEqual([
      { id: "b-1", name: "Products", updated_at: "2026-08-22T10:00:00.000Z", code_count: 3 },
      { id: "b-2", name: "Old labels", updated_at: "2026-08-01T10:00:00.000Z", code_count: 1 },
    ]);
  });

  it("sorts most-recently-updated first", () => {
    const newest = recentBatchesPayload(batches);
    expect(newest[0].id).toBe("b-1");
  });

  it("caps the list at 6 batches", () => {
    const many: BatchRecord[] = Array.from({ length: 10 }, (_, i) => ({
      id: `b-${i}`,
      name: `B${i}`,
      template: { name: "T", fields: [], strategy: { type: "pattern" }, symbology: "code128", label_size: "avery5160" },
      code_ids: [],
      created_at: "2026-08-01T00:00:00.000Z",
      updated_at: `2026-08-01T00:00:0${i}.000Z`,
      dirty: true,
    }));
    expect(recentBatchesPayload(many)).toHaveLength(6);
  });

  it("returns [] for empty input", () => {
    expect(recentBatchesPayload([])).toEqual([]);
  });
});
