# File-type fallback thumbnails and Source primary Artifact

**Status:** idea only — not roadmapped. Related client media work: [`image-optimization.md`](image-optimization.md). Domain: [`source-layer-data-model.md`](../source-layer-data-model.md) §§6–8 (Artifact → File → `file_derivatives`).

## Problem

### Non-image Files look empty

`derivatives.EnsureThumbnail` only rasterizes common **image** MIME types. PDFs, Office docs, video, and other evidence skip cleanly — Artifact rows and Sources list cells fall back to a generic empty `PVThumbnail`. Researchers still need a **recognizable** stand-in: “this is a PDF,” “this is a video,” not a blank square.

Manual “attach a preview image” (hinted in Spike 2 derivative notes) is a later path; most of the time a **file-type glyph** is enough.

### Sources have many Artifacts; which thumb represents the Source?

A Source can own several Artifacts, each with zero or one primary File, each File optionally with a thumbnail derivative. List rows and Source identity chrome need **one** image (or fallback) for the Source. Today the list is enriched with *some* `thumbnail_rel_path` (first available raster path in practice) — there is no durable, user-controllable choice when multiple thumbs exist.

## Idea

### 1. File-type fallback thumbnails

When there is no raster thumbnail derivative (or no File), render a **typed fallback** in `PVThumbnail` (or a thin wrapper):

| Kind of stand-in | Examples |
| --- | --- |
| Document badge | PDF, DOC/DOCX, RTF, plain text |
| Spreadsheet / slides | XLS, CSV, PPT (if we care) |
| Media | MP4 / MOV / audio waveform-style glyph |
| Generic file | unknown / `application/octet-stream` |
| Fileless Artifact | distinct empty / physical-only treatment (already closer to today’s placeholder) |

Visual language: still archival (not colorful emoji), e.g. document silhouette with a short type label (`PDF`, `MP4`) in mono — consistent with Provenencia chrome. Map from `files.media_type` and/or filename extension; keep the map in one place (Swift design-system helper and/or a small shared table of known types).

**Not** generating fake JPEG derivatives for PDFs in Go unless we later add real `pdf_page_preview` (already reserved in the derivatives vocabulary). Fallback is **UI chrome**, not a new `file_derivatives` row — unless dogfood shows we need durable exported previews.

### 2. Source primary Artifact (thumbnail rollup)

Persist which Artifact (or its primary File) supplies the Source’s representative thumbnail.

```text
Source
  ├── Artifact A (image) → File → thumbnail ✓   ← e.g. primary
  ├── Artifact B (PDF)   → File → no raster → type fallback
  └── Artifact C (image) → File → thumbnail ✓
```

**Default behavior**

- When the **first** raster thumbnail is successfully ensured for any Artifact under the Source, mark that Artifact (or File) as the Source’s **primary thumbnail source**.
- If the primary’s File/thumb is later removed and no replacement is chosen, fall back to the next available raster thumb, then to a type-fallback from another Artifact, then to empty.

**User control**

- On the Source page (Artifact row or identity chrome), a clear action: **Use as Source thumbnail** / **Set as cover** (exact copy TBD).
- Switching primary updates list + header immediately; only one primary at a time.

**Schema sketch (when pulled into a spike)**

- Something like `sources.primary_artifact_id` (nullable FK → `artifacts`) **or** `primary_thumbnail_file_id` → `files`, with application rules that the Artifact/File belongs to this Source.
- Prefer Artifact-level primary if the product thought is “this *piece of evidence* represents the Source”; File-level if we only care about the bitmap. Artifact is probably clearer for researchers.

List/Get Source responses keep returning a single `thumbnail_rel_path` (resolved from primary → derivative, else fallback rules) so Swift list cells stay dumb.

## Why both together

Fallbacks make non-image Artifacts legible in lists. Primary selection makes multi-Artifact Sources predictable in the Sources list and omnibar/search chrome later. Without primary, “first thumb we happened to ensure” stays opaque and fights user intent when the best scan is Artifact #3.

## Non-goals (for the parked idea)

- Full in-app PDF/page raster pipeline (`pdf_page_preview`) — related, but heavier; fallback glyphs first
- Replacing content-addressed derivatives with UI-only icons for images that *do* have thumbs
- Async decode cache — stays in [`image-optimization.md`](image-optimization.md)

## Open questions

- Primary = Artifact id vs File id?
- If primary Artifact is PDF-only, does the Source show the **PDF fallback glyph**, or prefer another Artifact’s raster thumb automatically unless the user pinned the PDF?
- Where does “Set as Source thumbnail” live — Artifact row menu, identity header, both?
- Shared glyph set in the design system vs SF Symbols with overlays?
- Interaction with share packages / exports (embed raster only, or also record primary Artifact)?

## Related docs

- [`source-layer-data-model.md`](../source-layer-data-model.md) §§6–8
- [`image-optimization.md`](image-optimization.md)
- [`artifact-file-storage.md`](../artifact-file-storage.md)
- Spike 2 completed notes for S2-12 / S2-26 (thumbnail ensure + list enrichment)
