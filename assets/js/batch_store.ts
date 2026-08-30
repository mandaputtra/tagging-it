import { openDB, type IDBPDatabase } from "idb";
import type { BatchRecord, CodeRecord } from "./types.js";

const DB_NAME = "tagging-it";
const DB_VERSION = 2;

interface TaggingItSchema {
  batches: { key: string; value: BatchRecord };
  codes: {
    key: string;
    value: CodeRecord;
    indexes: { batchId: string; code_data: string; sequence: string };
  };
  meta: { key: string; value: { key: string; value: unknown } };
}

// Module-level singleton: open() is idempotent and reusable across calls.
let dbPromise: Promise<IDBPDatabase<TaggingItSchema>> | null = null;

export function open(): Promise<IDBPDatabase<TaggingItSchema>> {
  if (!dbPromise) {
    dbPromise = openDB<TaggingItSchema>(DB_NAME, DB_VERSION, {
      upgrade(db, oldVersion, _newVersion, transaction) {
        if (!db.objectStoreNames.contains("batches")) {
          db.createObjectStore("batches", { keyPath: "id" });
        }
        if (!db.objectStoreNames.contains("codes")) {
          const codes = db.createObjectStore("codes", { keyPath: "id" });
          codes.createIndex("batchId", "batch_id");
          codes.createIndex("code_data", "code_data");
          codes.createIndex("sequence", "sequence");
        } else if (oldVersion < 2) {
          const codes = transaction.objectStore("codes");
          if (!codes.indexNames.contains("code_data")) codes.createIndex("code_data", "code_data");
          if (!codes.indexNames.contains("sequence")) codes.createIndex("sequence", "sequence");
        }
        if (!db.objectStoreNames.contains("meta")) {
          db.createObjectStore("meta", { keyPath: "key" });
        }
      },
    });
  }
  return dbPromise;
}

export async function putBatch(batch: BatchRecord): Promise<void> {
  const db = await open();
  await db.put("batches", batch);
}

export async function putCodes(codes: CodeRecord[]): Promise<void> {
  const db = await open();
  const tx = db.transaction("codes", "readwrite");
  for (const code of codes) {
    await tx.store.put(code);
  }
  await tx.done;
}

export async function listBatches(): Promise<BatchRecord[]> {
  const db = await open();
  return db.getAll("batches");
}

export async function getBatch(id: string): Promise<BatchRecord | undefined> {
  const db = await open();
  return db.get("batches", id);
}

export async function codesByBatch(batchId: string): Promise<CodeRecord[]> {
  const db = await open();
  return db.getAllFromIndex("codes", "batchId", batchId);
}

export async function listCodes(): Promise<CodeRecord[]> {
  const db = await open();
  return db.getAll("codes");
}

export async function getCode(id: string): Promise<CodeRecord | undefined> {
  const db = await open();
  return db.get("codes", id);
}

export async function codesByValue(value: string): Promise<CodeRecord[]> {
  const db = await open();
  try {
    const byData = await db.getAllFromIndex("codes", "code_data", value);
    if (byData.length) return byData;
    return db.getAllFromIndex("codes", "sequence", value);
  } catch {
    // Fallback for pre-v2 stores before migration (index missing)
    const all = await db.getAll("codes");
    return all.filter((c) => c.code_data === value || c.sequence === value);
  }
}

export async function deleteBatch(id: string): Promise<void> {
  const db = await open();
  const tx = db.transaction(["batches", "codes"], "readwrite");
  const codeIds = await tx.objectStore("codes").index("batchId").getAllKeys(id);
  for (const codeId of codeIds) {
    await tx.objectStore("codes").delete(codeId);
  }
  await tx.objectStore("batches").delete(id);
  await tx.done;
}

export async function putMeta(key: string, value: unknown): Promise<void> {
  const db = await open();
  await db.put("meta", { key, value });
}

export async function getMeta(key: string): Promise<unknown> {
  const db = await open();
  const row = await db.get("meta", key);
  return row ? row.value : undefined;
}
