# S2-23 — Source page (Artifacts + Files)

**Kind:** Claude Design board  
**Spike:** Provenencia Spike 2 (Source layer validation)  
**Implements later as:** PR S2-18  
**Depends on:** S2-01 workspace chrome (done); S2-04 Sources list (how researchers arrive here); S2-02 / S2-03 vocabulary (metadata editor + type display)  
**Related briefs:** [`S2-04-sources-list.md`](S2-04-sources-list.md), [`archive/S2-02-source-fields.md`](archive/S2-02-source-fields.md), [`archive/S2-03-source-types.md`](archive/S2-03-source-types.md), [`S2-20-files-list.md`](S2-20-files-list.md)

Paste this entire document into Claude Design as the requirements for one board/flow.

---

## 1. Objective

Design the **individual Source page** — a separate destination from the Sources list (S2-04), not a master–detail pane beside that list. Researchers open it by selecting a list row, or after **Add Source** succeeds (create dialog lives on S2-04). This page is **view/edit only** for an already-persisted Source: always-editable identity fields, notes, metadata, the Artifacts list, and File **attach** (not replace). **No create/draft mode** on this board.

The Source page is the **lowest navigation level** in this flow — there is no further page push for an Artifact. Artifacts appear as a **list on this page**; “Artifact detail” is an **in-place expand** (accordion-style) on a list row. Expanding shows more Artifact fields plus detail for the single associated primary File (when present). Do **not** surface File derivatives in that expand — they are generated for the app (e.g. list thumbnails), not something researchers should interact with. The researcher stays on the Source page the whole time.

```text
Sources list (S2-04)
  ├─ Add Source dialog → Create
  └─ select row
         └─ Source page (this board) — view/edit; leaf destination
              ├─ identity + description + notes + metadata (editable)
              └─ Artifacts list (on this page)
                   └─ row expand (accordion) — not a separate page
                        ├─ Artifact detail (e.g. label, description)
                        └─ primary File detail only (when present; no derivatives list)
```

Include **add flows** on this page: **Add Artifact** (same centered dimming modal as Add Source; combined with optional File ingest); **Add file…** only on a **fileless** Artifact. Assume S2-01 chrome. **Do not redraw a second window shell.** Do **not** redesign the Sources list or the Add Source dialog — only how this page is reached (**breadcrumb** to the list).

---

## 2. Domain model (UI must reflect)

Authoritative: [`source-layer-data-model.md`](../../../source-layer-data-model.md) §§4, 6–8; stack rules for ingest (bytes never in protobuf).

### 2.1 Source

| Field / concept | UI implication |
| --- | --- |
| `title` | **Required** (non-empty), same rule as Add Source (S2-04). Editable on this page; primary headline. Same control for view and edit — no separate read-only mode. |
| `ref` (`SRC-…`) | Always visible; mono; not editable (minted at create). |
| Type (`source_types.label`) | Show type **name**; changing type after create is **allowed**. |
| `description` | Catalog text about the Source — editable on this page (same as title: always editable). |
| Notes | Distinct area on the Source page: a **stream** of researcher commentary — multi-entry add/edit/delete over time, not a single text field. Keep secondary to the evidence tree if the board gets crowded, but do not omit. |
| Metadata | Distinct area on the Source page (separate from Notes): a **collection of properties**. Show all `source_metadata` values for this Source. **Type suggestions** (not yet filled) are quick-add rows — type a value and save; each is **permanently dismissible** (e.g. X) with dismiss **persisted** per Source. Separately, an **Add** control opens a field picker over the full vocabulary, then value entry + save (not the same as accepting a suggestion). Rows are **user-orderable** (drag). Design assumes schema support for dismiss + order — S2-18 adds it. |

### 2.2 Artifact

| Field / concept | UI implication |
| --- | --- |
| `ref` (`ART-…`) | Always visible; mono; not editable. |
| `label` | **Required** (non-empty) human name for the Artifact. Primary list-row headline so rows are easily identifiable. Editable when expanded (same always-editable pattern as Source title). Design assumes this column exists — S2-18 adds it to the schema before shipping the page. |
| List thumbnail | Each Artifact **list row** includes a **thumbnail** of the associated primary File (from a File derivative under the hood). Fileless Artifacts (or missing derivative) use a calm **placeholder** — not an error. Same slot size whether present or not. Do **not** expose derivatives as a separate UI list. |
| `description` | Longer optional text; shown when the Artifact row is expanded — not the list headline. |
| `file_id` | **Zero or one** primary File. Fileless Artifacts are valid (physical-only). Once set, the primary File is **not** replaced on this Artifact. |
| Multiple scans | **Multiple Artifacts** under one Source — including a clearer/newer scan of the same document. Do **not** swap files under an existing `ART-…` (Citations locate into an Artifact; pointer-swap would break locators). Citation move/duplicate across Artifacts is Interpretation — out of scope here. |

