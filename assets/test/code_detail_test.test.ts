// @vitest-environment happy-dom
import { describe, it, expect } from "vitest";
import { buildCodeDetailPayload } from "../js/code_detail.js";
import type { BatchRecord, CodeRecord } from "../js/types.js";
import { makeBatch, makeCode } from "./fixtures.js";

describe("buildCodeDetailPayload", () => {
  it("shapes batch + code into the wire payload", () => {
    const batch: BatchRecord = makeBatch("b-1");
    const code: CodeRecord = makeCode("c-1", "b-1", "ITEM-001");
    expect(buildCodeDetailPayload(batch, code)).toEqual({ batch, code });
  });

  it("throws when the code references a different batch", () => {
    const batch: BatchRecord = makeBatch("b-1");
    const code: CodeRecord = makeCode("c-1", "b-2", "ITEM-001");
    expect(() => buildCodeDetailPayload(batch, code)).toThrow(/batch/i);
  });
});
