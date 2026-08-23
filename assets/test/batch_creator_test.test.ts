// @vitest-environment happy-dom
import "fake-indexeddb/auto";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { persistAndGo } from "../js/batch_creator.js";
import { getBatch, codesByBatch, open } from "../js/batch_store.js";
import type { BatchRecord, CodeRecord } from "../js/types.js";

const batch: BatchRecord = {
  id: "b-1",
  name: "Products",
  template: { name: "T", fields: [], strategy: { type: "pattern" }, symbology: "code128", label_size: "avery5160", show_sequence: true },
  code_ids: ["c-1", "c-2"],
  created_at: "2026-01-01T00:00:00.000Z",
  updated_at: "2026-01-01T00:00:00.000Z",
  dirty: true,
};

const codes: CodeRecord[] = [
  {
    id: "c-1",
    batch_id: "b-1",
    sequence: "CODEPRODUCT00000120260101",
    code_data: "CODEPRODUCT00000120260101",
    symbology: "code128",
    fields: [{ name: "SKU", value: "" }],
    created_at: "2026-01-01T00:00:00.000Z",
    updated_at: "2026-01-01T00:00:00.000Z",
    dirty: true,
  },
  {
    id: "c-2",
    batch_id: "b-1",
    sequence: "CODEPRODUCT00000220260101",
    code_data: "CODEPRODUCT00000220260101",
    symbology: "code128",
    fields: [{ name: "SKU", value: "" }],
    created_at: "2026-01-01T00:00:00.000Z",
    updated_at: "2026-01-01T00:00:00.000Z",
    dirty: true,
  },
];

beforeEach(async () => {
  const db = await open();
  await Promise.all(["batches", "codes", "meta"].map((name) => db.clear(name)));
  vi.stubGlobal("location", { href: "" });
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("persistAndGo", () => {
  it("persists the batch and its codes to IndexedDB", async () => {
    await persistAndGo(batch, codes);

    expect(await getBatch("b-1")).toEqual(batch);
    const stored = await codesByBatch("b-1");
    expect(stored.map((c) => c.id).sort()).toEqual(["c-1", "c-2"]);
  });

  it("navigates to the sheet for the created batch", async () => {
    await persistAndGo(batch, codes);
    expect(window.location.href).toBe("/sheet/b-1");
  });

  it("rejects when the payload is not a batch+codes pair", async () => {
    await expect(persistAndGo(null as unknown as BatchRecord, codes)).rejects.toThrow(/batch/i);
  });
});