### 2.3 File + derivatives

| Rule | UI implication |
| --- | --- |
| Primary File | Immutable content-addressed object; when an Artifact is expanded, show **only** this File — filename / media type / size. **Open** activates the file in the **default external app** (e.g. Preview / QuickTime via `NSWorkspace`) — not an in-app viewer. In-app rich preview (zoom, PDF pages, AV transport) is a later enhancement. |
| First attach | Fileless Artifact may gain a primary File once (create-time in Add Artifact, or later **Add file…**). |
| No replace | **No “Replace file…”** on this board. A better scan = **Add Artifact** (new `ART-…`) under the same Source. Later: move/duplicate Citations onto the new Artifact (Interpretation). |
| Derivatives | Belong to the **File** (`file_derivatives`) and power things like list thumbnails. **Out of UI for this board:** do not list or invite interaction with derivatives under an expanded Artifact — researchers should only see the primary File. |
| Bytes | Never stage file bytes in UI models; pass a filesystem path to ingest; read via relative `objects/…` path. |

### 2.4 Association mechanism (engine)

- `CreateArtifact` — create fileless or with an existing `file_id`
- `IngestArtifactFile` — ingest from an absolute path and set the Artifact’s primary `file_id`

**Product rule:** ingest may run only when the Artifact is still **fileless**. S2-18 should **reject** ingest when `file_id` is already set (align engine + docs with this board). Design “Add file” only for the fileless empty state. Implementation may still need **thumbnail listing / ensure** for list cells (see §8 gaps).

### 2.5 Design system — new vs reuse

Tell Claude Design / engineering what is **shared chrome** vs **compose from existing**. Do not invent parallel controls when a built component already fits. Prefer the same reuse/hoist discipline as [`S2-04-sources-list.md`](S2-04-sources-list.md) §2.4.

#### Reuse (already built — compose, don’t redraw)

| Need on this board | Use |
| --- | --- |
| Add Artifact modal | `PVDialog` (same centered form-dialog pattern as Add Source) |
| Title / description / Artifact label | `PVField` + `PVInput` (always editable — no separate read-only mode) |
| Source type change | `PVSelect` or `PVComboBox` |
| Metadata field picker (D-5d) | `PVComboBox` (vocabulary pool) inside `PVDialog` or inline form |
| Primary / secondary actions | `PVButton` (use loading state for ingest) |
| Dismiss suggestion (X) | `PVIconButton` |
| Artifact list thumbnail | `PVThumbnail` (image / empty / loading — missing = placeholder, not error) |
| Empty Artifacts / empty Notes | `PVEmptyState` |
| Validation / ingest failures | `PVToast` (+ `PVField` inline errors) |
| Fileless / physical-only copy | `PVCallout` |
| Metadata data-type cues | `PVBadge` |
| Section hairlines | `PVDivider` |
| Mono `SRC-…` / `ART-…` | `PVFont.mono` (until a shared ref chip exists — see Hoist) |
| Workspace shell | Existing S2-01 chrome — **do not** redraw a second window |

**`PVList` caution:** today’s `PVList` is **navigate-on-activate** (Sources list → Source page). Artifact rows need **expand-in-place**. Reuse the **row visual language** (thumb + primary + mono meta), not that activation model — do not force accordion behavior into navigate-`PVList`.

#### Hoist (new design-system components)

Design these as reusable, not Source-page-only sketches:

| Piece | Why |
| --- | --- |
| **Breadcrumbs** (e.g. `PVBreadcrumbs`) | D-2 requires breadcrumb to Sources; already listed as missing in the macOS DS README. Files → Source and later Interpretation deep links will reuse it. **Not** a standalone back button. |
| **Disclosure / expandable list** (or a disclosure mode beside navigate-`PVList`) | Artifact accordion rows (D-9). Keep separate from navigate-`PVList` used by Sources / Files. |
| **File pick control** (path row + Choose… → `NSOpenPanel`) | Add Artifact modal **and** fileless **Add file…**. One AppKit wrapper; no one-off pickers per screen. |
| **Reorderable rows** (drag handle + drop) | Metadata order (D-5c); likely other ordered lists later. |
| **Ref chip** (optional but recommended) | Mono `SRC-…` / `ART-…` repeats on chrome, list rows, and expand — prefer a tiny shared chip over ad hoc mono `Text`. |
| **Page section header** (title + optional Add) | Notes / Metadata / Artifacts sections share the same rhythm. |

**Metadata:** hoist **primitives** (dismissible suggestion row, reorderable property row, field picker via `PVComboBox` + `PVDialog`). Do **not** invent a monolithic `PVSourceMetadataEditor` — the Source-specific mix of filled values + type suggestions + Add is feature composition.

