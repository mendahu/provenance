# Spike 2 — Completed steps

Finished Spike 2 work kept for history. The live to-do list is [`README.md`](README.md).

IDs stay stable (`S2-NN`). Do not renumber when moving steps here.

## Index

| Step | Kind | One-liner |
| --- | --- | --- |
| [S2-01](#s2-01--design-app-workspace-chrome-sidebar--content) | Design | App workspace chrome (sidebar + content host) |
| [S2-02](#s2-02--design-source-fields-metadata-field-vocabulary) | Design | Source fields vocabulary |
| [S2-03](#s2-03--design-source-types-types--suggested-field-associations) | Design | Source types + suggested fields |
| [S2-04](#s2-04--design-sources-list) | Design | Sources list + Add Source dialog |
| [S2-23](#s2-23--design-source-page-artifacts--files) | Design | Source page (Artifacts + Files) |
| [S2-05](#s2-05--pr-audit-tables-and-atomic-write-helper) | PR | Audit tables + write helper |
| [S2-06](#s2-06--pr-date_values-schema-and-minimal-helpers) | PR | `date_values` schema + helpers |
| [S2-07](#s2-07--pr-source-vocabulary-tables--small-seed) | PR | Source vocabulary tables + small seed |
| [S2-08](#s2-08--pr-sources--source_notes-crud-audited) | PR | `sources` + `source_notes` CRUD (audited) |
| [S2-09](#s2-09--pr-files-store--ingest-audited-file-create) | PR | Files store + ingest |
| [S2-10](#s2-10--pr-artifacts-crud--attachreplace-file) | PR | Artifacts CRUD + attach/replace File |
| [S2-11](#s2-11--pr-source_metadata-text--date) | PR | `source_metadata` (text + date) |
| [S2-12](#s2-12--pr-file_derivatives--minimal-thumbnail) | PR | `file_derivatives` + thumbnail pipeline |
| [S2-13](#s2-13--pr-ffi-source-use-cases) | PR | FFI Source use-cases |
| [S2-14](#s2-14--pr-swift-app-workspace-layout-sidebar-shell) | PR | Swift app workspace layout |
| [S2-15](#s2-15--pr-swift-source-fields-list--createedit) | PR | Swift Source fields |
| [S2-22](#s2-22--pr-pvtable--custom-chrome-table-with-keyboarda11y) | PR | `PVTable` (custom-chrome table + keyboard/a11y) |
| [S2-16](#s2-16--pr-swift-source-types-list--associations) | PR | Swift Source types |
| [S2-17](#s2-17--pr-swift-sources-list) | PR | Swift Sources list |
| [S2-24](#s2-24--pr-source-page-schema-precede-label-first-attach-credibility) | PR | Artifact label, first-attach, credibility schema |
| [S2-18](#s2-18--pr-source-page-shell--artifacts--ingest) | PR | Source page + Notes, credibility, Artifact ingest |
| [S2-25](#s2-25--pr-source-metadata-editor-suggestions-dismiss-reorder) | PR | Metadata dismiss, order, Source page editor |

---

## Steps

### S2-01 — Design: App workspace chrome (sidebar + content)

**Claude Design brief:** [`design/archive/S2-01-workspace-chrome.md`](design/archive/S2-01-workspace-chrome.md)

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

**Claude Design brief:** [`design/archive/S2-02-source-fields.md`](design/archive/S2-02-source-fields.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done) — mounts in the **Source fields** destination |
| **Deliverables** | Done. Board for the **Source fields** destination: searchable list/table of `source_metadata_fields` (label + data type; origin visible in one list, not split lists); detail/edit (label, description; **data type immutable after create**); add/create flow with **auto slug key from label** (not user-typed). No delete. Add chrome (modal/sheet vs nested pane + back) is a Design choice. Lives inside the workspace content host — not a separate window chrome. |
| **Context** | Source doc §5.1; [`seeded-vocabulary.md`](../../seeded-vocabulary.md) §1.1 (`origin`). Simplest Spike 2 UI; no dependency on Sources catalog or type↔field suggestions. **`user` and create-time `provenencia` rows are editable; plugin rows are view-only.** |
| **Out** | Delete/retire fields; attaching fields to types (S2-03); Source instance metadata values; Source types admin; Citations/credibility. |
| **Feeds** | S2-15 (and supplies the field pool for S2-03) |

---

### S2-03 — Design: Source types (types + suggested field associations)

**Claude Design brief:** [`design/archive/S2-03-source-types.md`](design/archive/S2-03-source-types.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done); S2-02 (Source fields vocabulary — association picker pool) |
| **Deliverables** | Done. Board for the **Source types** destination: list (label + key; origin visible); detail/expanded view with description + associated metadata fields from `source_type_metadata_fields`; assign associations from existing Source fields; **remove associations**; add/create type flow; **delete a type** only while unused and not plugin-owned (added when the brief was refined — T-12). **Design decision:** master–detail split, not in-list expand or a breadcrumb push. |
| **Context** | Source doc §§3, 5.2; [`seeded-vocabulary.md`](../../seeded-vocabulary.md) §1.1. One complexity step above S2-02 because suggestions join fields. Prefer `provenencia` type rows view-only for label/description; association edit on seeded types OK for dogfood. |
| **Out** | Force-deleting a Source type sources still use; field vocabulary CRUD (S2-02); Source instance UI; Artifacts. |
| **Feeds** | S2-16 |

---

### S2-04 — Design: Sources list

**Claude Design brief:** [`design/archive/S2-04-sources-list.md`](design/archive/S2-04-sources-list.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done); S2-02 / S2-03 (types vocabulary for Add Source / row type name) |
| **Deliverables** | Done. Board for the **Sources** list only: **list-style** rows (thumbnail + title + type/`SRC-…`) via a **new list component** — **not** `PVTable`; search; empty + **Add Source** as a **centered dimming dialog** (same family as confirm dialogs; type + **title** required; description optional) that on Create navigates to the **separate Source page**; row select also opens that page. Not master–detail like S2-02/S2-03. Do not design Artifacts or File ingest here. |
| **Context** | Source doc §4 (list-facing). Navigation locked: **separate page**. Create locked: **confirm-style dialog on the list**, then land on S2-23 (view/edit). Presentation locked: **evidence list**, not vocabulary table — `PVTable` remains fields/types only. |
| **Out** | Source page body, Artifacts, ingest (S2-23 / S2-18); delete; vocabulary admin. |
| **Feeds** | S2-17 |

---

### S2-23 — Design: Source page (Artifacts + Files)

**Claude Design brief:** [`design/archive/S2-23-source-detail.md`](design/archive/S2-23-source-detail.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Depends on** | S2-01 (done); S2-04 (done); S2-02 / S2-03 (notes/metadata + type display) |
| **Deliverables** | Done. Board for the **individual Source page** (view/edit only — no create/draft): identity + editable title/description; **Source credibility** (three-point grade + optional argument); **Notes** and **Metadata** as distinct areas; Artifacts list with **in-place accordion**; primary File opens **externally**; **Add Artifact** centered modal; **Add file…** fileless-only — **no Replace**; **breadcrumb** to Sources list. |
| **Context** | Source doc §§4, 6–8; credibility: [`research-judgment-model.md`](../../research-judgment-model.md) §2. Feeds S2-18 schema/FFI gaps (Artifact `label`, suggestion dismiss, metadata order, credibility tables, first-attach-only ingest). |
| **Out** | Redesigning the Sources list; delete; Replace file; Citations / Observations / Nodes; Claim confidence; in-app File preview; project Files browser (S2-20). |
| **Feeds** | S2-24 → S2-18 (and S2-25 / S2-26) |

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
| **Deliverables** | Done. **Source fields** destination: searchable list/table (label, data type, origin); detail/edit for project fields (label, description; data type fixed at create); add/create flow per S2-02 board. No delete. **Auto-generate `key` as a kebab slug of the label** — do not collect key in the UI. Prefer Go as source of truth (e.g. derive in `CreateMetadataField` from label; ignore/omit client-supplied key), with a small shared slug helper if needed (related to onboarding folder slug rules, without the `.provenencia` suffix). If edit needs an `UpdateMetadataField` (or equivalent) FFI beyond today’s create/list, include that thin engine gap in this PR. `Features/` model+views mounted in the existing workspace content host. Unit tests with `FakeStore` (including slug collision / unslugifiable label). L10n via skill. |
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
| **Deliverables** | Done. Design-system **`PVTable`** under `macos/App/DesignSystem/Components/Data/`: generic single-selection table that keeps Provenencia visual chrome (micro-caps headers, hover/selected row, accent bar, badge cells) rather than SwiftUI `Table` / `NSTableView`. Migrate the Source fields list pane onto it. Add native-parity **keyboard** (focusable table, ↑/↓ + Home/End, scroll-into-view, type-to-select by primary text) and **VoiceOver** (combined row elements, selected trait, sort ascending/descending announced). Unit-test pure helpers (type-select buffer, selection movement). Document the tradeoff + interaction contract in `DesignSystem/README.md`. L10n for any new a11y strings via skill. |
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
| **Depends on** | S2-04 (done), S2-16 (types available to pick), S2-13, S2-14 |
| **Deliverables** | Done. **Sources** list destination: homogeneous **list** rows (thumbnail + title + type/`SRC-…`) via design-system **`PVList`** (not `PVTable`); **`PVDialog`** **Add Source** (type + **required** title + optional description) that on Create navigates to a **separate Source page** (stub until S2-18); row select opens that page. Search/filter/sort chrome; empty states; unit tests with `FakeStore`; L10n via skill. |
| **Context** | Mount under S2-14 **Sources** pane. Match S2-04: **not** master–detail; create is confirm-style dialog → Source page; presentation is list-not-table. Thumbnail placeholders OK until S2-18 owns real thumbs. |
| **Out** | Source page body, Artifact detail, ingest, derivative/thumbnail ensure (S2-18). |
| **Feeds** | S2-18; S2-21 (prefer reusing `PVList`) |

---

### S2-24 — PR: Source page schema precede (label, first-attach, credibility)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-23 (done), S2-13 |
| **Deliverables** | Done. **Engine/docs only (no Source page UI):** (1) Artifact **`label`** column (required) — migration + query/proto/FFI create/update/get/list; (2) **first-attach only** — `IngestArtifactFile` rejects when Artifact already has a File; align [`source-layer-data-model.md`](../../source-layer-data-model.md); (3) **Source credibility** — migrate `source_credibility_grades` + `source_credibility_assessments`, seed `provenencia` grades (`low_trust` / `standard` / `high_trust`), audited get/upsert assessment + list grades, expose on Source workspace FFI (do **not** add a column on `sources`). Go + `FakeStore`/protocol stubs + tests. |
| **Context** | Unblocked S2-18 UI. Credibility semantics: [`research-judgment-model.md`](../../research-judgment-model.md) §2. |
| **Out** | Source page SwiftUI; metadata suggestion dismiss / `sort_order`; thumbnail ensure/list; Files browser. |
| **Feeds** | S2-18 |

---

### S2-18 — PR: Source page shell + Artifacts + ingest

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-24 (done), S2-17 (done), S2-23 (done) |
| **Deliverables** | Done. Replaced the S2-17 Source page stub: **`PVBreadcrumbs`** to Sources list; editable identity (**title**, type, **description**); **Notes** stream (add/edit/delete); **credibility** control (grade + optional argument); **Artifacts** in-place accordion (`label` + `ART-…` + thumbnail **placeholder**); expand shows label/description + primary File identity; **Open** via `NSWorkspace`; **Add Artifact** centered modal (required label + optional File); **Add file…** on fileless only — **no Replace**. `FakeStore` model tests; user-selected file entitlement. Metadata UI deferred to S2-25; real thumbs to S2-26. |
| **Context** | Thin vertical slice of S2-23. Swift does not write `objects/` itself. |
| **Out** | Metadata suggestions / dismiss / drag reorder (S2-25); derivative thumbnail ensure/list UI (S2-26); in-app File preview; Replace file; Citations / Observations / Nodes; project Files browser (S2-21). |
| **Feeds** | S2-25, S2-26, S2-21 |

---

### S2-25 — PR: Source metadata editor (suggestions, dismiss, reorder)

| | |
| --- | --- |
| **Kind** | PR |
| **Depends on** | S2-18 (done), S2-23 (done) |
| **Deliverables** | Done. **`source_metadata_layout`** migration for per-Source suggestion **dismiss** + display **order**; `ListWorkspace` filters dismissed empty suggestions and orders by layout; FFI `DismissSourceMetadataSuggestion` / `ReorderSourceMetadata`; Source page **Metadata** section (values, quick-add suggestions with X, **Add** vocabulary dialog, drag reorder via **`PVReorderableList`**); Artifact accordion expand matched to board (two-column sunken panel). `FakeStore` model tests. |
| **Context** | Completes the Metadata half of S2-23. |
| **Out** | Thumbnail wiring (S2-26); vocabulary admin; Claim confidence. |
| **Feeds** | S2-26, S2-21, S2-19 |

---

