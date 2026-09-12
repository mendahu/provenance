# Evidence thumbnails: file-type fallbacks, Source-type icons, and primary Artifact

**Status:** idea only — not roadmapped. Related client media work: [`image-optimization.md`](image-optimization.md). Domain: [`source-layer-data-model.md`](../source-layer-data-model.md) §§3, 6–8; vocabulary: [`seeded-vocabulary.md`](../seeded-vocabulary.md) §2.1.

## Problem

### Non-image Files look empty

`derivatives.EnsureThumbnail` only rasterizes common **image** MIME types. PDFs, Office docs, video, and other evidence skip cleanly — Artifact rows and Sources list cells fall back to a generic empty `PVThumbnail`. Researchers still need a **recognizable** stand-in: “this is a PDF,” “this is a video,” not a blank square.

### Fileless / physical Artifacts look empty too

An Artifact with no File (physical book on the shelf, cassette in a box, courthouse register only seen on microfilm) has nothing to rasterize. A MIME glyph does not apply. The **Source type** is the best signal for what kind of evidence it is — birth certificate, oral history, parish register — if types can carry a **representational icon**.

### Sources have many Artifacts; which thumb represents the Source?

A Source can own several Artifacts, each with zero or one primary File, each File optionally with a thumbnail derivative. List rows and Source identity chrome need **one** representation for the Source. Today the list is enriched with *some* `thumbnail_rel_path` (first available raster path in practice) — there is no durable, user-controllable choice when multiple thumbs (or only fallbacks) exist.

## Idea

Three cooperating layers of representation, in preference order when resolving what to show:

```text
1. Raster file_derivatives thumbnail (when present)
2. File-type glyph (PDF / MP4 / …) when there is a File but no raster thumb
3. Source-type icon (book, microfilm, interview, …) for fileless Artifacts — or when chosen as Source cover
4. Generic empty placeholder
```

### 1. File-type fallback thumbnails

When there is a File but no raster thumbnail derivative, render a **typed fallback** in `PVThumbnail` (or a thin wrapper):

| Kind of stand-in | Examples |
| --- | --- |
| Document badge | PDF, DOC/DOCX, RTF, plain text |
| Spreadsheet / slides | XLS, CSV, PPT (if we care) |
| Media | MP4 / MOV / audio waveform-style glyph |
| Generic file | unknown / `application/octet-stream` |

Visual language: archival (not colorful emoji), e.g. document silhouette with a short type label (`PDF`, `MP4`) in mono. Map from `files.media_type` and/or filename extension; one shared map (design-system helper).

**Not** inventing fake JPEG derivatives for PDFs in Go unless we later add real `pdf_page_preview`. MIME fallback is **UI chrome**, not a `file_derivatives` row.

### 2. Source-type icon vocabulary

Design a **curated collection** of icons that represent *kinds of evidence*, independent of digital file format. Examples to explore in Design:

- Generic book / bound volume
- Loose document / certificate
- Parchment / scroll
- Cassette / magnetic tape
- Microfilm / microfiche
- Video / film reel
- Audio / interview / oral history
- Photograph / album (even when no File yet)
- Map / plat
- Newspaper / clipping
- Digital-native / website (if useful)
- Generic “evidence” fallback for custom types

**On Source types:** when creating or editing a type (seeded or user), the researcher **picks one icon** from the collection (stored as a stable key on `source_types`, e.g. `icon_key`, not raw image bytes). Seeded `provenencia` types ship with sensible defaults; user types default to a generic document/book until changed.

**Where it shows**

| Surface | Behavior |
| --- | --- |
| **Fileless Artifact** | Use the parent Source’s type icon as the Artifact row thumbnail (physical-only stand-in). |
| **Source cover (optional)** | User may set the Source-level thumbnail to the **type icon** (not only to an Artifact raster/MIME glyph) — useful when all Artifacts are fileless or when the type mark is a better list identity than a random scan. |
| **Vocabulary / type lists** | Optional: show the icon next to the type label for scanability. |

Icons live in the **design system** (asset pack + `PVSymbol`-like or dedicated `SourceTypeIcon` keyed enum). Catalog stores only the **key**; clients resolve artwork. Plugins later could register extra keys under a namespaced prefix if needed — keep v1 closed set.

### 3. Source primary thumbnail (rollup + user choice)

Persist what supplies the Source’s representative thumbnail — broader than “which Artifact’s File”:

```text
Source cover resolution
  ├── primary Artifact with raster thumb
  ├── primary Artifact with MIME glyph only
  ├── explicit “use Source type icon”
  └── auto: first raster ensured → else first useful Artifact fallback → else type icon → empty
```

**Default behavior**

- When the **first** raster thumbnail is successfully ensured for any Artifact under the Source, mark that Artifact as the Source’s **primary thumbnail source** (auto).
- If nothing rasterizes (all PDFs / fileless), fall through to MIME glyph or **Source-type icon** so the Sources list is never a wall of blanks.

**User control**

- **Use as Source thumbnail** on an Artifact row (raster or MIME fallback for that Artifact).
- **Use Source type icon as thumbnail** (identity chrome or type picker) so cover can be the type mark even when rasters exist — researcher choice wins over auto.
- Switching updates list + header immediately; one primary mode at a time.

**Schema sketch (when pulled into a spike)**

- `sources.primary_artifact_id` (nullable FK) **and/or** a small cover mode enum (`artifact` | `source_type_icon`) — exact shape TBD.
- `source_types.icon_key` (TEXT, required or defaulted) referencing the curated set.
- List/Get Source still returns enough for Swift to render: either `thumbnail_rel_path` **or** a resolved `cover: { kind: raster|mime|type_icon, … }` so cells stay simple.

## Why these hang together

| Situation | What the researcher sees |
| --- | --- |
| Scanned JPEG Artifact | Real thumb; can be Source cover |
| PDF Artifact | PDF glyph; can be Source cover |
| Fileless “parish register” Artifact | Source-type scroll/book icon |
| Multi-Artifact Source | Explicit primary / type-icon cover instead of opaque “first ensure” |

Without type icons, physical evidence stays blank. Without MIME glyphs, digital non-images stay blank. Without primary/cover control, multi-Artifact Sources stay arbitrary.

## Non-goals (for the parked idea)

- Full in-app PDF/page raster pipeline (`pdf_page_preview`) — heavier; glyphs first
- Replacing content-addressed derivatives with UI-only icons for images that *do* have thumbs
- Async decode cache — stays in [`image-optimization.md`](image-optimization.md)
- Per-Artifact custom uploaded icons (type-level curated set is enough for v1)

## Open questions

- Primary = Artifact id vs File id vs cover-mode enum?
- If user pinned type icon as cover, does a later first raster auto-steal cover or leave the pin?
- If primary Artifact is PDF-only, show PDF glyph or fall through to type icon unless pinned?
- Closed icon set size for v1 (~12–20)? Naming keys (`book`, `microfilm`, `oral_history`, …)?
- Seeded types: which default icons for `birth_certificate` and friends?
- Where do cover actions live — Artifact row, identity header, both?
- Share packages: embed raster only, or also ship `icon_key` / cover mode?

## Related docs

- [`source-layer-data-model.md`](../source-layer-data-model.md) §§3, 6–8
- [`seeded-vocabulary.md`](../seeded-vocabulary.md) §2.1 (`source_types`)
- [`image-optimization.md`](image-optimization.md)
- [`artifact-file-storage.md`](../artifact-file-storage.md)
- Spike 2 completed notes for S2-12 / S2-26 (thumbnail ensure + list enrichment)