**S2-18 priority (engineering):** (1) breadcrumbs, (2) file pick control, (3) disclosure list, (4) reorderable rows — Metadata order depends on (4).

#### Leave out of the design system for now (feature-owned)

- Source page layout composition (identity + notes + metadata + artifacts as one page).
- Source identity header assembly (title + type + ref under breadcrumb).
- **Notes stream** UI (multi-entry commentary timeline) — wait for a second notes-like surface before hoisting.
- Expanded Artifact body (label/description editors + primary File identity + open-externally affordance + fileless CTA).
- Ingest busy gating / duplicate-submit disable (model + `PVButton` loading).
- List ↔ Source page navigation host (app navigation, not a component).

---

## 3. Requirements

### 3.1 Navigation / page chrome

| ID | Requirement |
| --- | --- |
| D-1 | This is a **separate page** from the Sources list — full content-host takeover (or equivalent push), **not** a split pane beside the list and **not** in-list expand. |
| D-2 | **Breadcrumb** navigation back to the Sources list (S2-04) — not a standalone back button. |
| D-3 | Show Source identity in the page chrome: `SRC-…`, type, title. |
| D-3a | This page assumes an existing Source (`GetSourceWorkspace`). Do **not** design a create/draft state here — Add Source is S2-04’s dialog. |

### 3.2 Source body

| ID | Requirement |
| --- | --- |
| D-4 | **Title** (required, non-empty) and **description** (optional) are editable in place (view = edit). Empty title must fail validation — same rule as the Add Source dialog. |
| D-5 | **Notes** are a **distinct** page area: multi-entry stream (add/edit/delete). Not combined visually with Metadata. Keep layout one composition with the rest of the page, not a dashboard of cards. |
| D-5a | **Metadata** is a **distinct** page area: show **all** associated `source_metadata` values for this Source. Not the same UI as Notes. |
| D-5b | **Type suggestions:** for fields suggested by the Source’s type that are not yet filled, show them as empty/suggested rows (especially useful right after create). Filling is a **quick add** — enter a value and save in place. Each suggestion has a dismiss control (e.g. **X**). Dismiss is **permanent and persistent** for this Source — dismissed suggestions must not reappear after reload. |
| D-5c | Metadata rows (filled values and, while visible, suggestions) are **user-orderable** via drag (or equivalent reorder affordance). Order is persisted. |
| D-5d | Separate **Add** control (not the suggestions): open a picker of **all** available `source_metadata_fields`, choose a field, enter a value, and save. Distinct from accepting a type suggestion. |
| D-6 | No delete Source in this spike (omit or defer). |

### 3.3 Artifacts on the Source

| ID | Requirement |
| --- | --- |
| D-7 | List **all Artifacts** for this Source: each row shows **thumbnail** (of the primary File when present; else placeholder), **`label`** (primary text), and **`ART-…`**. |
| D-8 | **Add Artifact** from this page — same centered modal pattern as Add Source; combined form can also attach a File (fileless still OK if the researcher skips the file step). |
| D-9 | Expanding an Artifact row shows Artifact + File detail **in place** on this page (accordion / disclosure). **No** separate Artifact page and **no** further navigation push. Do not bounce back to the Sources list. |

### 3.4 Artifact detail

| ID | Requirement |
| --- | --- |
| D-10 | Show `ART-…` + editable **`label`** (required) + **description** (optional). |
| D-11 | Show the **primary File** when present: filename, media type, size. Activating it (**click / Open**) opens the file in an **outside app** via the system default handler (`NSWorkspace` on the `objects/…` URL). Do **not** design an in-app preview window for this board. |
| D-12 | Do **not** show a derivatives list or related-generated-files UI under the Artifact. Thumbnail for the collapsed row may still come from a derivative behind the scenes. |
| D-13 | Fileless empty state: explain physical-only; CTA to **Add file…** (first attach / ingest only). |
| D-14 | If a primary File **already exists**, show it read-only for identity (filename / type / size) plus the external-open affordance. **No Replace file…** — annotate that a newer scan is a **new Artifact**; Citation remapping is later (Interpretation). |
| D-15 | No multi-primary-file attach UI. Extra / clearer scans = **Add Artifact**. |

### 3.5 Add flows

| ID | Requirement |
| --- | --- |
| D-16 | **Add Artifact** uses the **same centered dimming modal pattern** as Add Source (S2-04 / confirm-dialog chrome — not an inspector or full page). One combined form: required **label**, optional description, **and** optional File pick/ingest (researchers usually do both together). Skipping the file leaves a fileless Artifact. |
| D-17 | **Add file…** on a **fileless** Artifact only (expanded row): NSOpenPanel-style pick → path to ingest; show progress/errors calmly. Distinct from D-16’s create-time file step. Never offered when a primary File is already set. |

