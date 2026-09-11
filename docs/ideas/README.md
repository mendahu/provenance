# Ideas parking lot

Scratch space for product ideas that are **not** on the current deployment plan and should not be treated as commitments.

Use this folder when something useful pops up mid-work and would otherwise get lost. Capture enough context that a future reader understands the problem and the rough shape of a solution. Do **not** turn entries into spike tasks, schemas, or UI specs until they are deliberately pulled into a roadmap spike.

## Rules of thumb

- **Not authoritative.** Domain and stack decisions stay in the sibling docs under [`docs/`](../). Spikes live under [`deployment-plan/`](../deployment-plan/).
- **Not scheduled.** Listing an idea here does not put it on Spike 2 (or any spike).
- **Prefer one file per idea.** Keep the entry short; link out to model docs when the idea depends on an existing layer.
- **Rough is fine.** Bullets, open questions, and “maybe later” notes are enough.

## Index

| Idea | One-liner |
| --- | --- |
| [Share packages](share-packages.md) | One-button export of a Source (or later a canonical entity) as a readable, standards-friendly bundle for other researchers. |
| [Omnibar search](omnibar-search.md) | Project-scoped top search across Sources, vocabulary, Files, and later Interpretation/Conclusion — jump by typing instead of sidebar hunting. |
| [Navigation history](navigation-history.md) | Browser-like Back/Forward through workspace views (sidebar + deep links), distinct from in-page “up to list.” |
| [Catalog access serialization](catalog-access-serialization.md) | Serialize exclusive catalog opens (and related DB/FFI performance) so concurrent RPCs queue instead of failing — beyond the workspace appear-time gate. |
| [Image optimization](image-optimization.md) | Async in-memory thumbnail cache so SwiftUI stops sync-decoding `objects/…` thumbs on every render. |

## Completed

| Idea | One-liner |
| --- | --- |
| [Aggregate workspace nav counts](archive/aggregate-workspace-nav-counts.md) | `GetWorkspaceNavCounts` for sidebar badge counts (plus vocabulary origin splits) in one FFI open. |

Completed ideas live in [`archive/`](archive/).
