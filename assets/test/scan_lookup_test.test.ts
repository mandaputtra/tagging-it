// @vitest-environment happy-dom
import "fake-indexeddb/auto";
import { beforeEach, describe, expect, it } from "vitest";
import * as store from "../js/batch_store.js";
import { makeBatch, makeCode } from "./fixtures.js";
import type { CodeRecord } from "../js/types.js";

beforeEach(async () => {
  const db = await store.open();
  await Promise.all(["batches", "codes", "meta"].map((name) => db.clear(name)));
});

describe("codesByValue (DB v2 code_data/sequence indexes + fallback)", () => {
  it("finds a code by code_data (hit)", async () => {
    await store.putCodes([makeCode("c1", "b1", "CODE-001"), makeCode("c2", "b1", "CODE-002")]);
    const hits = await store.codesByValue("CODE-001");
    expect(hits.map((c: CodeRecord) => c.id)).toEqual(["c1"]);
  });

  it("finds by sequence when code_data misses (sequence fallback)", async () => {
    const code = makeCode("c1", "b1", "DATA-XYZ");
    code.sequence = "SEQ-001";
    await store.putCodes([code]);
    const hits = await store.codesByValue("SEQ-001");
    expect(hits.map((c: CodeRecord) => c.id)).toEqual(["c1"]);
  });

  it("returns [] on miss", async () => {
    await store.putCodes([makeCode("c1", "b1", "CODE-001")]);
    expect(await store.codesByValue("UNKNOWN")).toEqual([]);
  });

  it("returns all ambiguous hits when code_data duplicated", async () => {
    await store.putCodes([makeCode("c1", "b1", "DUP"), makeCode("c2", "b2", "DUP")]);
    const hits = await store.codesByValue("DUP");
    expect(hits.map((c: CodeRecord) => c.id).sort()).toEqual(["c1", "c2"]);
  });

  it("handles unicode code_data", async () => {
    await store.putCodes([makeCode("c1", "b1", "SN-✓-0042")]);
    expect((await store.codesByValue("SN-✓-0042")).map((c: CodeRecord) => c.id)).toEqual(["c1"]);
  });

  it("returns [] on empty store", async () => {
    expect(await store.codesByValue("ANY")).toEqual([]);
  });

  it("works after DB v1→v2 upgrade (existing stores gain indexes)", async () => {
    await store.putCodes([makeCode("c1", "b1", "MIG-001")]);
    expect((await store.codesByValue("MIG-001")).map((c: CodeRecord) => c.id)).toEqual(["c1"]);
  });
});

describe("getCode", () => {
  it("fetches a code by id", async () => {
    await store.putCodes([makeCode("c1", "b1", "CODE-001")]);
    expect((await store.getCode("c1"))?.id).toBe("c1");
    expect(await store.getCode("missing")).toBeUndefined();
  });
});
