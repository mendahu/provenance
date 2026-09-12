# Catalog access serialization (and related DB interface performance)

**Status:** PR1 landed in Go (`core/catalogsession` + all catalog FFI handlers). Mac workspace open/close lifecycle and dropping `isCatalogReady` remain **PR2**. Not part of Spike 3. Related: [`archive/aggregate-workspace-nav-counts.md`](archive/aggregate-workspace-nav-counts.md).

## Problem

### What happens today (pre-session / Mac until PR2)

Every catalog FFI handler **used to** do **open → work → close**:

```text
Swift feature  →  GoStore.provenenciaCall (Task.detached, parallel-friendly)
                 →  openProjectCatalog → database.Open
                      PRAGMA locking_mode=EXCLUSIVE + BEGIN IMMEDIATE
                 →  query / mutate
                 →  defer Close()
```

The catalog is an **exclusive** connection (`MaxOpenConns=1`, WAL, `busy_timeout` 100ms). A second open while the first is held fails as `catalog.already_open` (busy/locked), not “wait your turn.”

Swift does **not** serialize store calls. Feature models independently `async` load, refresh badges, mutate, ensure thumbs, etc. They collide.

### What researchers / dogfood already see

- Cold launch: nav-count refresh raced destination `load()` → empty badges and/or empty lists
- Workspace **gates** content until `CatalogCounts.refreshAll()` finishes (`WorkspaceView.isCatalogReady`) — a **UI coordination band-aid** for one race, not a general fix
- Any later overlap (section switch + counts publish, two panes, refresh + save, omnibar search + list load, …) can hit the same wall
- Failures are often soft (`try?` on counts; partial loads) → silent empties instead of a clear “catalog busy”

### Product smell

Feature authors should be able to say “load my Sources” / “refresh badges” / “save this note” **without** knowing who else is talking to SQLite. Concurrency of catalog access is a **platform concern**. Today every screen is one more accidental participant in a locking protocol.

### Performance worry (maybe we’re doing this wrong)

Even when calls don’t collide, **open-per-RPC is heavy**:

- Exclusive lock + immediate transaction setup/teardown on **every** small read
- Appear-time and navigation fan out into many opens (partially mitigated by `GetWorkspaceNavCounts`, still open-per-call elsewhere)
- cgo + SQLite open cost dominates tiny `SELECT`s
- Feels cumbersome and slow for a local desktop app with one user and one project

The exclusive **single-writer** rule for the *project directory* (no second Provenencia process) is still right. Burning that into **open-per-FFI-call with fail-fast busy** may be the wrong *in-process* shape.

## Goal

1. **Feature models ask freely** — concurrent `async` store use queues on the session; they do not coordinate locks or appear-order gates for correctness.
2. **One clear access manager** — held session + serial ops live in the Go catalog / FFI layer (optional Swift façade), documented as the threading contract.
3. **Amortize open** — exclusive catalog open once per workspace life, not per RPC.
4. **Honest errors** — real failures visible; `already_open` becomes a bug signal (something bypassed the session), not normal UX.

Appear-time gating can shrink or go away once (1) holds.

## Implementation posture (first-class, not a band-aid)

Early product: **prefer correct catalog access infrastructure over minimal diff.** This is how every screen, search, ingest, and future Windows client will talk to the project DB. A narrow “queue opens in GoStore only” or “leave `isCatalogReady` forever” half-measure is not enough.

- **Wide surgery is expected** — Rework FFI handlers off open-per-call, introduce an explicit session lifecycle (open with workspace / close on switch), thread a serial queue through catalog use, update FakeStore / tests, and delete appear-time coordination that only existed to paper over races. Touching many files is fine.
- **Features stay dumb** — Models keep calling `list*` / `get*` / mutate APIs; they must not grow lock ordering or “wait for counts” protocols for correctness.
- **Go owns the contract** — Session + serialization in core/FFI so Mac and later Windows share one model; don’t strand the fix in Swift-only glue.
- **No parallel access paths** — Ingest, derivatives, search, and list all use the same session doorway. A leftover `openProjectCatalog` per handler that bypasses the session is a bug.
- **Tests** — Concurrent overlapping store calls must not yield `already_open` / empty UI; project switch closes the session; FakeStore remains usable without real locking.
- **Churn now is cheaper** than retrofitting a session under omnibar, nav restore, and every new destination later.

