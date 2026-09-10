# Aggregate workspace nav counts RPC

**Status:** idea only — not roadmapped. Candidate follow-up once more sidebar destinations land (or sooner if workspace appear feels slow).

## Problem

The macOS workspace sidebar shows a count badge per destination. Initial load today walks sections **one FFI call at a time** (`listSources`, `listSourceTypes`, `listMetadataFields`, `countFiles`, …), because each catalog open takes an exclusive SQLite lock and concurrent opens fail.

`CatalogCounts` already unifies badge totals with vocabulary header splits (seeded / user / plugin) and lets feature models **publish** after create/delete without a recount. That does not fix appear-time cost: every new nav item adds another serial round trip.

## Idea

Add a single engine RPC, e.g. `GetWorkspaceNavCounts`, that opens the catalog **once** and returns every badge the sidebar needs — including origin breakdowns for vocabulary destinations:

```text
sources, files,
source_fields: { total, seeded, user, plugin },
source_types:  { total, seeded, user, plugin }
```

Implement with `COUNT(*)` / `GROUP BY origin` (not `list` + `.count` in Swift). Client `CatalogCounts.refreshAll()` becomes one call. New destinations extend that response and the SQL, not another macOS round trip.

Keep publish-on-mutate for Fields/Types (and later Sources) so create/delete still avoid a full refresh.

## Why later is fine for now

Spike 2 only has a handful of destinations; serial refresh is acceptable. The pattern matters when Interpretations, Places, Files detail, etc. join the rail.

## Open questions

- Proto shape: flat ints vs nested summary messages per vocabulary section?
- Should Sources eventually grow an origin (or other) split, or stay a single total?
- Refresh policy: always full RPC on workspace appear, or also on section switch for stale badges?

## Explicitly out of scope for this note

- Caching full row lists for destinations (counts only)
- Denormalized count tables (revisit only if `COUNT(*)` is too hot)
- Changing the exclusive-lock catalog model

## Related code / docs

- `macos/App/Features/Shared/CatalogCounts.swift`
- `docs/deployment-plan/spike-2/design/S2-01-workspace-chrome.md` (sidebar counts)
- Catalog exclusive lock notes in historical `WorkspaceModel.refreshCounts` / `CatalogCounts.refreshAll`
