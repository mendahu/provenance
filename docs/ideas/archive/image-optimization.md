# Image optimization (async thumbnail cache + object extensions)

**Status:** done — archived after `ThumbnailCache` / `CachedThumbnail` on macOS and MIME-derived extensions on `objects/…` (`files.StorageRelPath` + `EnsureObjectExtensions` on open).

## Problem

Two related media rough edges:

1. **Sync decode jank** — macOS loaded list and detail thumbnails with sync `NSImage(contentsOf:)` on the SwiftUI render path via `ProjectFiles.thumbnailImage(projectDir:relPath:)`.
2. **Extensionless object store** — project `objects/…` entries were content-addressed hex names with **no file extension**, so Finder showed generic icons and double-click / Quick Look were weaker than for ordinary `….jpg` / `….pdf` files.

Call sites for (1) today:

- Source page identity header
- Source page artifact rows (and expanded primary-file tile)
- Sources list rows (`PVList` thumbnail closure)

Any re-render (draft typing, chip selection, accordion expand, list scroll rebuild) can hit disk again for the same `objects/…` path. That is jank and wasted I/O — not “thumbnails missing.” Go already ensures durable thumbnail derivatives under the project; Swift should not re-decode them every frame.

`PVThumbnail` already has a **loading** state (`Content(loading: true)`). Real image loads never use it.

For (2): hash names are intentional identity (see [`application-stack.md`](../application-stack.md) / [`source-layer-data-model.md`](../source-layer-data-model.md)). Human names stay in `files.original_filename`. We are **not** switching to ingest filenames on disk — only adding a MIME-derived extension so Launch Services / Preview / Quick Look treat objects as normal media.

## Idea

### A. Async loader + in-memory thumbnail cache

Replace sync body reads with an **async loader + small in-memory cache**.

Three layers: **key → memory → miss**.

1. **Cache key** — stable per file, e.g. `(projectDir, thumbnailRelPath)` or the resolved absolute URL. Empty `relPath` → no load → `PVThumbnail.Content.empty`.
2. **In-memory store** — process-lifetime map (`NSCache` or `@MainActor` dictionary) of path → decoded `Image` / `NSImage`. Bound count/cost so memory pressure evicts; a miss just reloads once.
   - **Hit:** return image immediately → `Content(image:)`.
   - **Miss in flight:** show `Content(loading: true)`; coalesce duplicate requests for the same key.
   - **Miss complete:** store result (including a “missing/failed” sentinel so we do not retry forever) and refresh observers.
3. **Async load on miss** — decode off the main thread (`Task.detached` / background queue), hop back to main, write cache, publish. Views observe via a small helper (`ThumbnailCache` / `CachedThumbnail` view + `task(id:)`).

The cache is **decoded images in RAM**, keyed by object path — **not** a second on-disk derivative. Files under `objects/…` remain the durable thumbnails.

#### Call-site shape

```text
relPath empty?     → .empty
cache hit?         → .image
request in flight? → .loading
else               → start load, show .loading
```

One Platform helper shared by Source page header, artifact rows, and Sources list — same bug, same fix.

#### Invalidation

Rare. Content-addressed `relPath` → same bytes. New ingest → new path → natural miss. Switching projects → clear cache or always key by `projectDir` so paths cannot collide.

### B. MIME-derived extensions on `objects/…`

Keep content-addressed layout; append an extension derived from sniffed / stored `media_type` (and the known JPEG for thumbnail derivatives):

```text
objects/{hh}/{hh}/{checksum_hex}.jpg
objects/{hh}/{hh}/{checksum_hex}.pdf
…
```

- Path remains deterministic from checksum + media type (still no competing `storage_path` column).
- `original_filename` stays catalog metadata for UI — do **not** rename objects to ingest basenames.
- Update `files.StorageRelPath` (and ingest / derivative writers) so new objects land with extensions.
- Existing projects: one-shot rename (or copy+verify+delete) of extensionless objects when opened, or a small catalog open migration — exact approach TBD when implementing.
- Any FFI / Swift callers that assume bare hex paths must follow the new convention (rel paths returned from core stay authoritative).

## Suggested home

- Cache: `ProjectFiles` sibling or `ThumbnailCache` under `macos/App/Platform/`
- Thin view wrapper that feeds `PVThumbnail` so features do not reimplement hit/miss/loading
- Extensions: `core/database/files.StorageRelPath` + ingest / `derivatives` writers; docs in source-layer / application-stack when shipped

## Non-goals (for this parked idea)

- Go-side N+1 “ensure thumbnail” inside `GetSourceWorkspace` (separate core/FFI performance pass)
- Resizing / WebP / multi-resolution pipelines beyond what Go already writes
- Remote or network image loading (catalog is local files)
- Storing objects under human-friendly `original_filename` paths (breaks CAS identity / dedup-by-path)

## Open questions

- `NSCache` vs explicit `@MainActor` dictionary + max count?
- Cache `NSImage` or SwiftUI `Image` (or both)?
- Should Sources list prefetch visible rows, or only load on first paint?
- Any need to observe file replacement at the same path (overwrite without new hash)?
- Extension map: which MIME → suffix table (unknown → no extension vs `.bin`)?
- Lazy rename on open vs explicit project upgrade step for existing extensionless objects?
