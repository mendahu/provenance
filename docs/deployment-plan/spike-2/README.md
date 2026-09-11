# Spike 2 — Source layer catalog (schema, CRUD, ingest UI)

## Status

**Current.** Planning notes for the next implementation sprint: validate the Source-layer model end-to-end (tables → Go CRUD/ingest → FFI → macOS catalog UI), with design work in Claude Design interleaved where the UX is non-trivial.

Authoritative models:

- [`source-layer-data-model.md`](../../source-layer-data-model.md)
- [`artifact-file-storage.md`](../../artifact-file-storage.md) (pointer → Source layer)
- [`seeded-vocabulary.md`](../../seeded-vocabulary.md) §2
- [`audit-revision-history.md`](../../audit-revision-history.md)
- [`structured-date-model.md`](../../structured-date-model.md)
- [`catalog-refs.md`](../../catalog-refs.md)
- [`application-stack.md`](../../application-stack.md) (FFI granularity, `objects/` ingest)
- [`macos-client-patterns.md`](../../macos-client-patterns.md)

Claude Design handoffs live in [`design/`](design/) — self-contained requirement briefs, not the task list below. Remaining Design: **S2-20** Files list (**S2-01…S2-04** / **S2-23** done — [`design/archive/`](design/archive/), [`completed.md`](completed.md)).

Spike 1 left an explicit gate: **the first researched mutation must write audit**, not decorative empty tables without a write path. This spike owns that gate.

---

## Goal

A signed-in researcher can, in a real `*.provenencia` project:

1. Work inside an **app workspace** (sidebar + content) instead of a one-screen onboarding home forever.
2. Create a Source (type, title, description, notes, descriptive metadata).
3. Extend the project’s Source types and metadata fields when the seeded set is not enough.
4. Add Artifacts under a Source (including fileless / physical-only placeholders).
5. Ingest a local file into content-addressed `objects/`, attach it as an Artifact’s primary File, and see enough UI to verify the model (list, detail, metadata, type extension).

That is enough to **validate** the Source-layer schema and storage rules before Interpretation work begins.

```text
Onboarding (Spike 1) → signed in
  → App workspace (sidebar + content)
       ├── Sources (list → separate Source page)
       │     ├── type + title + notes + metadata
       │     ├── extend types / fields (project-local)
       │     └── Artifacts
       │           ├── fileless placeholder
       │           └── ingest File → objects/{hh}/{hh}/{sha256} → Artifact.file_id
       ├── Source types / Source fields (vocabulary admin)
       ├── Files (project file list → jump to Source)
       └── Project / session (sign out, project label, contributor)
```

---

## In scope

- **App workspace chrome**: side navigation + content host. Spike 2 destinations: **Sources**, **Source types**, **Source fields**, **Files** (no “coming soon” stubs for later layers).
- Audit write path (`audit_transactions` / `audit_changes`) used by every Source-layer mutation.
- Shared `date_values` table (schema + minimal Go helpers) so date-typed Source metadata can land without a second migration later.
- Full Source-layer table set from the Source doc: `source_types`, `sources`, `source_notes`, `source_metadata_fields`, `source_type_metadata_fields`, `source_metadata`, `artifacts`, `files`, `file_derivatives`.
- Small **seed** of types/fields (not the entire [`seeded-vocabulary.md`](../../seeded-vocabulary.md) horizon list). Create-time starter today: `birth_certificate` plus a few suggested fields; opens do not heal or expand the set.
- Go domain packages for CRUD + ingest; FFI use-cases (coarse verbs); SwiftUI Source catalog UI inside the workspace, consuming `GenealogyStore`.
- Claude Design boards for workspace chrome, Source fields, Source types, Sources list, Source page (Source → Artifact → File), and the Files list.
- Refs: mint `SRC-…` / `ART-…` via `core/ref` on insert ([`catalog-refs.md`](../../catalog-refs.md)).

## Out of scope (later spikes)

