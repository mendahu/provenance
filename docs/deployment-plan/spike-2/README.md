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

Claude Design handoffs live in [`design/`](design/) — self-contained requirement briefs, not the task list below. Design sequence: **S2-02** Source fields → **S2-03** Source types → **S2-04** Sources list → **S2-23** Source page → **S2-20** Files list (**S2-01** chrome done).

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

- Interpretation (Citations, Observations, Nodes) and Conclusion — do not add sidebar placeholders for them in this spike.
- Source **credibility** assessments ([`research-judgment-model.md`](../../research-judgment-model.md)).
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
4. **Content-addressed immutability** — `objects/{hh}/{hh}/{full hex}`; replace scan = new File + Artifact pointer update.
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

IDs stay stable even if order of *starting* work shifts; **Depends on** is the merge/start gate.

---

## Dependency sketch

```text
S2-01 Design — App workspace chrome (sidebar + content host) (done)
S2-02 Design — Source fields (metadata field vocabulary)
S2-03 Design — Source types (types + suggested field associations)
S2-04 Design — Sources list (browse + Add Source → separate Source page)
S2-23 Design — Source page (Artifacts + File ingest)
S2-20 Design — Files list (project file browser)
        │
        ▼
S2-05 PR — Audit tables + write helper (done)   ◄── gate for research mutations
S2-06 PR — date_values schema + helpers (done)
S2-07 PR — Source vocabulary tables + small seed (done)
S2-08 PR — sources + source_notes CRUD (+ audit) (done)
S2-09 PR — files store + ingest (+ audit on File create) (done)
S2-10 PR — artifacts CRUD + attach/replace File (+ audit) (done)
S2-11 PR — source_metadata (+ type field suggestions) (done)
S2-12 PR — file_derivatives + thumbnail pipeline (minimal) (done)
S2-13 PR — FFI Source use-cases (done)
S2-14 PR — Swift app workspace layout (sidebar shell) (done)
S2-15 PR — Swift Source fields (list + create/edit)
S2-22 PR — PVTable (custom-chrome table + keyboard/a11y)
S2-16 PR — Swift Source types (list + associations) (done)
S2-17 PR — Swift Sources list (+ Add Source; navigate to Source page)
S2-18 PR — Swift Source page (Artifacts + file ingest + list thumbnails)
S2-21 PR — Swift Files list (+ Source link)
S2-19 PR — Dogfood polish (copy, empty states, errors, tests)
```

Design **S2-01** / chrome **S2-14** are done. Remaining Design: **S2-02** → **S2-03** → **S2-04** → **S2-23** → **S2-20**. Feature UI: **S2-15** → **S2-22** → **S2-16** → **S2-17** → **S2-18** → **S2-21** → **S2-19**. Do not start a feature UI PR until its Design step has a reviewable board (or an explicit “design enough to code” note).

---

## Steps

### S2-01 — Design: App workspace chrome (sidebar + content)

