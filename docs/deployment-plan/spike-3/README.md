# Spike 3 — Workspace layout (nav history + omnibar)

## Status

**Planning.** Workspace layout (nav history + omnibar chrome) plus first-class infrastructure: **catalog `project.uuid`**, hand-rolled navigation history, and **Go/SQLite catalog search** (registry + FTS5 + ranking; successive PRs).

Authoritative stack / chrome context: [`macos-client-patterns.md`](../../macos-client-patterns.md), [`application-stack.md`](../../application-stack.md). Spike 2 chrome brief (historical): [`S2-01-workspace-chrome.md`](../archive/spike-2/design/archive/S2-01-workspace-chrome.md).

**Design:** [`design/App Layout.dc.html`](design/App%20Layout.dc.html) — main-column toolbar with Back/Forward, breadcrumbs, and omnibar ([`design/README.md`](design/README.md)).

## Goal

First-class **Back/Forward** (persisted, coordinator-driven) and **project search** (toolbar omnibar + engine-side FTS/ranking), not band-aid chrome. Early-dev churn and broad file touch are acceptable; successive PRs should still be dogfoodable.

See [`navigation-history.md`](navigation-history.md) § Implementation posture and [`omnibar-search.md`](omnibar-search.md) § Implementation posture / Incremental delivery.

## Working notes (promoted from ideas)

| Note | One-liner |
| --- | --- |
| [Navigation history](navigation-history.md) | Browser-like Back/Forward; Application Support JSON keyed by `project.uuid`. |
| [Omnibar search](omnibar-search.md) | Toolbar `⌘K` search; registry + FTS5 + context ranking + fuzzy; removes per-destination list search. |

## Out of scope (for now)

- Interpretation / Conclusion catalog work
- Files list destination (descoped in Spike 2)
- Catalog access serialization / DB performance ([ideas parking lot](../../ideas/catalog-access-serialization.md))
- Short human project `ref` (unless a later spike needs one)
