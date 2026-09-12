# Ingest MIME / file-type enforcement

**Status:** idea only — not roadmapped. Parked after shipping MIME-derived `objects/…` extensions ([`archive/image-optimization.md`](archive/image-optimization.md)). Related UI: [`file-type-fallback-thumbnails.md`](file-type-fallback-thumbnails.md). Domain: [`source-layer-data-model.md`](../source-layer-data-model.md) §6; ingest: `core/ingest`.

## Problem

Ingest today accepts **any** regular file ≤ 512 MiB. `http.DetectContentType` only records advisory `media_type` (and drives object-path suffixes via `ExtensionForMediaType`). There is **no allowlist**.

That is fine for early dogfood, but as evidence volume grows we will want a hard product boundary:

- Reject malware-shaped / irrelevant payloads (executables, archives we never open, random binaries)
- Keep the catalog and Finder-facing object store focused on genealogical evidence (scans, photos, PDFs, maybe AV)
- Give researchers a clear error instead of a faceless blob they cannot preview
- Align open-panel filters, FFI errors, and `ExtensionForMediaType` so “allowed to attach” and “gets a real extension” stay in sync

Thumbnail rasterization already has a **narrow** image allowlist (`core/derivatives/raster`); that only skips thumbs — the File still lands. Enforcement at ingest is a different gate.

## Idea

Add a first-class **ingest media policy** in Go (single source of truth):

1. **Allowlist** of MIME types (and/or sniffed format families) Provenencia will accept as Artifact primary Files.
2. On ingest: sniff as today → if not allowed → `ingest.unsupported_type` (or similar) → no object write, no `files` row.
3. macOS open panel optionally filters to the same set (UX); **Go remains authoritative** so CLI / future Windows cannot bypass.
4. Keep `ExtensionForMediaType` as the naming map for allowed types; unknown allowed types (if any) stay bare hex until mapped.

Suggested v1 families (exact list TBD):

| Family | Examples |
| --- | --- |
| Images | `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `image/tiff`, `image/bmp` |
| Documents | `application/pdf` |
| Maybe later | common Office, plain text, audio/video oral-history |

Non-goals for the first cut: magic-byte forensics beyond Go’s sniff, per-Source-type allowlists, user-editable policy, converting HEIC/etc. on ingest.

## Open questions

- Sniff-only vs also require `original_filename` extension to agree (reject `evil.exe` renamed `.jpg`)?
- Reject `application/octet-stream` / `text/plain` always, or allow with a weaker path?
- Should already-ingested disallowed types stay readable, or only gate **new** ingest?
- Share one table with raster thumb allowlist + MIME glyph map, or keep ingest wider than “can thumbnail”?
- L10n / open-panel copy when the researcher picks a blocked type

## Suggested home

- Policy + check: `core/ingest` (next to sniff) or small `core/ingest/mediatypes`
- FFI: map new code under `L10n.Errors`
- Docs: note in source-layer / application-stack when shipped
