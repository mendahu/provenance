# Provenance Genealogy — Artifact and File Storage

## Status

Draft architecture notes. This document refines the Source-layer Artifact and File model described by the core data-model documentation.

---

# 1. Design philosophy

## 1.1 Artifacts are representations of Sources

A Source is the evidentiary object. An Artifact is a concrete representation of that Source.

```text
Source
  ├── Artifact
  ├── Artifact
  └── Artifact
```

Examples include a scan, photograph, PDF, audio recording, downloaded export, or a placeholder representing a physical copy that has not been digitized.

Multiple representations belong as multiple Artifacts under the same Source. Provenance does not model one Artifact as having several files for original, derivative, thumbnail, or alternate-format representations.

For example:

```text
Source: family photograph
  Artifact: original TIFF scan
  Artifact: JPEG derivative
```

rather than:

```text
Artifact: family photograph
  File: original TIFF
  File: JPEG derivative
```

This keeps Artifact identity aligned with a concrete representation and leaves the Source responsible for grouping representations of the same evidence.

## 1.2 No `artifact_type`

Artifacts do not use an `artifact_type` classification field or an `artifact_types` vocabulary.

The earlier `artifact_type` concept mixed several different dimensions such as acquisition method, content, representation, and file format. File format and technical handling are already represented more precisely by file metadata such as MIME media type.

If a future workflow requires an additional semantic distinction between Artifacts, that distinction should be introduced only when there is a concrete use case rather than creating a generic Artifact type taxonomy in advance.

## 1.3 Offline-first ingestion

Provenance should not depend on an external service, website, URL, mounted drive, or other remote resource in order to access digital evidence already added to a project.

The governing rule is:

> Digital evidence added to Provenance is ingested into application-managed local storage. External locations are Source provenance/reference information, not runtime dependencies for Artifact access.

An external URL may therefore be retained on the Source, but it does not replace local ingestion.

This supports:

- fully offline research;
- durable projects when websites disappear or URLs change;
- project portability;
- integrity checking;
- predictable backup behavior;
- independence from third-party services.

## 1.4 Artifacts may exist without files

Not every Artifact has a digital file.

For example, a researcher may record the existence of a physical family Bible that has not yet been photographed or scanned.

```text
Source: Smith family Bible
  Artifact: physical copy held by relative
  File: none
```

`artifacts.file_id` is therefore nullable.

## 1.5 Files are immutable and history-preserving

Once a File is ingested, its byte content is immutable.

A File's identity is tied to its SHA-256 checksum, so replacing its bytes in place would violate the storage model. If a better scan, corrected export, or otherwise different byte stream is acquired, Provenance creates a new File row and updates the Artifact to reference that new File.

For example:

```text
Revision 220
  CREATE File B
  UPDATE Artifact.file_id: File A -> File B
```

The prior File A remains preserved.

This is required because the audit history may refer to File A when reconstructing earlier project state.

The governing rule is:

> Any File that has ever been referenced by audited research data is retained so historical revisions remain reconstructable.

Ordinary orphan cleanup must therefore not delete a File merely because no current Artifact references it.

---

# 2. Files are storage objects

Artifact and File are separate concepts:

```text
Artifact = evidentiary representation
File     = locally managed digital storage object
```

File storage is application infrastructure rather than genealogical interpretation.

Separating Files from Artifacts provides a clear home for technical concerns such as checksums, media types, byte sizes, storage integrity, and content-addressed storage.

---

# 3. `files`

```sql
CREATE TABLE files (
    id                  BLOB PRIMARY KEY,          -- UUIDv7, 16 bytes
    checksum_sha256     TEXT NOT NULL UNIQUE,
    original_filename   TEXT,
    media_type          TEXT,
    byte_size           INTEGER NOT NULL
) STRICT;
```

## 3.1 Content-addressed storage

The database does not need to persist an absolute or relative filesystem path when the storage location can be deterministically derived from the file checksum.

For example:

```text
SHA-256:
8fce3b...

Managed storage location:
objects/8f/ce/8fce3b...
```

The exact directory-sharding convention is an application/storage implementation detail. The important property is that the mapping from checksum to local storage location is deterministic.

This avoids two competing sources of truth such as:

```text
checksum_sha256
storage_path
```

and makes a project relocatable without rewriting database paths.

## 3.2 Checksum

`checksum_sha256` identifies the stored byte content and supports integrity verification.

It is unique so identical byte content is stored only once in the managed object store. Even though the initial Artifact model permits only one File per Artifact, separate Artifacts may technically reference the same File row if they contain identical bytes.

The checksum is the canonical storage address; the File UUID remains the relational identifier used by the schema.

## 3.3 Original filename

The storage object is not named according to the filename from which it was ingested. The original filename is retained separately as descriptive acquisition information:

```text
original_filename = "IMG_4832.JPG"
checksum_sha256   = "8fce3b..."
```

Renaming or reorganizing managed storage therefore does not destroy the filename originally presented to Provenance.

