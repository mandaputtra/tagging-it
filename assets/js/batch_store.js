import { openDB } from "idb";

const DB_NAME = "tagging-it";
const DB_VERSION = 1;

// Module-level singleton: open() is idempotent and reusable across calls.
let dbPromise = null;

export function open() {
  if (!dbPromise) {
    dbPromise = openDB(DB_NAME, DB_VERSION, {
      upgrade(db) {
        if (!db.objectStoreNames.contains("batches")) {
          db.createObjectStore("batches", { keyPath: "id" });
        }
        if (!db.objectStoreNames.contains("codes")) {
          const codes = db.createObjectStore("codes", { keyPath: "id" });
          codes.createIndex("batchId", "batch_id");
        }
        if (!db.objectStoreNames.contains("meta")) {
          db.createObjectStore("meta", { keyPath: "key" });
        }
      },
    });
  }
  return dbPromise;
}

export async function putBatch(batch) {
  const db = await open();
  await db.put("batches", batch);
}

export async function putCodes(codes) {
  const db = await open();
  const tx = db.transaction("codes", "readwrite");
  for (const code of codes) {
    await tx.store.put(code);
  }
  await tx.done;
}

export async function listBatches() {
  const db = await open();
  return db.getAll("batches");
}

export async function getBatch(id) {
  const db = await open();
  return db.get("batches", id);
}

export async function codesByBatch(batchId) {
  const db = await open();
  return db.getAllFromIndex("codes", "batchId", batchId);
}

export async function listCodes() {
  const db = await open();
  return db.getAll("codes");
}

export async function deleteBatch(id) {
  const db = await open();
  const tx = db.transaction(["batches", "codes"], "readwrite");
  const codeIds = await tx.objectStore("codes").index("batchId").getAllKeys(id);
  for (const codeId of codeIds) {
    await tx.objectStore("codes").delete(codeId);
  }
  await tx.objectStore("batches").delete(id);
  await tx.done;
}

export async function putMeta(key, value) {
  const db = await open();
  await db.put("meta", { key, value });
}

export async function getMeta(key) {
  const db = await open();
  const row = await db.get("meta", key);
  return row ? row.value : undefined;
}
