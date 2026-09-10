# Deployment plan

Working notes for implementation milestones. These are stopping points, not a full product roadmap.

Authoritative domain and stack decisions remain in the sibling docs under [`docs/`](../). Unscheduled product ideas live in [`ideas/`](../ideas/) — a parking lot, not a spike queue.

## Current

| Spike | Goal |
| --- | --- |
| [Spike 2](spike-2/) | Validate the Source layer: app workspace chrome (sidebar), audit + schema + Go CRUD/ingest + FFI + macOS Source catalog UI (create Sources, Artifacts, Files, extensible types/metadata). Design steps in Claude Design interleaved with PRs. |

Spike 2 contents:

- [`spike-2/README.md`](spike-2/README.md) — open task list
- [`spike-2/completed.md`](spike-2/completed.md) — finished Spike 2 steps
- [`spike-2/design/`](spike-2/design/) — open Claude Design briefs; completed briefs in [`spike-2/design/archive/`](spike-2/design/archive/)

## Completed

| Spike | Goal |
| --- | --- |
| [Spike 1](archive/spike-1.md) | Scaffold the macOS app, local SQLite project, and first-run onboarding. **Retired the cgo SQLite + Swift dylib risk** (plan A: `mattn/go-sqlite3` inside `libprovenencia.dylib`). |

Older milestone notes live in [`archive/`](archive/).
