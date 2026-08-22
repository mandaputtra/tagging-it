import "fake-indexeddb/auto";
import { beforeEach, describe, expect, it } from "vitest";
import * as store from "../js/batch_store.js";
import { makeBatch, makeCode } from "./fixtures.js";

// fake-indexeddb persists the database at the global level across tests, so
// wipe every store before each test.
beforeEach(async () => {
  const db = await store.open();
  await Promise.all(["batches", "codes", "meta"].map((name) => db.clear(name)));
});

describe("batch_store", () => {
  it("putBatch/getBatch round-trips a batch", async () => {
    const batch = makeBatch();
    await store.putBatch(batch);
    expect(await store.getBatch(batch.id)).toEqual(batch);
  });

  it("putCodes + codesByBatch returns only that batch's codes", async () => {
    await store.putCodes([
      makeCode("c1", "b1", "ITM00000120260822"),
      makeCode("c2", "b1", "ITM00000220260822"),
    ]);
    await store.putCodes([makeCode("c3", "b2", "ITM00000320260822")]);
    const codes = await store.codesByBatch("b1");
    expect(codes.map((c) => c.id).sort()).toEqual(["c1", "c2"]);
  });

  it("listBatches returns all batches", async () => {
    await store.putBatch(makeBatch("b1"));
    await store.putBatch(makeBatch("b2", "Batch Two"));
    expect((await store.listBatches()).map((b) => b.id).sort()).toEqual(["b1", "b2"]);
  });

  it("listCodes returns all codes", async () => {
    await store.putCodes([
      makeCode("c1", "b1", "ITM00000120260822"),
      makeCode("c2", "b2", "ITM00000220260822"),
    ]);
    expect((await store.listCodes()).map((c) => c.id).sort()).toEqual(["c1", "c2"]);
  });

  it("deleteBatch removes the batch and its codes (cascade)", async () => {
    await store.putBatch(makeBatch("b1"));
    await store.putBatch(makeBatch("b2"));
    await store.putCodes([
      makeCode("c1", "b1", "ITM00000120260822"),
      makeCode("c2", "b1", "ITM00000220260822"),
    ]);
    await store.putCodes([makeCode("c3", "b2", "ITM00000320260822")]);
    await store.deleteBatch("b1");
    expect(await store.getBatch("b1")).toBeUndefined();
    expect(await store.codesByBatch("b1")).toEqual([]);
    expect(await store.codesByBatch("b2")).toHaveLength(1);
  });

  it("putMeta/getMeta round-trips meta values", async () => {
    await store.putMeta("theme", "dark");
    await store.putMeta("count", 42);
    expect(await store.getMeta("theme")).toBe("dark");
    expect(await store.getMeta("count")).toBe(42);
    expect(await store.getMeta("missing")).toBeUndefined();
  });

  it("open() is idempotent across calls", async () => {
    const first = await store.open();
    const second = await store.open();
    expect(first).toBe(second);
    await store.putBatch(makeBatch());
    expect(await store.getBatch("b1")).toBeDefined();
  });
});
