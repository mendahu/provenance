# S2-04 — Sources list

**Kind:** Claude Design board  
**Spike:** Provenencia Spike 2 (Source layer validation)  
**Implements later as:** PR S2-17  
**Depends on:** S2-01 workspace chrome (done); S2-02 / S2-03 vocabulary (types exist to classify Sources; fields not edited on this board)  
**Related briefs:** [`S2-02-source-fields.md`](S2-02-source-fields.md), [`S2-03-source-types.md`](S2-03-source-types.md), [`S2-23-source-detail.md`](S2-23-source-detail.md), [`S2-20-files-list.md`](S2-20-files-list.md)

Paste this entire document into Claude Design as the requirements for one board/flow.

---

## 1. Objective

Design the **Sources** destination **list** — the browse surface researchers land on from the sidebar. Rows identify Sources and open a **separate Source page** (S2-23), not a master–detail split in the same pane the way Source types / Source fields do.

**Presentation is locked:** this is an **evidence list**, not a vocabulary table. Do **not** use **`PVTable`** (that stays for Source fields / Source types). Design a **new list-style component** (or board pattern that implies one): homogeneous rows with a leading thumbnail, primary title, and secondary meta — Finder/Mail density, not spreadsheet columns.

```text
Sources list
  ├─ select row ────────────────────────────────────────►  Source page (S2-23)
  └─ Add Source → centered dialog → Create ─────────────►  Source page (S2-23)
```

Include the **Add Source** create chrome (lightweight dialog — not the full Source page) and empty state. Assume S2-01 chrome. **Do not redraw a second window shell.** Do **not** design the Source page, Artifacts, or File ingest on this board — annotate that Create (and row select) navigate away to that separate page.

---

## 2. Domain model (UI must reflect)

Authoritative: [`source-layer-data-model.md`](../../../../../source-layer-data-model.md) §§4, 6–8 (list-facing fields only).

### 2.1 Source (list row)

| Field / concept | UI implication |
| --- | --- |
| `title` | Required primary list headline (non-empty). |
| `ref` (`SRC-…`) | Always visible on the row; mono; not editable. |
| Type (`source_types.label`) | Show type **name** on the row; Add Source picker uses S2-03 vocabulary. |
| List thumbnail | **Derived from child data** (typically a thumbnail of an Artifact’s primary File). Reserve a consistent thumbnail slot even when missing (placeholder). Real thumbnail bytes may land in S2-18 — Design still shows the slot. |
| `description`, notes, metadata | **Not** on the list row — those belong on the Source page (S2-23). |

### 2.2 What this destination is not

- Not a master–detail split with Source detail beside or under the list (unlike S2-02 / S2-03).
- Not a **`PVTable`** / columnar admin list (unlike Source fields / Source types).
- Not Artifacts, primary Files, derivatives, or ingest.
- Not vocabulary admin (link to Source types / fields destinations OK).

### 2.3 List chrome (locked)

| Rule | UI implication |
| --- | --- |
| Component | **New list-style component** in the design system (name TBD in implementation — e.g. `PVList` / media list). Homogeneous row template for every Source. |
| Not `PVTable` | No column headers, no multi-column grid, no spreadsheet sort-by-header chrome. Vocabulary keeps `PVTable`; Sources does not. |
| Row skeleton | Leading **thumbnail** (or placeholder) → **title** (primary) → secondary line or trailing meta for **type** + **`SRC-…`**. Same structure every row. |
| Density | Calm list / document browser — not cards, not a dashboard of tiles. Shared row height; hairline separators OK. |
| Sort (optional) | If sorting exists, use a toolbar/menu control — not clickable table headers. |

### 2.4 Design system — new vs reuse

Tell Claude Design / engineering what is **shared chrome** vs **compose from existing**. Do not invent parallel controls when a built component already fits.

#### Hoist (new design-system components)

These are first-class DS work — design them as reusable, not Sources-only sketches:

| Piece | Why |
| --- | --- |
| **List** (e.g. `PVList`) | Evidence browse shell: homogeneous rows, selection/hover, keyboard. Files (and later similar browsers) reuse it. **Not** `PVTable`. |
| **Thumbnail** (e.g. `PVThumbnail`) | Fixed tile: image or placeholder, shared size/radius. Sources rows now; Artifacts / Files next. Missing image = placeholder, not error. |
| **Form dialog** (extend confirm / e.g. `PVDialog`) | Add Source needs **fields** inside centered dimming chrome. `PVConfirm` today is copy + actions (delete-style). Reuse that **presentation**; add a content slot for short forms so every “Add …” does not fork a one-off modal. |

#### Reuse (already built — compose, don’t redraw)

| Need on this board | Use |
| --- | --- |
| Search | `PVInput` (same list-search pattern as vocabulary panes) |
| Empty / no matches | `PVEmptyState` |
| Type picker | `PVSelect` or `PVComboBox` |
| Title / description fields | `PVField` + `PVInput` |
| Primary / secondary actions | `PVButton` |
| Validation / success feedback | `PVToast` (or inline field errors) |
| Mono `SRC-…` | `PVFont.mono` (optional tiny shared ref chip later if it keeps repeating — not required for this board) |

#### Leave out of the design system for now

- Source-specific list row composition (title + type + ref) — feature logic.
- “Navigate to Source page” wiring — app navigation, not a component.
- Full Source page / Artifact chrome — **S2-23**.