## Intended minimum: A + B (locked preference)

**Do both:** hold an exclusive catalog **session** for the workspace lifetime (**B**), and **serialize operations** on that session (**A**, primarily in Go).

Product fit: one researcher, one app, one open project — **locking the DB while the workspace is open is fine.** No multi-user catalog access. External tools can wait until the project is closed / app leaves the workspace (same single-writer rule as today, just held longer).

```text
Enter workspace  →  session.Open (exclusive, once)
Feature awaits   →  queue → run one RPC’s work on the session → next waiter
Leave / switch   →  session.Close
```

### What this does *not* mean

**Not** concurrent Go queries on SQLite. With one exclusive connection, work is still **one catalog operation at a time** (one RPC’s transaction / statement batch completing before the next starts). Parallelism is only on the Swift side: many `async` calls may be *in flight*, but they **wait in line** for the session. That is the point — features don’t coordinate; the platform queues.

So:

| Layer | Concurrent? |
| --- | --- |
| Swift feature `async` calls | Yes — fire whenever |
| Catalog session ops in Go | **No** — mutex / serial queue |
| SQLite connection | **One at a time** |

If we ever want true overlapping reads, that would be a separate **B3**-style multi-connection design — **out of scope** for this minimum. A+B is “safe + amortize open,” not “parallel query engine.”

### A and B roles together

| Piece | Role |
| --- | --- |
| **B session** | Open once; don’t pay exclusive open per List/Get; hold lock for workspace life |
| **A serialize** | Don’t interleave two RPCs on that handle; replace fail-fast `already_open` with waiting |

Swift-side serialization (**A1**) is optional if every path goes through the Go session API; **Go-side queue on the session (A2)** is the load-bearing half.

## Direction A — Serialize access (queue, don’t race)

Treat exclusive access as a **queue**, not a race.

| Approach | Where | Pros | Cons |
| --- | --- | --- | --- |
| **A1. Swift serial executor / actor** on `GoStore` | Mac client | Features stay dumb; FakeStore tests easy | Only this process’s Swift callers; Windows reimplements; weaker if anything bypasses GoStore |
| **A2. Go mutex / serial queue on the catalog session** | Core | All FFI clients; one contract | Must wrap all session ops |
| **A3. Both** | Swift + Go | Defense in depth | Slight redundancy |

With **B**, prefer **A2** (or A3). Retry/backoff on `already_open` is a **safety net** for bugs (something still calling `Open` twice), not the primary design.

Contract: “at most one exclusive catalog session per projectDir in this process; session ops run one at a time; waiters queue.”

## Direction B — Longer-lived catalog session

Keep the catalog **open for the workspace lifetime** (or until project switch / sign-out), and run RPCs against a held handle.

```text
Open project / enter workspace
  → session.Open(projectDir)   // exclusive once
  → many Search / List / Mutate on session (serialized)
  → session.Close() on leave
```

| Pros | Cons |
| --- | --- |
| Amortizes exclusive open; small reads get cheap | Need session API, invalidation on switch, careful Close |
| Natural place for the in-process serial queue | FFI must not assume open-per-call forever |
| Fits “one window, one project” MVP | Multi-window later: share one session per projectDir or refuse |
| Aligns with single-writer product rule | DB locked for the whole session (acceptable — see intended minimum) |

Variants:

- **B1. Held `*database.Catalog` in Go** keyed by projectDir, refcounted by “workspace open” — **preferred shape for A+B**
- **B2. Tiny pool still MaxOpenConns=1** but don’t tear down between RPCs (session is the pool)
- **B3. Read path with shared/WAL readers** — overlapping reads; **not** part of the A+B minimum

**A+B** is closer to how a desktop app should talk to local SQLite than open-exclusive-every-ListSources.

## Direction C — Fewer / richer RPCs (batching) — deferred

Even with a session, chatty UI × many round trips *can* hurt (especially through cgo). Patterns like `GetWorkspaceNavCounts` remain valid **when a feature clearly needs them**.

**Not part of this catalog-access job.** Prefer **A+B** (held session + serial queue) so many small RPCs are cheap and safe enough that we **don’t have to** invent batch APIs up front. If a specific screen still feels chatty after A+B, consider a richer RPC **for that feature only** — opportunistic, not a platform workstream bundled here.

