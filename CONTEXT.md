# Tagging It

Freemium web app for generating QR codes and barcodes with customizable text labels, printable from a laptop browser. Free tier runs entirely client-side; premium adds server sync.

## Language

**Code**:
A single generated barcode or QR code with its data payload and label fields.
_Avoid_: Barcode, QR, item (ambiguous with the physical thing being labeled)

**Batch**:
A group of codes created together from one batch template.
_Avoid_: Project, collection

**Batch template**:
The shared definition that pre-fills a batch: field names, shared field values, code-data generation strategy, and label size.
_Avoid_: Template (ambiguous with label template), preset

**Field**:
A `{field_name, value}` pair rendered on a label. Free-form; no preset taxonomy.
_Avoid_: Attribute, property, metadata

**Field map**:
The resolved, ordered list of fields stored on each code. Batch edits affect future codes only.
_Avoid_: Fields (the column), label data

**Label**:
The printable artifact: barcode plus its field map, at a chosen label size.
_Avoid_: Sticker, tag, printout

**Label size**:
A preset sheet geometry (e.g. Avery 5160) or a custom W×H. Custom sizes print single-label-per-page.
_Avoid_: Paper size (belongs to the printer driver)

**Code data**:
The value encoded in the barcode — generated per batch strategy: custom pattern (prefix + sequence + date) or ULID.
_Avoid_: Payload, content, raw value

**Sync**:
Premium feature: replicating codes and batches between client IndexedDB and the server via `POST /api/sync`.
_Avoid_: Backup, export/import (those are client-side JSON file transfers)