- Interpretation beyond Source credibility on the Source page (Citations, Observations, Nodes) and Conclusion — do not add sidebar placeholders for them in this spike.
- Claim confidence and Citation transcription certainty ([`research-judgment-model.md`](../../research-judgment-model.md)).
- Full GEDCOM / import adapters.
- Destructive primary File deletion; orphan GC of historically referenced Files.
- Rich audit UI / timeline browser (writes must exist; browsing history can wait).
- Open/create project flows beyond what Spike 1 already shipped (“continue as / that’s not me” polish is a separate spike unless it blocks dogfood).
- Windows client, sync, cloud accounts, notarization.
- Shipping the entire seeded vocabulary catalog on day one.

---

## Non-negotiable constraints (from docs)

1. **Audit atomicity** — domain write + audit revision in one SQLite transaction ([`audit-revision-history.md`](../../audit-revision-history.md) §5).
2. **No `created_at` / `updated_by` on Source tables** — attribution lives in audit.
3. **File bytes never travel over protobuf** — ingest use-case; read path returns relative `objects/…` path; Swift reads bytes ([`application-stack.md`](../../application-stack.md)).
4. **Content-addressed immutability** — `objects/{hh}/{hh}/{full hex}`; File bytes never change in place. Better/clearer scan = **new Artifact** (not pointer-swap under an existing `ART-…`; Citations locate into Artifacts).
5. **Derivatives belong to Files**, not Artifacts; generation need not audit.
6. **Swift stays thin** — Go owns schema, ingest, validation; models + `FakeStore` for tests.
7. **Seed small; grow from use** ([`seeded-vocabulary.md`](../../seeded-vocabulary.md) §1).

---

## Definition of done

Jake can, on his MacBook, without a server:

1. Finish Spike 1 onboarding and land in an **app workspace** with a sidebar (not the old single “you’re signed in” home as the permanent shell).
2. Use the sidebar to open Sources, Source types, Source fields, and Files.
3. Create a Source of a seeded type, edit title/description, add a note, set text (and at least one date) metadata fields suggested for that type.
4. Add a custom Source type and/or metadata field (from their nav destinations) and use them on a Source.
5. Add a fileless Artifact and an Artifact with an ingested image/PDF; confirm `files` row + bytes under `objects/`.
6. Inspect `provenencia.sqlite`: Source-layer rows present; audit revisions recorded for creates/updates; `SRC-…` / `ART-…` refs present.
7. Relaunch: workspace returns; catalog still lists the Sources; File still opens from the relative path.

---

## Step numbering

Steps are **`S2-NN`** (Spike 2, two-digit sequence). Each step has a **kind**:

| Kind | Meaning |
| --- | --- |
| **Design** | Claude Design (and/or local UX writing). No product code required to “complete,” but outputs feed later PRs. |
| **PR** | Mergeable change on `main`; leave the app buildable. |
| **Doc** | Docs/rules/skills only when a decision must land before code. |

IDs stay stable even if order of *starting* work shifts; **Depends on** is the merge/start gate. When a step finishes, move its write-up to [`completed.md`](completed.md) and leave a short pointer here only if something still depends on reading it.

---

## Dependency sketch

Open work only (completed steps: [`completed.md`](completed.md)):

```text
S2-20 Design — Files list (project file browser)
        │
S2-24 PR — Source page schema precede (label, first-attach, credibility)
        │
        ▼
S2-18 PR — Source page shell + Artifacts + ingest
        ├── S2-25 PR — Source metadata editor (suggestions / dismiss / reorder)
        └── S2-26 PR — Evidence list thumbnails (Sources + Artifacts)
                │
                ▼
S2-21 PR — Swift Files list (+ Source link)
S2-19 PR — Dogfood polish (copy, empty states, errors, tests)
```

Core schema / Go, workspace chrome, Source fields/types UI, Sources list (S2-17), and Design **S2-01…S2-04** / **S2-23** are **done** — see [`completed.md`](completed.md) and [`design/archive/`](design/archive/). Remaining Design: **S2-20**. Remaining feature UI: **S2-24** → **S2-18**, then **S2-25** / **S2-26** (can parallel after S2-18), then **S2-21** → **S2-19**. Do not start a feature UI PR until its Design step has a reviewable board (or an explicit “design enough to code” note).

---

## Open steps

To-do queue for Spike 2. Finished Design/PR write-ups live in [`completed.md`](completed.md).

