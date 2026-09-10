# Aggregate workspace nav counts RPC

**Status:** done — archived after `METHOD_GET_WORKSPACE_NAV_COUNTS` / `GetWorkspaceNavCounts`. `CatalogCounts.refreshAll()` uses one store call; Fields/Types still publish on mutate.

## Problem

The macOS workspace sidebar shows a count badge per destination. Initial load previously walked sections **one FFI call at a time** (`listSources`, `listSourceTypes`, `listMetadataFields`, `countFiles`, …), because each catalog open takes an exclusive SQLite lock and concurrent opens fail.

`CatalogCounts` already unifies badge totals with vocabulary header splits (seeded / user / plugin) and lets feature models **publish** after create/delete without a recount. That did not fix appear-time cost: every new nav item added another serial round trip.

## Solution

`GetWorkspaceNavCounts` opens the catalog **once** and returns every badge the sidebar needs — including origin breakdowns for vocabulary destinations:

```text
sources, files,
source_fields: { total, seeded, user, plugin },
source_types:  { total, seeded, user, plugin }
```

Implemented with `COUNT(*)` / `GROUP BY origin` (not `list` + `.count` in Swift). Client `CatalogCounts.refreshAll()` is one call. New destinations extend that response and the SQL, not another macOS round trip.

Publish-on-mutate for Fields/Types stays so create/delete still avoid a full refresh. The standalone `CountFiles` RPC remains for other callers.

## Explicitly out of scope (still)

- Caching full row lists for destinations (counts only)
- Denormalized count tables (revisit only if `COUNT(*)` is too hot)
- Changing the exclusive-lock catalog model
- Reactive refresh on every section switch
