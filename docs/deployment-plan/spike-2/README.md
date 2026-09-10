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

Claude Design handoffs live in [`design/`](design/) — self-contained requirement briefs, not the task list below. Design sequence: **S2-04** Sources list → **S2-23** Source page → **S2-20** Files list (**S2-01…S2-03** done — [`design/archive/`](design/archive/), [`completed.md`](completed.md)).

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
S2-04 Design — Sources list (browse + Add Source → separate Source page)
S2-23 Design — Source page (Artifacts + File ingest)
S2-20 Design — Files list (project file browser)
        │
        ▼
S2-17 PR — Swift Sources list (+ Add Source; navigate to Source page)
S2-18 PR — Swift Source page (Artifacts + file ingest + list thumbnails)
S2-21 PR — Swift Files list (+ Source link)
S2-19 PR — Dogfood polish (copy, empty states, errors, tests)
```

Core schema / Go, workspace chrome, Source fields/types UI, and Design **S2-01…S2-03** are **done** — see [`completed.md`](completed.md) and [`design/archive/`](design/archive/). Remaining Design: **S2-04** → **S2-23** → **S2-20**. Remaining feature UI: **S2-17** → **S2-18** → **S2-21** → **S2-19**. Do not start a feature UI PR until its Design step has a reviewable board (or an explicit “design enough to code” note).

---

## Open steps

To-do queue for Spike 2. Finished Design/PR write-ups live in [`completed.md`](completed.md).

### S2-04 — Design: Sources list

**Claude Design brief:** [`design/S2-04-sources-list.md`](design/S2-04-sources-list.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done); S2-02 / S2-03 (types vocabulary for Add Source / row type name) |
| **Deliverables** | Board for the **Sources** list only: **list-style** rows (thumbnail + title + type/`SRC-…`) via a **new list component** — **not** `PVTable`; search; empty + **Add Source** as a **centered dimming dialog** (same family as confirm dialogs; type + **title** required; description optional) that on Create navigates to the **separate Source page**; row select also opens that page. Not master–detail like S2-02/S2-03. Do not design Artifacts or File ingest here. |
| **Context** | Source doc §4 (list-facing). Navigation locked: **separate page**. Create locked: **confirm-style dialog on the list**, then land on S2-23 (view/edit). Presentation locked: **evidence list**, not vocabulary table — `PVTable` remains fields/types only. |
| **Out** | Source page body, Artifacts, ingest (S2-23 / S2-18); delete; vocabulary admin. |
| **Feeds** | S2-17 |

---

### S2-23 — Design: Source page (Artifacts + Files)

**Claude Design brief:** [`design/S2-23-source-detail.md`](design/S2-23-source-detail.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done); S2-04 (list entry/exit); S2-02 / S2-03 (notes/metadata + type display) |
| **Deliverables** | Board for the **individual Source page** (view/edit only — no create/draft): identity + editable title/description; **Source credibility** (three-point grade + optional argument; Interpretation assessment, edited on this page); **Notes** and **Metadata** as distinct areas (Metadata: all values, dismissible quick-add suggestions, separate **Add** field picker, drag reorder); Artifacts list (**thumbnail of primary File** + `label` + `ART-…`) with **in-place accordion** expand (not a separate Artifact page); expanded row shows label/description + **one** primary File only (**no** derivatives list); activating the File **opens it in an external app** (MVP — no in-app preview); **Add Artifact** centered modal (same pattern as Add Source; label + optional File); **Add file…** only when fileless — **no Replace**. **Breadcrumb** to the Sources list (not a back button). |
| **Context** | Source doc §§4, 6–8; credibility: [`research-judgment-model.md`](../../research-judgment-model.md) §2. Design assumes Artifact **`label`**, per-Source **suggestion dismiss**, metadata **`sort_order`**, and **credibility grades/assessments** schema — S2-18 adds those first. Better scan = new Artifact (Citation remapping later). File **first-attach** only. File open MVP = default external app. Create lives on S2-04’s Add Source dialog. |
| **Out** | Redesigning the Sources list (S2-04); delete Sources/Artifacts/Files; **Replace file**; Citations / Observations / Nodes; Citation move-duplicate; Claim confidence; **in-app File preview**; vocabulary admin; project Files browser (S2-20). |
| **Feeds** | S2-18 |

---

### S2-20 — Design: Files list (project file browser)

**Claude Design brief:** [`design/S2-20-files-list.md`](design/S2-20-files-list.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done — **Files** placeholder already in shell); S2-23 (Source page link target) |
| **Deliverables** | Board for the **Files** destination: list rows with **thumbnail**, **media type**, **original filename**; **link to associated Source** (via Artifact). No ingest/delete on this board. Prefer not listing derivative-only Files as peer rows. |
| **Context** | Source doc §§6–8. Association is indirect (`artifacts.file_id` → Source). Sidebar Files destination already exists; only `CountFiles` is wired today. |
| **Out** | Ingest (S2-23/S2-18); delete; Interpretation. |
| **Feeds** | S2-21 |

---

### S2-17 — PR: Swift Sources list

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-04 (design enough), S2-16 (types available to pick), S2-13, S2-14 |
| **Deliverables** | **Sources** list destination: homogeneous **list** rows (thumbnail + title + type/`SRC-…`; thumbnail placeholder OK if S2-18 owns real thumbs) via a **new design-system list component** — **do not use `PVTable`**; **Add Source** centered dialog (reuse confirm-dialog chrome; type + **required** title + optional description) that on Create navigates to a **separate Source page** (stub/placeholder page OK until S2-18); row select opens that page. Unit tests with `FakeStore`. L10n via skill. |
| **Context** | Mount under S2-14 **Sources** pane. Match S2-04: **not** master–detail; create is confirm-style dialog → Source page; presentation is list-not-table. Do not ship full Artifact/File UI here. |
| **Out** | Source page body, Artifact detail, ingest, derivative/thumbnail ensure (S2-18). |

---

### S2-18 — PR: Swift Source page (Artifacts + file ingest + thumbnails)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-23 (design enough), S2-17, S2-13 (S2-12 done for generation) |
| **Deliverables** | **First (schema/FFI/docs):** (1) Artifact **`label`** (required); (2) per-Source **persistent dismiss** of type metadata suggestions; (3) **`sort_order`** (or equivalent) on Source metadata + reorder API; (4) **no primary-File replace** — `IngestArtifactFile` rejects when Artifact already has a File; (5) **Source credibility** — migrate `source_credibility_grades` + `source_credibility_assessments`, seed `provenencia` grades (`low_trust` / `standard` / `high_trust`), audited get/upsert assessment + list grades, include in Source workspace FFI (do **not** add a column on `sources`); update Source-layer docs for first-attach-only. Then **Source page** from the list: description; **credibility** control (grade + optional argument); **Notes** stream; **Metadata** area (all values; dismissible quick-add suggestions; separate **Add** → vocabulary picker → value → save; drag reorder); Artifacts list (**primary-File thumbnail** + `label` + `ART-…`); in-place Artifact expand (label/description; **primary File only** — do not list derivatives); activating the File **opens it in the default external app** (`NSWorkspace`) — **no** in-app preview; **Add Artifact** centered modal (same pattern as Add Source; required label + optional File ingest); **Add file…** on fileless Artifacts only via NSOpenPanel → `IngestArtifactFile` (path only) — **no Replace UI**. Surface thumbnails on Sources/Artifacts list rows (ensure or fetch derivative `rel_path`; Swift reads bytes). Include any thin FFI gap to list/ensure thumbnails for list cells. Tests for model state transitions with `FakeStore` (including ingest rejected when File already set; credibility upsert). Confirm file-access usage copy/entitlements. |
| **Context** | Association for **first attach** exists (`IngestArtifactFile` / `CreateArtifact`). Schema today lacks `artifacts.label`, suggestion dismiss, `source_metadata` display order, and credibility tables — add those in this PR before UI. Tighten ingest so it cannot pointer-swap. Do not invent multi-primary-file attach. Stack: Swift must not write `objects/` itself. Breadcrumb to Sources list per S2-23. File open MVP = external app. Credibility semantics: [`research-judgment-model.md`](../../research-judgment-model.md) §2. |
| **Out** | Vocabulary admin; delete primary Files; **Replace file**; Citations / Observations / Nodes; Citation move/duplicate; Claim confidence; **in-app File preview**; project-wide Files browser (S2-21). |

---

### S2-21 — PR: Swift Files list (+ Source link)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-20 (design enough), S2-18 (Source page navigation target; thumbnail wiring preferred), S2-17 (prefer reusing the Sources **list** component), S2-13, S2-14 |
| **Deliverables** | **Files** destination: list thumbnail, media type, original filename via the **list-style** component from S2-17 (not `PVTable`); Source link navigates into the Sources **Source page**. Add `ListFiles` (or equivalent) FFI joining current Artifact→Source when present; exclude derivative-only rows from the peer list. Unit tests with `FakeStore`. L10n via skill. |
| **Context** | Mount under existing S2-14 **Files** pane. Share thumbnail ensure/list helpers with S2-18 where practical. |
| **Out** | Ingest UI; File delete/GC. |

---

### S2-19 — PR: Dogfood polish and regression net

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-14, S2-15, S2-22, S2-16, S2-17, S2-18, S2-21 |
| **Deliverables** | Empty/error copy pass; accessibility identifiers for workspace nav + Source flows; Go+Swift test gaps closed for happy paths and one failure each (duplicate type key, ingest missing file, audit present after create). Update [`deployment-plan/README.md`](../README.md) when archiving this spike. Optional: short “how to dogfood Source catalog” note in README or spike retro. |
| **Out** | Product SemVer bump only if cutting a release ([`versioning.md`](../../versioning.md)). |

---

## Suggested PR titles (why-focused)

| Step | Title sketch |
| --- | --- |
| S2-17 | Add a Sources list inside the app workspace |
| S2-18 | Open a Source page with Artifacts, ingest, thumbnails, and Source credibility |
| S2-21 | Browse project Files and jump to their Source |
| S2-19 | Harden the Source catalog for first dogfood |

---

## Parallelism and team split

| Track | Steps |
| --- | --- |
| **Design (Claude Design)** | S2-01…S2-03 done; remaining **S2-04** → **S2-23** → **S2-20** |
| **Core schema / Go** | S2-05…S2-13 — done ([`completed.md`](completed.md)) |
| **FFI + Mac** | S2-14…S2-16 / S2-22 — done; remaining **S2-17** → **S2-18** → **S2-21** → **S2-19** |

Prefer **many small PRs**. Sources list (S2-17) ships a **new list-style component** (not `PVTable`); Source page + Artifact ingest + thumbnails (S2-18); then project Files browser (S2-21 — prefer reusing the Sources list component). Do not fold the workspace shell into feature destination PRs.

---

## Explicit non-goals checklist (keep PRs honest)

- [ ] No Citation / Observation / Node tables or RPCs (sidebar stubs only) — **except** Source credibility grades/assessments shipped with S2-18 for the Source page
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