---

## 3. Requirements

### 3.1 Sources list

| ID | Requirement |
| --- | --- |
| S-1 | List Sources in the **Sources** content host using the **list-style** pattern (§2.3) — **not** `PVTable`. |
| S-2 | Each row shows **title**, **`SRC-…`**, and **source type name** in the homogeneous skeleton (thumb + primary + meta). |
| S-3 | Each row reserves a **thumbnail** slot (image or placeholder) derived from child Artifact/File data when available. |
| S-4 | Search/filter recommended (title / ref / type). |
| S-5 | Empty state + primary **Add Source** CTA. |
| S-6 | Selecting a row **navigates to a separate Source page** (push / replace content — not in-list expand, not a side-by-side detail pane). Document that pattern on the board; the destination page itself is S2-23. |
| S-6a | Board must show the **new list component** clearly enough that engineering can extract it (row anatomy, selected/hover, empty, with/without thumb) — not a one-off Sources-only sketch that cannot become shared chrome. |

### 3.2 Add Source

Create is a **thin** `CreateSource` payload (type + **required** title + optional description). Do **not** open the full Source page in a draft/create mode — that page is view/edit only (S2-23).

| ID | Requirement |
| --- | --- |
| S-7 | **Add Source** opens a **centered, dimming dialog** — same presentation family as Source fields/types **confirm** dialogs (`PVConfirm` / dialog chrome): modal to the window, parent dimmed, short panel in the center. **Not** a trailing inspector, **not** an in-list draft pane, **not** a second full page. |
| S-8 | Form fields: **type** (required), **title** (required, non-empty), **description** (optional). No notes, metadata, Artifacts, or file pickers here. |
| S-9 | Type picker uses existing Source types vocabulary (S2-03); do not create types inline on this board. |
| S-10 | Primary action **Create** calls create, dismisses the dialog, and **navigates to the new Source page** (S2-23) where `SRC-…` and further editing live. Cancel dismisses without navigating. |

### 3.3 Errors and feedback

| ID | Requirement |
| --- | --- |
| S-11 | Validation failures use toast or inline patterns consistent with onboarding. |
| S-12 | Busy states disable duplicate submits. |
| S-13 | Missing thumbnail is a placeholder, not an error. |

---

## 4. Suggested mock content

- Several Sources mixed types (Photograph, Book, custom), each with a real title.
- Empty Sources list + Add Source.
- **Add Source** dialog (centered, dimmed parent): type + title + description; Create → annotate navigation to Source page.
- One row with a real-looking thumbnail; one with placeholder only.
- Annotation: row selection → separate Source page (stub frame OK; full page is S2-23).

---

## 5. Screen / frame inventory (minimum)

1. Sources **list** (list component: thumbnails, title, ref, type) — not a table.
2. Sources **empty** + Add Source.
3. **Add Source** dialog (type, title, description; Create / Cancel) — confirm-dialog chrome.
4. Annotation: Create and row select both go to the **separate Source page** (do not invent master–detail or create-mode on that page here).

---

## 6. Out of scope

- Source page layout (editable title/description, notes, metadata, Artifacts) — **S2-23**.
- Using the Source page itself as the create form — create stays in this board’s dialog.
- Trailing inspector / slide-over create chrome.
- Reusing or extending **`PVTable`** for this destination.
- Artifact detail, File ingest (first attach / Add Artifact), derivatives — **S2-23** / PR S2-18.
- Deleting Sources.
- Interpretation (citations, people); credibility grades.
- Creating types/fields here (link to S2-02 / S2-03 destinations OK).

---

## 7. Acceptance checklist

- [ ] Sources list uses **list-style** rows (thumb + title + type/`SRC-…`) — **not** `PVTable` / column headers.
- [ ] Board implies a **reusable list component** (row anatomy documented), not only a Sources one-off.
- [ ] Thumbnail and form-dialog chrome read as **shared** DS pieces; search/empty/fields/buttons reuse existing components.
- [ ] Empty + **Add Source** centered dimming dialog (type + title required; description optional).
- [ ] Dialog chrome matches confirm-dialog presentation (not inspector / not full-page create).
- [ ] Create navigates to the Source page; Cancel stays on the list.
- [ ] Navigation is explicitly **separate page**, not master–detail / in-list expand.
- [ ] No Source page, Artifact, or File chrome designed on this board.
- [ ] No second app chrome.

---

## 8. Implementation notes (for PRs — not Design homework)

| Gap | Status |
| --- | --- |
| List chrome | Ship a **new design-system list component** (S2-17); do **not** mount Sources on `PVTable`. Files (S2-20/S2-21) may reuse the same list later. |
| Thumbnail | Ship a **shared thumbnail** tile with placeholder; don’t inline ad-hoc `Image` framing per feature. |
| Add Source chrome | **Form dialog** sharing confirm-dialog presentation (`PVConfirm` family / `PVDialog`); fields via existing `PVField`/`PVInput`/`PVSelect`/`PVComboBox`. Do not invent a parallel modal system. |
| List thumbnail refs | Likely **FFI gap:** ensure/list derivative paths for list cells — fold into S2-18 (or a thin precede PR). Placeholder OK in S2-17. |
| Source page | Designed in S2-23; shipped in S2-18 (S2-17 may stub navigation). |
