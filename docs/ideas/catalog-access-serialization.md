# Catalog access serialization (and related DB interface performance)

**Status:** idea only — not roadmapped. Parked to join later with other catalog / FFI performance work.

## Problem

Each macOS catalog RPC opens the project SQLite file under an **exclusive** lock. Concurrent opens fail (busy / already open). That shows up as:

- Empty sidebar badges and empty destination lists on cold launch when nav-count refresh races the active view’s `load()`
- Risk of the same failure whenever two features (or refresh + mutate) hit the store at once

Today the workspace **gates** destination content until `CatalogCounts.refreshAll()` finishes (`WorkspaceView.isCatalogReady`). That fixes the known appear-time collision without putting bootstrap state on `CatalogCounts`. It does **not** make concurrent catalog access safe in general.

Related archived note: [`archive/aggregate-workspace-nav-counts.md`](archive/aggregate-workspace-nav-counts.md) (one FFI open for all nav badges). Explicitly out of scope there: changing the exclusive-lock catalog model.

## Idea

Treat exclusive catalog access as a **platform / store concern**, not something every feature model coordinates:

- Serialize (or carefully multiplex) catalog FFI opens in `GenealogyStore` / `GoStore` — e.g. an actor or serial executor so concurrent `async` callers queue instead of colliding
- Optionally keep a longer-lived catalog session in Go so “open → query → close” per RPC is not the only shape
- Retry/backoff on busy as a safety net, not the primary design

This belongs with a broader pass on **database interface performance**, not as a one-off UI fix.

## Bundle with other DB / FFI performance work

When revisiting the catalog interface, consider together:

| Theme | Notes |
| --- | --- |
| Access serialization | Queue concurrent opens; document the threading contract for Swift ↔ cgo |
| Session / connection lifetime | Held catalog handle vs open-per-RPC; WAL + busy timeout already exist — revisit pool size and close policy |
| Round-trip batching | Pattern of `GetWorkspaceNavCounts`: more “read what the shell needs in one open” RPCs where appear-time fans out |
| List + count coherence | Avoid double opens when a destination loads rows *and* wants a badge publish |
| Error surfacing | Failed opens should not be silent `try?` forever; busy vs real failure should be distinguishable to UI/tests |
| Measurement | Cheap instrumentation of open latency and busy rate under workspace navigation |

## Non-goals (for the idea as parked)

- Changing SQLite `STRICT` / migration / `user_version` rules
- Denormalized count tables (unless measurement says `COUNT(*)` is hot)
- Reactive “refresh everything on every section switch” without a store-level plan

## Open questions

- Serialize only in Swift (`GoStore`), only in Go (`openProjectCatalog`), or both?
- Is a multi-reader catalog ever acceptable, or is exclusive open load-bearing for audit / single-writer assumptions?
- How does this interact with ingest, derivatives, and future Windows clients sharing the same core?