| Pattern | When (later, per feature) |
| --- | --- |
| Shell bootstrap | Only if appear-time still fans out too hard after session |
| Destination load + badge | Only if double-fetch stays visibly slow |
| Search one-shot | Owned by omnibar / search design, not this note |

Batching is optional polish after measurement — **not** a prerequisite for fixing races or open-per-RPC cost.

## Direction D — What not to do

- **Scatter `isCatalogReady`-style gates** on every feature — pushes locking into UI
- **Silent `try?`** on catalog open as product behavior
- **Denormalized count tables** until measurement says `COUNT(*)` is hot
- **Multi-process multi-writer** — out of scope; refuse second app instance remains fine
- **Swift opening SQLite directly** — breaks shared-core story

## Exploring “are we wrong?”

Likely **right:**

- SQLite in the project package, Go owns the schema
- One live writer per project directory
- Swift never opens the file

Likely **worth changing:**

- Fail-fast exclusive open **per RPC** as the only in-process model
- Expecting feature models to not overlap awaits
- 100ms busy timeout as a substitute for a queue (too short to wait, long enough to feel stuck, then error)

**Mental model to aim for:**

```text
Feature code:  await store.listSources(...)   // fire whenever (may overlap)
Platform:      held session + serial queue     // one op at a time
SQLite:        one exclusive connection for this project while workspace is open
```

## Suggested delivery (when scheduled)

One *job*, **two reviewable PRs** (optional third). Not one mega-PR, and not a long series that leaves mixed open-per-call vs session handlers.

| PR | Delivers | Leaves the tree… |
| --- | --- | --- |
| **1 — Go session + serial queue + all handlers** | **Done:** held catalog session (`core/catalogsession`); Go mutex/serial queue; every catalog FFI path uses the session; `METHOD_CLOSE_CATALOG_SESSION`; SignOut / RemoveActiveProject / OpenProject close sessions; Go tests for overlapping calls and close/switch | Core is correct and open is amortized; Mac still binds session lifetime awkwardly (open on first RPC / close on sign-out) until PR 2 |
| **2 — Mac lifecycle** | Explicit session open/close on workspace enter/leave and project switch; `GenealogyStore` / FakeStore wired; drop or narrow `isCatalogReady` | Features can overlap `async` store calls end-to-end without UI lock gates |
| **3 (optional)** | Hardening: concurrent Swift tests, clearer errors if anything bypasses the session, stack/client-pattern doc updates | Polish |

**Do not** split PR 1 into “half the handlers” unless a single doorway *forbids* non-session opens — a hybrid open-per-call + session world is worse than today’s races.

**Do not** ship “serialize opens only” as the lasting architecture if A+B is the locked minimum. A short-lived queue-around-`Open` on a branch is fine only as a stepping stone toward the session, not the end state.

After A+B is live: **measure** queue wait vs query time. **Direction C** batching and **B3** multi-reader stay deferred (see Non-goals).

## Open questions

- Session keyed by `projectDir` string vs future `project.uuid`?
- Multi-window: one shared session per project, or one window until later?
- Optional A1 Swift façade on top of A2+B, or Go session API alone?
- How does workspace “session open” bind to onboarding → home → workspace lifecycle (exact FFI: explicit OpenCatalogSession vs implicit on first RPC)?

## Non-goals (while parked)

- Concurrent / overlapping SQLite queries (B3) as part of the A+B minimum
- **Bundling Direction C (richer/batch RPCs)** into this job — defer; feature-by-feature only if A+B isn’t enough
- Spike 3 depending on this landing first (note collision risk until it does)
- Changing `STRICT` / migrations / `user_version` for performance
- Multi-user or multi-process writers on one catalog

## Related docs

- [`application-stack.md`](../application-stack.md) §10 / §12 (WAL, pool, single writer)
- [`archive/aggregate-workspace-nav-counts.md`](archive/aggregate-workspace-nav-counts.md)
- [`macos-client-patterns.md`](../macos-client-patterns.md) (`GenealogyStore` / FakeStore)
- Spike 3 omnibar will add more concurrent catalog traffic — strengthens the case for scheduling this nearby
