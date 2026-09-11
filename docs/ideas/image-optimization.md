# Image optimization (async thumbnail cache)

**Status:** idea only — not roadmapped. Parked from Source page structural cleanup (fix 13); do later with other client image / media work.

## Problem

macOS loads list and detail thumbnails with sync `NSImage(contentsOf:)` on the SwiftUI render path via `ProjectFiles.thumbnailImage(projectDir:relPath:)`.

Call sites today:

- Source page identity header
- Source page artifact rows (and expanded primary-file tile)
- Sources list rows (`PVList` thumbnail closure)

Any re-render (draft typing, chip selection, accordion expand, list scroll rebuild) can hit disk again for the same `objects/…` path. That is jank and wasted I/O — not “thumbnails missing.” Go already ensures durable thumbnail derivatives under the project; Swift should not re-decode them every frame.

`PVThumbnail` already has a **loading** state (`Content(loading: true)`). Real image loads never use it.

## Idea

Replace sync body reads with an **async loader + small in-memory cache**.

### How the cache works

Three layers: **key → memory → miss**.

1. **Cache key** — stable per file, e.g. `(projectDir, thumbnailRelPath)` or the resolved absolute URL. Empty `relPath` → no load → `PVThumbnail.Content.empty`.
2. **In-memory store** — process-lifetime map (`NSCache` or `@MainActor` dictionary) of path → decoded `Image` / `NSImage`. Bound count/cost so memory pressure evicts; a miss just reloads once.
   - **Hit:** return image immediately → `Content(image:)`.
   - **Miss in flight:** show `Content(loading: true)`; coalesce duplicate requests for the same key.
   - **Miss complete:** store result (including a “missing/failed” sentinel so we do not retry forever) and refresh observers.
3. **Async load on miss** — decode off the main thread (`Task.detached` / background queue), hop back to main, write cache, publish. Views observe via a small helper (`ThumbnailCache` / `CachedThumbnail` view + `task(id:)`).

The cache is **decoded images in RAM**, keyed by object path — **not** a second on-disk derivative. Files under `objects/…` remain the durable thumbnails.

### Call-site shape

```text
relPath empty?     → .empty
cache hit?         → .image
request in flight? → .loading
else               → start load, show .loading
```

One Platform helper shared by Source page header, artifact rows, and Sources list — same bug, same fix.

### Invalidation

Rare. Content-addressed `relPath` → same bytes. New ingest → new path → natural miss. Switching projects → clear cache or always key by `projectDir` so paths cannot collide.

## Suggested home

- `ProjectFiles` sibling or `ThumbnailCache` under `macos/App/Platform/`
- Thin view wrapper that feeds `PVThumbnail` so features do not reimplement hit/miss/loading

## Non-goals (for this parked idea)

- Go-side N+1 “ensure thumbnail” inside `GetSourceWorkspace` (separate core/FFI performance pass)
- Resizing / WebP / multi-resolution pipelines beyond what Go already writes
- Remote or network image loading (catalog is local files)

## Open questions

- `NSCache` vs explicit `@MainActor` dictionary + max count?
- Cache `NSImage` or SwiftUI `Image` (or both)?
- Should Sources list prefetch visible rows, or only load on first paint?
- Any need to observe file replacement at the same path (overwrite without new hash)?

## Ask when picking this up (on-disk layout)

**Reminder — do not silently “fix” storage; ask first.** In Finder, project `objects/…` entries look like nameless / extensionless content-addressed blobs rather than ordinary `something.jpg` files you can double-click and recognize. Expectation going in was regular image files. As part of this task, clarify how originals and thumbnails are stored on disk (why that shape, how Finder / Preview should treat them, whether human-friendly names or extensions belong later) before changing anything.