### 3.6 Errors and feedback

| ID | Requirement |
| --- | --- |
| D-18 | Validation / ingest failures use toast or inline patterns consistent with onboarding. |
| D-19 | Busy states disable duplicate submits; ingest may take noticeable time. |
| D-20 | Missing Artifact-row thumbnail (fileless or no derivative yet) is a placeholder, not an error. |

---

## 4. Suggested mock content

- One Source with two Artifacts (two scans) + one fileless Artifact.
- One Artifact expanded showing the primary File only (no derivatives list).
- Source with zero Artifacts + Add Artifact.
- Notes stream + Metadata area with filled values, dismissible quick-add suggestions, **Add** field picker, and reorder.
- Breadcrumb to the Sources list annotated.

---

## 5. Screen / frame inventory (minimum)

1. **Source page** — identity + description + notes + metadata + Artifacts list (collapsed and one row expanded).
2. **Add Artifact** modal (same pattern as Add Source: label + optional description + optional File).
3. **Expanded Artifact row** — label + description + primary File only (same page as #1; not a separate destination; no derivatives list).
4. **Add file…** on a fileless Artifact (picker → success; optional failure). **No** replace-file frame.
5. Annotation of **breadcrumb** to the Sources list (only page-level navigation in this flow).

---

## 6. Out of scope

- Redesigning the Sources **list** or **Add Source** dialog (S2-04) — only the entry/exit from the list.
- Create/draft mode for a not-yet-persisted Source (that is the S2-04 dialog).
- Deleting Sources, Artifacts, or primary Files.
- **Replace file** / pointer-swap of an Artifact’s primary File (better scan = new Artifact; Citation move/duplicate later).
- **In-app File preview** (Quick Look embed, PDFKit/AVKit zoom/transport, universal preview window) — MVP is **open in external app** only; rich in-app preview can come later (likely a hoistable DS piece shared with Files).
- Orphan File GC / historical File version browser.
- Interpretation (citations, people); credibility grades; Citation remapping across Artifacts.
- Creating types/fields here (link to S2-02 / S2-03 destinations OK).
- Project-wide Files browser (S2-20).
- Surfacing File **derivatives** as user-visible objects under an Artifact (thumbnails may still use them internally).

---

## 7. Acceptance checklist

- [ ] Separate Source page with **breadcrumb** to list — not master–detail with the list; **no create mode**; **no** standalone back button.
- [ ] **Notes** as a distinct stream area (add/edit/delete).
- [ ] **Metadata** as a distinct area: all associated values; type suggestions as **quick add** with **persistent dismiss**; separate **Add** (vocabulary picker → value → save); **drag reorder**.
- [ ] Artifacts sublist with **thumbnail** (primary File), **`label`**, `ART-…`.
- [ ] Artifact expand is in-place accordion (label + description + **primary File only**); activating the File **opens it externally**; **no** in-app preview; **no** derivatives list.
- [ ] **Add Artifact** centered modal (same pattern as Add Source: label + optional file); **Add file…** only when fileless; **no** Replace file.
- [ ] No second app chrome; bytes not in models.

---

## 8. Implementation notes (for PRs — not Design homework)

| Gap | Status |
| --- | --- |
| Artifact ↔ File association | **Exists:** `CreateArtifact`, `IngestArtifactFile`. |
| No primary-File replace | **Product rule change.** Today ingest can pointer-swap `file_id`. **S2-18 must:** reject `IngestArtifactFile` when Artifact already has a File; update [`source-layer-data-model.md`](../../../source-layer-data-model.md) (and related notes) so better scans = **new Artifact**, not replace; keep first-attach (NULL → File) only. |
| Artifact `label` column | **Schema gap today** (`artifacts` has only `description`). **S2-18 must add** `label` (migration + query/FFI/proto) **before** shipping the Source page UI that depends on it. |
| Per-Source suggestion dismiss | **Schema gap:** type suggestions live on `source_type_metadata_fields` only — no per-Source dismiss store. **S2-18 must add** persistent dismiss (e.g. `source_metadata_suggestion_dismissals` or equivalent) + FFI. |
| Metadata display order | **Schema gap:** `source_metadata` has no `sort_order` (type-join order is not per-Source). **S2-18 must add** `sort_order` (or equivalent) on Source metadata + reorder FFI. |
| List / workspace thumbnail refs | Likely **FFI gap:** ensure/list derivative paths for list cells — fold into S2-18 (or a thin precede PR). |
| Open primary File | **MVP:** Swift opens the `objects/…` URL with **`NSWorkspace`** (default app). No in-app preview in S2-18. |
| Sources list | Shipped earlier as S2-17 from S2-04; this board feeds S2-18 only. |
