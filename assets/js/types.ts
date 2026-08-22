// Shared wire contracts between the Elixir server (BatchSerializer /
// SheetLive / BatchFormLive / LandingLive) and the client store (IndexedDB).
// These shapes are the compile-checked version of the payload contract that
// previously lived only in comments.

/** A field rendered on a label: name + value pair. */
export interface Field {
  name: string;
  value: string;
}

/** Strategy that generated a code's data (mirrors server structs). */
export interface Strategy {
  type: "pattern" | "ulid" | "paste";
  prefix?: string;
  start?: number;
  count?: number;
  date?: string;
}

/** Label-size preset (matches `Template.label_size` on the server). */
export type LabelSize = "avery5160" | "custom_2x1" | "custom_50x25";

/** Template shared by all codes in a batch. */
export interface Template {
  name: string;
  fields: Field[];
  strategy: Strategy;
  symbology: string;
  label_size: LabelSize;
}

/** A batch as stored in IndexedDB / pushed by the server. */
export interface BatchRecord {
  id: string;
  name: string;
  template: Template;
  code_ids: string[];
  created_at: string;
  updated_at: string;
  dirty: boolean;
}

/** A single code/label as stored in IndexedDB / pushed by the server. */
export interface CodeRecord {
  id: string;
  batch_id: string;
  code_data: string;
  symbology: string;
  fields: Field[];
  created_at: string;
  updated_at: string;
  dirty: boolean;
}

/** Payload for the `recent:loaded` event pushed to LandingLive. */
export interface RecentBatchWire {
  id: string;
  name: string;
  updated_at: string;
  code_count: number;
}

/** Payload for the `batch:created` event pushed by BatchFormLive. */
export interface BatchCreatedWire {
  batch: BatchRecord;
  codes: CodeRecord[];
}

/** Payload for the `sheet:loaded` event pushed to SheetLive. */
export interface SheetLoadedWire {
  batch: BatchRecord;
  codes: CodeRecord[];
}

/** Payload for the `sheet:update_field` event (field value edit). */
export interface UpdateFieldWire {
  code_id: string;
  field_name: string;
  value: string;
}
