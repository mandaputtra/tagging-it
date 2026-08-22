// @vitest-environment happy-dom
import { describe, it, expect, vi, beforeEach } from "vitest";
import { buildSheetPayload, renderBarcodes, type BarcodeOpts } from "../js/sheet_bridge.js";
import type { BatchRecord, CodeRecord } from "../js/types.js";

const template = {
  name: "T",
  fields: [] as { name: string; value: string }[],
  strategy: { type: "pattern" as const },
  symbology: "code128",
  label_size: "avery5160" as const,
};

describe("buildSheetPayload", () => {
  it("shapes batch + codes into the wire payload with ISO timestamps", () => {
    const batch: BatchRecord = {
      id: "b1",
      name: "Products",
      template,
      code_ids: ["c1"],
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      dirty: true,
    };
    const codes: CodeRecord[] = [
      {
        id: "c1",
        batch_id: "b1",
        code_data: "CODEPRODUCT00000120260101",
        symbology: "code128",
        fields: [{ name: "SKU", value: "" }],
        created_at: "2026-01-01T00:00:00.000Z",
        updated_at: "2026-01-01T00:00:00.000Z",
        dirty: true,
      },
    ];

    expect(buildSheetPayload(batch, codes)).toEqual({ batch, codes });
  });

  it("throws when codes reference a different batch", () => {
    const batch: BatchRecord = {
      id: "b1",
      name: "Products",
      template,
      code_ids: [],
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
      dirty: true,
    };
    const codes: CodeRecord[] = [
      {
        id: "c1",
        batch_id: "b2",
        code_data: "X",
        symbology: "code128",
        fields: [],
        created_at: "2026-01-01T00:00:00.000Z",
        updated_at: "2026-01-01T00:00:00.000Z",
        dirty: true,
      },
    ];
    expect(() => buildSheetPayload(batch, codes)).toThrow(/batch/i);
  });
});

describe("renderBarcodes", () => {
  let container: HTMLElement;
  let toSvg: ReturnType<typeof vi.fn<(opts: BarcodeOpts) => string>>;

  beforeEach(() => {
    container = document.createElement("div");
    document.body.appendChild(container);
    toSvg = vi.fn<(opts: BarcodeOpts) => string>(
      (opts) => `<svg data-test="svg" data-bcid="${opts.bcid}" data-text="${opts.text}"></svg>`,
    );
  });

  it("injects an SVG into each barcode placeholder", () => {
    container.innerHTML = `
      <div class="barcode" data-code-id="c1" data-bcid="code128" data-text="ABC123"></div>
      <div class="barcode" data-code-id="c2" data-bcid="qrcode" data-text="XYZ"></div>
    `;

    renderBarcodes(container, toSvg);

    expect(toSvg).toHaveBeenCalledTimes(2);
    const svgs = container.querySelectorAll(".barcode svg");
    expect(svgs.length).toBe(2);
    expect((svgs[0] as HTMLElement).dataset.bcid).toBe("code128");
    expect((svgs[0] as HTMLElement).dataset.text).toBe("ABC123");
    expect((svgs[1] as HTMLElement).dataset.bcid).toBe("qrcode");
  });

  it("skips placeholders already rendered", () => {
    container.innerHTML = `
      <div class="barcode" data-code-id="c1" data-bcid="code128" data-text="ABC"><svg></svg></div>
    `;

    renderBarcodes(container, toSvg);
    expect(toSvg).not.toHaveBeenCalled();
  });

  it("renders inline error text when toSvg throws", () => {
    toSvg.mockImplementation(() => {
      throw new Error("unknown symbology");
    });
    container.innerHTML = `
      <div class="barcode" data-code-id="c1" data-bcid="bogus" data-text="ABC"></div>
    `;

    renderBarcodes(container, toSvg);

    expect(container.querySelector(".barcode")?.textContent).toContain("error");
    expect(container.querySelector(".barcode svg")).toBeNull();
  });

  it("no-op when there are no placeholders", () => {
    renderBarcodes(container, toSvg);
    expect(toSvg).not.toHaveBeenCalled();
  });
});