**Claude Design brief:** [`design/S2-01-workspace-chrome.md`](design/S2-01-workspace-chrome.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | — |
| **Deliverables** | Done. Board + brief for the post-onboarding **app workspace**: leading sidebar with **Sources**, **Source types**, and **Source fields**; main content host; project label + contributor identity in chrome; Sign Out in the app menu only; label expand/collapse toggle; selected vs idle nav states; short-window sidebar scroll. No “coming soon” nav stubs. |
| **Context** | [`application-stack.md`](../../application-stack.md) (Mac owns windows/navigation); design system README lists `SidebarNav` as add-on-demand — this board decides whether to port that component or a bespoke onboarding-aligned rail. Preserve Provenencia visual language (tokens already in `macos/App/DesignSystem/`). One clear composition: sidebar + one primary content column, not a multi-panel dashboard. |
| **Out** | Feature destination layouts (S2-02+); Settings product; future-layer nav stubs. |
| **Feeds** | S2-14 (and constrains how S2-15+ mount content) |

---

### S2-02 — Design: Source fields (metadata field vocabulary)

**Claude Design brief:** [`design/S2-02-source-fields.md`](design/S2-02-source-fields.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done) — mounts in the **Source fields** destination |
| **Deliverables** | Board for the **Source fields** destination: searchable list/table of `source_metadata_fields` (label + data type; origin visible in one list, not split lists); detail/edit (label, description; **data type immutable after create**); add/create flow with **auto slug key from label** (not user-typed). No delete. Add chrome (modal/sheet vs nested pane + back) is a Design choice. Lives inside the workspace content host — not a separate window chrome. |
| **Context** | Source doc §5.1; [`seeded-vocabulary.md`](../../seeded-vocabulary.md) §1.1 (`origin`). Simplest Spike 2 UI; no dependency on Sources catalog or type↔field suggestions. **`user` and create-time `provenencia` rows are editable; plugin rows are view-only.** |
| **Out** | Delete/retire fields; attaching fields to types (S2-03); Source instance metadata values; Source types admin; Citations/credibility. |
| **Feeds** | S2-15 (and supplies the field pool for S2-03) |

---

### S2-03 — Design: Source types (types + suggested field associations)

**Claude Design brief:** [`design/S2-03-source-types.md`](design/S2-03-source-types.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done); S2-02 (Source fields vocabulary — association picker pool) |
| **Deliverables** | Board for the **Source types** destination: list (label + key; origin visible); detail/expanded view with description + associated metadata fields from `source_type_metadata_fields`; assign associations from existing Source fields; **remove associations**; add/create type flow; **delete a type** only while unused and not plugin-owned (added when the brief was refined — T-12). **Design decision:** master–detail split, not in-list expand or a breadcrumb push. |
| **Context** | Source doc §§3, 5.2; [`seeded-vocabulary.md`](../../seeded-vocabulary.md) §1.1. One complexity step above S2-02 because suggestions join fields. Prefer `provenencia` type rows view-only for label/description; association edit on seeded types OK for dogfood. |
| **Out** | Force-deleting a Source type sources still use; field vocabulary CRUD (S2-02); Source instance UI; Artifacts. |
| **Feeds** | S2-16 |

---

### S2-04 — Design: Sources list

**Claude Design brief:** [`design/S2-04-sources-list.md`](design/S2-04-sources-list.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done); S2-02 / S2-03 (types vocabulary for Add Source / row type name) |
| **Deliverables** | Board for the **Sources** list only: **list-style** rows (thumbnail + title + type/`SRC-…`) via a **new list component** — **not** `PVTable`; search; empty + **Add Source** as a **centered dimming dialog** (same family as confirm dialogs; type required; title/description optional) that on Create navigates to the **separate Source page**; row select also opens that page. Not master–detail like S2-02/S2-03. Do not design Artifacts or File ingest here. |
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
| **Deliverables** | Board for the **individual Source page** (view/edit only — no create/draft): identity + editable title/description; notes + metadata; Artifacts list (`ART-…`, display fallback, thumbnail); Artifact detail (description + **one** primary File + that File’s derivatives); add Artifact; add/replace File ingest. Back/breadcrumb to the Sources list. Nested Artifact nav within this page stack is a Design choice — document it. |
| **Context** | Source doc §§4, 6–8. Artifact has **no label column** — use description / filename / ref fallback. Multiple scans = multiple Artifacts. File association already exists (`IngestArtifactFile`); list thumbnails may need FFI ensure/list wiring in S2-18. Create lives on S2-04’s Add Source dialog. |
| **Out** | Redesigning the Sources list (S2-04); delete Sources/Artifacts/Files; Interpretation; vocabulary admin; project Files browser (S2-20). |
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
| **Out** | Ingest/replace (S2-23/S2-18); delete; Interpretation. |
| **Feeds** | S2-21 |

---

### S2-05 — PR: Audit tables and atomic write helper

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | — (merge before any Source mutation PR) |
| **Deliverables** | Done. Migration `000003` + `core/database/audit.Record` on `sql.Tx`; create/update/delete JSON and monotonic revision tested. |
| **Context** | Spike 1 explicit gate. Skills: [`add-catalog-migration`](../../../.cursor/skills/add-catalog-migration/SKILL.md), [`add-catalog-query`](../../../.cursor/skills/add-catalog-query/SKILL.md). Entity types will include `source`, `artifact`, `file`, `source_metadata`, etc. as later PRs land — helper should accept `entity_type` string. |
| **Notes** | Do not audit the audit tables. `user_id` from install/session UUID already in `users`. |

---

### S2-06 — PR: `date_values` schema and minimal helpers

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | — (can parallel S2-05; must merge before date metadata writes in S2-11) |
| **Deliverables** | Done. Migration `000004` + `core/database/datevalues` Insert/Lookup for exact (optional time through ms + free-text tz), year, ABT, and cascading ranges with optional start/end tz; tests. |
| **Context** | Shared infrastructure, not Source-owned. Keep vocabulary flexible; do not freeze a full GEDCOM date language in this PR. |

---

### S2-07 — PR: Source vocabulary tables + small seed

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-04 seed decision (or interim seed with note “Design may trim”) |
| **Deliverables** | Done. Migration `000005` + `sourcetypes`/`sourcefields`/`sourcevocab`; origin namespaces; create-time `Install` seeds a trimmed starter (`birth_certificate` + suggested fields). Opens do not heal Source vocab. |
| **Context** | Source doc §§3, 5.1–5.2; vocabulary doc §1.1 / §2. Starter is intentionally tiny; horizon lists stay documentation. |
| **Out** | No `sources` rows yet. |

---

### S2-08 — PR: `sources` + `source_notes` CRUD (audited)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-05, S2-07 |
| **Deliverables** | Done. Migration `000006` + `sources` package; SRC refs; audited create/update Source and note add/update/delete; list/get by id/ref. |
| **Context** | Source doc §4; [`catalog-refs.md`](../../catalog-refs.md); `ref.PrefixSource`. |
| **Out** | FFI/UI; metadata; artifacts. |

---

### S2-09 — PR: Files store + ingest (audited File create)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-05 |
| **Deliverables** | Done. Migration `000007` + `files` helpers + `ingest.File`; content-addressed `objects/{hh}/{hh}/{hex}`; regular-file/symlink/size checks; audit `create_file` only on new checksum rows. |
| **Context** | Source doc §6; stack object naming. No Artifact linkage yet. |
| **Out** | Derivatives; Swift file UI. |

---

### S2-10 — PR: `artifacts` CRUD + attach/replace File

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-08, S2-09 |
| **Deliverables** | Done. Migration `000008` + `artifacts` helpers; mint `ART-…`; fileless create; attach/replace `file_id` (old File retained); list by `source_id`; audited `create_artifact` / `update_artifact`; tests for null `file_id` and Source `ON DELETE CASCADE`. |
| **Context** | Source doc §§7, 9, 11. Primary File deletion still unsupported. |

---

### S2-11 — PR: `source_metadata` (text + date)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-06, S2-07, S2-08 |
| **Deliverables** | Done. Migration `000009` + `sourcemetadata` helpers; set/clear with `data_type` validation; date fidelity (`value_text` + `date_value_id`); `ListWorkspace` merges type suggestions with extra values; audited `update_source_metadata`. |
| **Context** | Source doc §5.3. Date fidelity: keep `value_text` even when structured date exists. |

---

### S2-12 — PR: `file_derivatives` + minimal thumbnail

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-09 (ideally after S2-03 confirms preview needs) |
| **Deliverables** | Done. Migration `000010` + `filederivatives` helpers; `derivatives.Ensure`/`EnsureThumbnail` with parameterized `Spec` + encapsulated `raster.Options`/`EncodeJPEG` (jpeg/png/gif/bmp/tiff/webp → JPEG; default thumb ≤256px; transform hook); content-addressed `files`/`objects/`; idempotent; skip other MIME; no research audit; fixture tests. Hardened: pre-decode pixel budget + format allowlist, 128 MiB source cap, checksum-verified reads (`filederivatives.unprocessable` / `filederivatives.corrupt_object`), `MaxEdge` cap 4096, bounded decode concurrency. |
| **Context** | Source doc §8. Skip non-image MIME types cleanly. `Ensure` trusts `sourceFileID` — FFI wiring (S2-13+) must authorize File access before calling, and map the two new error codes in L10n. `unprocessable` files are candidates for a future manual thumbnail-attachment flow (ingest a preview image, link via `file_derivatives`). |

---

### S2-13 — PR: FFI Source use-cases

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-08…S2-11 (S2-12 optional) |
| **Deliverables** | Done. Proto + handlers for Source list/workspace/CRUD, notes, metadata, artifacts, ingest, types/fields; GenealogyStore/FakeStore/GoStore; L10n for new apperr codes; runRPC tests. |
| **Context** | Skills: [`add-ffi-handler`](../../../.cursor/skills/add-ffi-handler/SKILL.md); stack § FFI granularity. Extend `GenealogyStore` + `FakeStore` in the same PR or with S2-15 — prefer same PR if FakeStore otherwise blocks Swift tests. |

---

### S2-14 — PR: Swift app workspace layout (sidebar shell)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-01 (design enough); Spike 1 onboarding “signed in” as the entry point to replace |
| **Deliverables** | Done. Post-sign-in **app workspace** with sidebar + content host; destinations **Sources**, **Source types**, **Source fields** (placeholder panes); session/project chrome per S2-01; **Sign Out** via app menu only; selection-driven content; L10n for nav labels; chrome in `Features/Workspace/`. |
| **Context** | [`macos-client-patterns.md`](../../macos-client-patterns.md); [`application-stack.md`](../../application-stack.md) (navigation is a Mac concern). This step is **chrome only** — no Source CRUD UI. |
| **Out** | Feature destination content (S2-15+); interpreting other layers. |
| **Notes** | Shipped as discrete chrome (not folded into Source catalog). |

---

### S2-15 — PR: Swift Source fields (list + create/edit)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-02 (design enough), S2-13, S2-14 |
| **Deliverables** | **Source fields** destination: searchable list/table (label, data type, origin); detail/edit for project fields (label, description; data type fixed at create); add/create flow per S2-02 board. No delete. **Auto-generate `key` as a kebab slug of the label** — do not collect key in the UI. Prefer Go as source of truth (e.g. derive in `CreateMetadataField` from label; ignore/omit client-supplied key), with a small shared slug helper if needed (related to onboarding folder slug rules, without the `.provenencia` suffix). If edit needs an `UpdateMetadataField` (or equivalent) FFI beyond today’s create/list, include that thin engine gap in this PR. `Features/` model+views mounted in the existing workspace content host. Unit tests with `FakeStore` (including slug collision / unslugifiable label). L10n via skill. |
| **Context** | Mount under S2-14 **Source fields** pane — do not reintroduce a separate top-level window chrome. **`user` and create-time `provenencia` rows are editable; plugin rows are view-only.** |
| **Out** | Type↔field suggestions UI; Source catalog; delete/retire. |
| **Feeds** | S2-22 (extract the hand-rolled list into `PVTable`) |

---

### S2-22 — PR: `PVTable` — custom-chrome table with keyboard/a11y

**Implementation brief (full checklist for the implementing agent):** [`S2-22-pv-table.md`](S2-22-pv-table.md)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-15 (Source fields list exists to extract from) |
| **Deliverables** | Design-system **`PVTable`** under `macos/App/DesignSystem/Components/Data/`: generic single-selection table that keeps Provenencia visual chrome (micro-caps headers, hover/selected row, accent bar, badge cells) rather than SwiftUI `Table` / `NSTableView`. Migrate the Source fields list pane onto it. Add native-parity **keyboard** (focusable table, ↑/↓ + Home/End, scroll-into-view, type-to-select by primary text) and **VoiceOver** (combined row elements, selected trait, sort ascending/descending announced). Unit-test pure helpers (type-select buffer, selection movement). Document the tradeoff + interaction contract in `DesignSystem/README.md`. L10n for any new a11y strings via skill. |
| **Context** | Tabular browse lists matter less visually than design-system fidelity in this product, but researchers still expect Mac keyboard and accessibility behavior. Extract once here so S2-16 (Source types) can reuse `PVTable` instead of copying the hand-rolled `ScrollView` + `LazyVStack` pattern. **Sources (S2-17) and likely Files use a separate list-style component** — not `PVTable`. Deployment target is macOS 14 — prefer `.focusable()` / `.onKeyPress` / `ScrollViewReader`; no AppKit wrap required. |
| **Out** | Native SwiftUI `Table`; multi-select; column resize/reorder; rewriting Source types / Sources / Files lists (Source types *consumes* `PVTable`; Sources/Files do **not**); FFI/data-model changes; unrelated DesignSystem cleanup. |
| **Feeds** | S2-16 (prefer `PVTable` for vocabulary lists) |

---

### S2-16 — PR: Swift Source types (list + associations)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-03 (design enough), S2-15 (fields exist to assign), **S2-22** (`PVTable` for the types list), S2-13, S2-14 |
| **Deliverables** | Done. **Source types** destination: master–detail split (S2-03 T-13) mounted in the S2-14 pane — list (label + origin pill, key, suggested-field count) via **`PVTable`**, detail with description + suggested fields, assign/remove `source_type_metadata_fields` associations from the Source fields pool, add/create type, and delete gated on `usedBy == 0` and non-plugin origin (S2-03 T-12, added when the brief was refined). Origin markers hoisted out of Source fields into shared `OriginBadge` / `OriginPill` (plus the new plugin in-list pill). The assign control is a new design-system **`PVComboBox`** (searchable on field label *or* key, rich rows with the data-type badge, macOS key handling) with the assign action as an icon button beside it — the board switched from a plain `Select` after the first pass; single-select subset only, documented in `DesignSystem/README.md`. FFI added: `UpdateSourceType`, `ListTypeSuggestions`, `AssignTypeField`, `RemoveTypeField`; `CreateSourceType` now mints its key from the label like `CreateMetadataField`, and `SourceType` carries `used_by` + `suggested_field_count`. Unit tests with `FakeStore`; Go tests for `sourcetypes.Create`/`Update`/`UsedBy` and `sourcevocab.AppendSuggestion`. |
| **Context** | Mount under S2-14 **Source types** pane. Removing a suggestion must not delete field vocabulary or Source metadata values. Reuse `PVTable` from S2-22 — do not reintroduce a hand-rolled column list. |
| **Out** | Source catalog UI; field definition CRUD (S2-15); reordering suggestions; force-deleting a type sources still use. |

---

### S2-17 — PR: Swift Sources list

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-04 (design enough), S2-16 (types available to pick), S2-13, S2-14 |
| **Deliverables** | **Sources** list destination: homogeneous **list** rows (thumbnail + title + type/`SRC-…`; thumbnail placeholder OK if S2-18 owns real thumbs) via a **new design-system list component** — **do not use `PVTable`**; **Add Source** centered dialog (reuse confirm-dialog chrome; type + optional title/description) that on Create navigates to a **separate Source page** (stub/placeholder page OK until S2-18); row select opens that page. Unit tests with `FakeStore`. L10n via skill. |
| **Context** | Mount under S2-14 **Sources** pane. Match S2-04: **not** master–detail; create is confirm-style dialog → Source page; presentation is list-not-table. Do not ship full Artifact/File UI here. |
| **Out** | Source page body, Artifact detail, ingest, derivative/thumbnail ensure (S2-18). |

---

### S2-18 — PR: Swift Source page (Artifacts + file ingest + thumbnails)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-23 (design enough), S2-17, S2-13 (S2-12 done for generation) |
| **Deliverables** | **Source page** reached from the list: description; notes + metadata editor; Artifacts list (`ART-…` + display fallback); Artifact detail (description; primary File identity; derivatives); **Add Artifact**; **Add / replace file** via NSOpenPanel → `IngestArtifactFile` (path only). Surface thumbnails on Sources/Artifacts list rows (ensure or fetch derivative `rel_path`; Swift reads bytes). Include any thin FFI gap to list/ensure thumbnails for list cells. Tests for model state transitions with `FakeStore`. Confirm file-access usage copy/entitlements. |
| **Context** | Association mechanism **already exists** (`IngestArtifactFile` / `CreateArtifact`). Do not invent multi-primary-file attach. Stack: Swift must not write `objects/` itself. Back to Sources list per S2-23. |
| **Out** | Vocabulary admin; delete primary Files; project-wide Files browser (S2-21). |

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
| S2-05 | Record research mutations in append-only audit revisions |
| S2-06 | Add shared genealogical date_values storage |
| S2-07 | Seed extensible Source types and metadata fields |
| S2-08 | Create and update Sources with notes under audit |
| S2-09 | Ingest immutable content-addressed Files into the project |
| S2-10 | Attach Artifacts and primary Files to Sources |
| S2-11 | Store descriptive Source metadata (text and dates) |
| S2-12 | Generate disposable File thumbnails |
| S2-13 | Expose Source catalog use-cases over FFI |
| S2-14 | Replace post-onboarding home with a sidebar workspace shell |
| S2-15 | Let researchers browse and define Source metadata fields |
| S2-22 | Extract a design-system table with keyboard and VoiceOver parity |
| S2-16 | Let researchers define Source types and suggested fields |
| S2-17 | Add a Sources list inside the app workspace |
| S2-18 | Open a Source page with Artifacts, ingest, and thumbnails |
| S2-21 | Browse project Files and jump to their Source |
| S2-19 | Harden the Source catalog for first dogfood |

---

## Parallelism and team split

| Track | Steps |
| --- | --- |
| **Design (Claude Design)** | S2-01 (done) → S2-02 (fields) → S2-03 (types) → S2-04 (Sources list) → S2-23 (Source page) → S2-20 (Files) |
| **Core schema / Go** | S2-05…S2-13 (done) |
| **FFI + Mac** | S2-14 (done) → S2-15 → **S2-22** (`PVTable`) → S2-16 → S2-17 → S2-18 → S2-21 → S2-19 |

Prefer **many small PRs**. Vocabulary admin before Sources. Land **`PVTable` (S2-22)** before Source types so vocabulary lists reuse it. Sources list (S2-17) ships a **new list-style component** (not `PVTable`); Source page + Artifact ingest + thumbnails (S2-18); then project Files browser (S2-21 — prefer reusing the Sources list component). Do not fold the workspace shell into feature destination PRs.

---

## Explicit non-goals checklist (keep PRs honest)

- [ ] No Interpretation tables or RPCs (sidebar stubs only)
- [ ] No Source credibility UI
- [ ] No File bytes in protobuf
- [ ] No deletion of primary Files
- [ ] No full vocabulary dump from `seeded-vocabulary.md`
- [ ] No audit history browser required for done

---

## After Spike 2

Likely next spikes (not scheduled here):

1. Fill sidebar destinations beyond Sources / types / fields / Files (Interpretation entry, Settings) when those features exist.
2. Audit history UI / “what changed” for a Source.
3. Citation → Observation → Node (Interpretation) on top of Artifacts.
4. Project open/create UX polish beyond Spike 1 onboarding.
5. Richer date entry and more seeded types driven by real cataloging sessions.