## 3.4 Media type

`media_type` stores the technical media/MIME type where known, for example:

```text
application/pdf
image/jpeg
image/tiff
audio/mpeg
text/csv
application/json
```

This is technical information used for rendering and file handling. It is not an Artifact classification system.

## 3.5 Byte size

`byte_size` records the exact size of the ingested object and provides an additional integrity and storage-management signal.

## 3.6 File replacement

A File is never edited in place to represent different bytes.

When an Artifact receives a replacement file:

```text
1. ingest the replacement bytes;
2. calculate SHA-256;
3. create or reuse the matching File row;
4. update Artifact.file_id;
5. record the File creation and Artifact update in the same audit revision.
```

Example:

```text
Artifact A
  file_id = File A   -- photocopy scan

replacement operation

File B               -- higher-quality scan
Artifact A
  file_id = File B

Audit revision
  CREATE File B
  UPDATE Artifact A.file_id: File A -> File B
```

File A remains available for historical reconstruction.

---

# 4. `artifacts`

```sql
CREATE TABLE artifacts (
    id              BLOB PRIMARY KEY,          -- UUIDv7, 16 bytes
    source_id       BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    file_id         BLOB REFERENCES files(id),
    description     TEXT
) STRICT;
```

An Artifact has zero or one File.

A digital Artifact normally references a locally ingested File. A physical-only or otherwise non-digital Artifact may have `file_id = NULL`.

The Artifact itself does not store:

```text
artifact_type
file_path
media_type
checksum_sha256
byte_size
```

The first is intentionally omitted; the remaining technical fields belong to `files`.

---

# 5. Deletion policy

The initial implementation should not support destructive deletion of Files.

Removing a current reference to a File is allowed through ordinary audited domain changes, such as replacing `artifacts.file_id`, but the File row and content-addressed object remain preserved.

Likewise, deleting an Artifact or Source in a future implementation must not automatically delete historically referenced Files.

The initial storage model therefore intentionally favors historical integrity over reclaiming disk space.

A future explicit purge feature, if ever added, must be treated as a destructive maintenance operation rather than ordinary CRUD. It would need to account for audit reconstruction and make clear that purged historical states can no longer be fully materialized.

Until such a feature is deliberately designed, Files are retained indefinitely.

---

# 6. Examples

## Digitized certificate

```text
Source: 1897 birth certificate

Artifact:
  description = "Photograph of original certificate"
  file_id -> File A

File A:
  checksum_sha256 = ...
  original_filename = "IMG_4832.JPG"
  media_type = "image/jpeg"
  byte_size = 4281932
```

## Replacing a scan

```text
Source: 1897 birth certificate

Artifact:
  description = "Scan of certificate"

Revision 100:
  Artifact.file_id -> File A
  File A = photocopy scan

Revision 145:
  CREATE File B = higher-quality scan
  UPDATE Artifact.file_id: File A -> File B
```

The current Artifact opens File B. Historical reconstruction at Revision 100 still opens File A.

## Multiple representations

```text
Source: family photograph

Artifact A:
  description = "Archival TIFF scan"
  file_id -> File A

Artifact B:
  description = "JPEG derivative"
  file_id -> File B
```

These are two Artifacts rather than one Artifact with multiple files.

## Physical-only evidence

```text
Source: Smith family Bible

Artifact:
  description = "Physical copy held by Mary Smith"
  file_id = NULL
```

The Source may contain descriptive metadata about the evidence and its provenance without requiring a digital File.

## Externally acquired evidence

```text
Source:
  external provenance/reference = archive website URL

Artifact:
  file_id -> locally ingested File
```

The external reference may be retained as Source metadata or another future Source-level provenance mechanism. Opening the Artifact does not require access to that external location.

---

# 7. Current architectural rules

1. Artifacts do not have an `artifact_type` field.
2. Files are modeled separately from Artifacts.
3. An Artifact has zero or one File.
4. Multiple representations are modeled as multiple Artifacts belonging to the same Source.
5. Digital evidence is ingested into local application-managed storage.
6. External URLs and locations belong to Source provenance and are not Artifact runtime dependencies.
7. Files are content-addressed by SHA-256.
8. File byte content is immutable after ingestion.
9. Replacing a file creates or reuses a different content-addressed File and updates the Artifact reference under audit.
10. Previously referenced Files remain preserved for historical reconstruction.
11. The initial implementation does not support destructive File deletion.
12. Ordinary orphan cleanup must not remove historically referenced Files.
13. The managed storage path is derived from the checksum rather than persisted in the database.
14. The filename presented at ingestion is retained as `original_filename`.
15. MIME/media type and byte size belong to the File.
16. Artifacts without files are valid and support physical-only evidence.
17. All tables use SQLite `STRICT` typing.

This model keeps genealogy semantics, evidentiary representation, and storage infrastructure separate while making every ingested digital source durable, historically reconstructable, and usable offline.