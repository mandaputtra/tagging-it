// @vitest-environment happy-dom
import "fake-indexeddb/auto";
import { describe, it, expect, beforeEach } from "vitest";
import { deleteBatchAndRefresh } from "../js/batch_creator.js";
import { putBatch, putCodes, getBatch, open } from "../js/batch_store.js";
import { makeBatch, makeCode } from "./fixtures.js";

beforeEach(async () => {
  const db = await open();
  await Promise.all(["batches", "codes", "meta"].map((name) => db.clear(name)));
});

describe("deleteBatchAndRefresh", () => {
  it("removes the batch and its codes from IndexedDB", async () => {
    await putBatch(makeBatch("b1", "One"));
    await putBatch(makeBatch("b2", "Two"));
    await putCodes([makeCode("c1", "b1", "A1")]);

    const remaining = await deleteBatchAndRefresh("b1");

    expect(await getBatch("b1")).toBeUndefined();
    expect(remaining.map((b) => b.id)).toEqual(["b2"]);
  });

  it("returns the full remaining list (capped at 6) for the landing re-render", async () => {
    for (let i = 1; i <= 7; i++) {
      await putBatch(makeBatch(`b${i}`, `Batch ${i}`));
    }
    const remaining = await deleteBatchAndRefresh("b1");
    expect(remaining).toHaveLength(6);
    expect(remaining.some((b) => b.id === "b1")).toBe(false);
  });

  it("rejects when the batch id is missing", async () => {
    await expect(deleteBatchAndRefresh("")).rejects.toThrow(/batch/i);
  });
});