### S2-20 — Design: Files list (project file browser)

**Claude Design brief:** [`design/S2-20-files-list.md`](design/S2-20-files-list.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done — **Files** placeholder already in shell); S2-23 (done — Source page link target) |
| **Deliverables** | Board for the **Files** destination: list rows with **thumbnail**, **media type**, **original filename**; **link to associated Source** (via Artifact). No ingest/delete on this board. Prefer not listing derivative-only Files as peer rows. |
| **Context** | Source doc §§6–8. Association is indirect (`artifacts.file_id` → Source). Sidebar Files destination already exists; only `CountFiles` is wired today. |
| **Out** | Ingest (S2-18); delete; Interpretation. |
| **Feeds** | S2-21 |

---

### S2-24 — PR: Source page schema precede (label, first-attach, credibility)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-23 (done), S2-13 |
| **Deliverables** | **Engine/docs only (no Source page UI):** (1) Artifact **`label`** column (required) — migration + query/proto/FFI create/update/get/list; (2) **first-attach only** — `IngestArtifactFile` rejects when Artifact already has a File; align [`source-layer-data-model.md`](../../source-layer-data-model.md); (3) **Source credibility** — migrate `source_credibility_grades` + `source_credibility_assessments`, seed `provenencia` grades (`low_trust` / `standard` / `high_trust`), audited get/upsert assessment + list grades, expose on Source workspace FFI (do **not** add a column on `sources`). Go + `FakeStore`/protocol stubs + tests. |
| **Context** | Unblocks S2-18 UI. Credibility semantics: [`research-judgment-model.md`](../../research-judgment-model.md) §2. Keep this PR free of Swift feature UI and free of metadata dismiss/reorder schema (S2-25). |
| **Out** | Source page SwiftUI; metadata suggestion dismiss / `sort_order`; thumbnail ensure/list; Files browser. |
| **Feeds** | S2-18 |

---

### S2-18 — PR: Source page shell + Artifacts + ingest

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-24, S2-17 (done), S2-23 (done) |
| **Deliverables** | Replace the S2-17 Source page stub: **breadcrumb** to Sources list; editable identity (**title**, type, **description**); **Notes** stream (add/edit/delete); **credibility** control (grade + optional argument); **Artifacts** in-place accordion (`label` + `ART-…` + thumbnail **placeholder** OK); expand shows label/description + primary File identity; **Open** via `NSWorkspace` (external app); **Add Artifact** centered modal (same as Add Source: required label + optional File); **Add file…** on fileless only — **no Replace**. DS as needed: `PVBreadcrumbs`, disclosure/expandable list, file-pick control. `FakeStore` model tests; file-access usage copy/entitlements. |
| **Context** | Thin vertical slice of S2-23: page + Artifacts + ingest path. Defer rich Metadata editor (S2-25) and real list thumbnails (S2-26). Do not invent multi-primary-file attach. Swift must not write `objects/` itself. |
| **Out** | Metadata suggestions / dismiss / drag reorder (S2-25); derivative thumbnail ensure/list UI (S2-26); in-app File preview; Replace file; Citations / Observations / Nodes; project Files browser (S2-21). |
| **Feeds** | S2-25, S2-26, S2-21 |

---

### S2-25 — PR: Source metadata editor (suggestions, dismiss, reorder)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-18, S2-23 (done) |
| **Deliverables** | **Schema/FFI:** per-Source **persistent dismiss** of type metadata suggestions; **`sort_order`** (or equivalent) on `source_metadata` + reorder API. **UI** on the Source page Metadata area: all associated values; type suggestions as quick-add (in-place value + save) with dismiss (X); separate **Add** → vocabulary picker → value → save; **drag reorder**. Reorderable-row DS if not already present. `FakeStore` tests. |
| **Context** | Completes the Metadata half of S2-23. Keep Notes/Artifacts/credibility out of this PR unless a tiny glue change is required. |
| **Out** | Thumbnail wiring (S2-26); vocabulary admin; Claim confidence. |

---

