# Ideas parking lot

Scratch space for product ideas that are **not** on the current deployment plan and should not be treated as commitments.

Use this folder when something useful pops up mid-work and would otherwise get lost. Capture enough context that a future reader understands the problem and the rough shape of a solution. Do **not** turn entries into spike tasks, schemas, or UI specs until they are deliberately pulled into a roadmap spike.

## Rules of thumb

- **Not authoritative.** Domain and stack decisions stay in the sibling docs under [`docs/`](../). Spikes live under [`deployment-plan/`](../deployment-plan/).
- **Not scheduled.** Listing an idea here does not put it on the current spike (or any spike).
- **Prefer one file per idea.** Keep the entry short; link out to model docs when the idea depends on an existing layer.
- **Rough is fine.** Bullets, open questions, and “maybe later” notes are enough.
- **Promote out.** When an idea is pulled into a deployment-plan spike, move the file into that spike folder and drop it from the index below.

## Index

| Idea | One-liner |
| --- | --- |
| [Share packages](share-packages.md) | One-button export of a Source (or later a canonical entity) as a readable, standards-friendly bundle for other researchers. |
| [Catalog access serialization](catalog-access-serialization.md) | PR1 done (Go session + serial queue); PR2 Mac lifecycle still open. |
| [File-type fallback thumbnails](file-type-fallback-thumbnails.md) | MIME glyphs + curated Source-type icons (fileless / cover) + Source primary Artifact thumbnail rollup. |
| [Ingest MIME enforcement](ingest-mime-enforcement.md) | Allowlist media types at ingest so Artifact Files stay evidence-shaped, not arbitrary blobs. |

## Completed

| Idea | One-liner |
| --- | --- |
| [Aggregate workspace nav counts](archive/aggregate-workspace-nav-counts.md) | `GetWorkspaceNavCounts` for sidebar badge counts (plus vocabulary origin splits) in one FFI open. |
| [Image optimization](archive/image-optimization.md) | Async in-memory thumbnail cache + MIME extensions on `objects/…` so Finder/Preview work. |

Completed ideas live in [`archive/`](archive/).