### S2-26 — PR: Evidence list thumbnails (Sources + Artifacts)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-18 (preferred — Artifact rows exist), S2-17 (done — Sources `PVList`), S2-12/S2-13 (derivative pipeline) |
| **Deliverables** | FFI/helpers to **ensure or list** thumbnail derivative `rel_path` for list cells; Swift reads bytes from `objects/…` and fills `PVThumbnail` on **Sources** list rows and **Artifact** rows on the Source page. Missing/fileless → placeholder (not error). Tests for ensure/list happy path + skip. |
| **Context** | Shared wiring S2-21 will reuse. Can land in parallel with S2-25 after S2-18. |
| **Out** | In-app File preview; Files destination UI (S2-21); ingest UX changes. |
| **Feeds** | S2-21 |

---

### S2-21 — PR: Swift Files list (+ Source link)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-20 (design enough), S2-18 (Source page navigation target), S2-26 (thumbnail wiring preferred), S2-17 (done — prefer reusing `PVList`), S2-13, S2-14 |
| **Deliverables** | **Files** destination: list thumbnail, media type, original filename via the **list-style** component from S2-17 (not `PVTable`); Source link navigates into the Sources **Source page**. Add `ListFiles` (or equivalent) FFI joining current Artifact→Source when present; exclude derivative-only rows from the peer list. Unit tests with `FakeStore`. L10n via skill. |
| **Context** | Mount under existing S2-14 **Files** pane. Prefer sharing thumbnail helpers from S2-26. |
| **Out** | Ingest UI; File delete/GC. |

---

### S2-19 — PR: Dogfood polish and regression net

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-14, S2-15, S2-22, S2-16, S2-17, S2-24, S2-18, S2-25, S2-26, S2-21 |
| **Deliverables** | Empty/error copy pass; accessibility identifiers for workspace nav + Source flows; Go+Swift test gaps closed for happy paths and one failure each (duplicate type key, ingest missing file, audit present after create). Update [`deployment-plan/README.md`](../README.md) when archiving this spike. Optional: short “how to dogfood Source catalog” note in README or spike retro. |
| **Out** | Product SemVer bump only if cutting a release ([`versioning.md`](../../versioning.md)). |

---

## Suggested PR titles (why-focused)

| Step | Title sketch |
| --- | --- |
| S2-24 | Add Artifact labels, first-attach ingest, and Source credibility schema |
| S2-18 | Open a Source page with Notes, credibility, and Artifact ingest |
| S2-25 | Edit Source metadata with dismissible suggestions and reorder |
| S2-26 | Show real thumbnails on Sources and Artifact lists |
| S2-21 | Browse project Files and jump to their Source |
| S2-19 | Harden the Source catalog for first dogfood |

---

## Parallelism and team split

| Track | Steps |
| --- | --- |
| **Design (Claude Design)** | S2-01…S2-04 / S2-23 done; remaining **S2-20** |
| **Core schema / Go** | S2-05…S2-13 — done ([`completed.md`](completed.md)); **S2-24** (and S2-25 schema) reopen thin migrations |
| **FFI + Mac** | S2-14…S2-17 / S2-22 — done; remaining **S2-24** → **S2-18**, then **S2-25** ∥ **S2-26** → **S2-21** → **S2-19** |

Prefer **many small PRs**. Do not recombine S2-24…S2-26 into one Source-page mega-PR. Do not fold the workspace shell into feature destination PRs.

---

## Explicit non-goals checklist (keep PRs honest)

- [ ] No Citation / Observation / Node tables or RPCs (sidebar stubs only) — **except** Source credibility grades/assessments shipped with **S2-24** / UI in **S2-18**
- [ ] No Claim confidence UI
- [ ] No File bytes in protobuf
- [ ] No deletion of primary Files
- [ ] No full vocabulary dump from `seeded-vocabulary.md` (credibility grades seed is the three-point set only)
- [ ] No audit history browser required for done

---

## After Spike 2

Likely next spikes (not scheduled here):

1. Fill sidebar destinations beyond Sources / types / fields / Files (Interpretation entry, Settings) when those features exist.
2. Audit history UI / “what changed” for a Source.
3. Citation → Observation → Node (Interpretation) on top of Artifacts.
4. Project open/create UX polish beyond Spike 1 onboarding.
5. Richer date entry and more seeded types driven by real cataloging sessions.
