# S2-23 — Source page (Artifacts + Files)

**Kind:** Claude Design board  
**Spike:** Provenencia Spike 2 (Source layer validation)  
**Implements later as:** PR S2-18  
**Depends on:** S2-01 workspace chrome (done); S2-04 Sources list (how researchers arrive here); S2-02 / S2-03 vocabulary (metadata editor + type display)  
**Related briefs:** [`S2-04-sources-list.md`](S2-04-sources-list.md), [`S2-02-source-fields.md`](S2-02-source-fields.md), [`S2-03-source-types.md`](S2-03-source-types.md), [`S2-20-files-list.md`](S2-20-files-list.md)

Paste this entire document into Claude Design as the requirements for one board/flow.

---

## 1. Objective

Design the **individual Source page** — a separate destination from the Sources list (S2-04), not a master–detail pane beside that list. Researchers open it by selecting a list row, or after **Add Source** succeeds (create dialog lives on S2-04). This page is **view/edit only** for an already-persisted Source: always-editable identity fields, notes, metadata, the Artifacts tree, and File ingest/replace. **No create/draft mode** on this board.

```text
Sources list (S2-04)
  ├─ Add Source dialog → Create
  └─ select row
         └─ Source page (this board) — view/edit
              ├─ identity + description + notes + metadata (editable)
              └─ Artifacts
                   └─ Artifact detail
                        └─ primary File + its derivatives (e.g. thumbnail)
```

Include **add flows** on this page: add Artifact; attach/ingest or replace a File on an Artifact. Assume S2-01 chrome. **Do not redraw a second window shell.** Do **not** redesign the Sources list or the Add Source dialog — only how this page is reached (back / breadcrumb to the list).

---

## 2. Domain model (UI must reflect)

Authoritative: [`source-layer-data-model.md`](../../../source-layer-data-model.md) §§4, 6–8; stack rules for ingest (bytes never in protobuf).

### 2.1 Source

| Field / concept | UI implication |
| --- | --- |
| `title` | Editable on this page; primary headline. Same control for view and edit — no separate read-only mode. |
| `ref` (`SRC-…`) | Always visible; mono; not editable (minted at create). |
| Type (`source_types.label`) | Show type **name**; allow changing type after create unless Design explicitly locks it for this spike. |
| `description` | Catalog text about the Source — editable on this page (same as title: always editable). |
| Notes / metadata | Notes = multi-entry commentary; metadata = suggested + extra fields from vocabulary. Keep secondary to the evidence tree if the board gets crowded, but do not omit. |

### 2.2 Artifact

| Field / concept | UI implication |
| --- | --- |
| `ref` (`ART-…`) | Always visible; mono; not editable. |
| **No `label` column** | There is no separate Artifact label in the schema. List display should use a calm fallback: short **description** snippet, else primary File `original_filename`, else `ART-…` alone. Do not invent a fake label field. |
| `description` | Shown when the Artifact is expanded / opened. |
| `file_id` | **Zero or one** primary File. Fileless Artifacts are valid (physical-only). |
| Multiple scans | **Multiple Artifacts** under one Source — not one Artifact with many primary Files. |

### 2.3 File + derivatives

| Rule | UI implication |
| --- | --- |
| Primary File | Immutable content-addressed object; show filename / media type / size when present. |
| Replace scan | Ingest new bytes → new File → Artifact pointer updates; old File retained. UX = “Add file…” / “Replace file…”, not multi-file attach. |
| Derivatives | Belong to the **File** (`file_derivatives`), not to the Artifact. Under an Artifact, show the primary File and list its derivatives (e.g. thumbnail) as related generated files — not as sibling Artifacts. |
| Bytes | Never stage file bytes in UI models; pass a filesystem path to ingest; read via relative `objects/…` path. |

### 2.4 Association mechanism (already in engine)

Associating a File with an Artifact is **not missing** at the domain/FFI layer:

- `CreateArtifact` — create fileless or with an existing `file_id`
- `IngestArtifactFile` — ingest from an absolute path and set/replace the Artifact’s primary `file_id`

Design “Add file” against that model. Implementation may still need **thumbnail listing / ensure** exposed for list cells (see §8 gaps).

---

## 3. Requirements

### 3.1 Navigation / page chrome

| ID | Requirement |
| --- | --- |
| D-1 | This is a **separate page** from the Sources list — full content-host takeover (or equivalent push), **not** a split pane beside the list and **not** in-list expand. |
| D-2 | Clear **back** (or breadcrumb) to the Sources list (S2-04). |
| D-3 | Show Source identity in the page chrome: `SRC-…`, type, title. |
| D-3a | This page assumes an existing Source (`GetSourceWorkspace`). Do **not** design a create/draft state here — Add Source is S2-04’s dialog. |

### 3.2 Source body

| ID | Requirement |
| --- | --- |
| D-4 | **Title** and **description** are editable in place (view = edit). |
| D-5 | Notes list (add/edit/delete note) and metadata editor (type suggestions + extras) belong on this page — keep layout one composition, not a dashboard of cards. |
| D-6 | No delete Source in this spike (omit or defer). |

### 3.3 Artifacts on the Source

| ID | Requirement |
| --- | --- |
| D-7 | List **all Artifacts** for this Source: each row shows **`ART-…`**, display name fallback (§2.2), and **thumbnail** slot. |
| D-8 | **Add Artifact** from this page (fileless OK). |
| D-9 | Opening an Artifact shows Artifact detail **within this Source page stack** (nested expand or further push — Design picks; document it). Do not bounce back to the Sources list. |

### 3.4 Artifact detail

| ID | Requirement |
| --- | --- |
| D-10 | Show `ART-…` + **description** (editable). |
| D-11 | Show the **primary File** when present: filename, media type, size; affordance to open/preview when practical. |
| D-12 | Show **derivatives** of that primary File (at least thumbnail when present) as a sub-list or related files — labeled as generated, not as separate Artifacts. |
| D-13 | Fileless empty state: explain physical-only; CTA to **Add file…** (ingest). |
| D-14 | If a primary File already exists, **Replace file…** uses the same ingest path (pointer update). |
| D-15 | No multi-primary-file attach UI. Extra scans = add another Artifact. |

### 3.5 Add flows

| ID | Requirement |
| --- | --- |
| D-16 | **Add Artifact:** under current Source; description optional; may start fileless. |
| D-17 | **Add / replace File:** NSOpenPanel-style pick → path to ingest; show progress/errors calmly. |

### 3.6 Errors and feedback

| ID | Requirement |
| --- | --- |
| D-18 | Validation / ingest failures use toast or inline patterns consistent with onboarding. |
| D-19 | Busy states disable duplicate submits; ingest may take noticeable time. |
| D-20 | Missing thumbnail is a placeholder, not an error. |

---

## 4. Suggested mock content

- One Source with two Artifacts (two scans) + one fileless Artifact.
- One Artifact expanded showing primary File + thumbnail derivative.
- Source with zero Artifacts + Add Artifact.
- Notes + a couple of metadata fields filled; one empty suggested field.
- Back affordance to the Sources list annotated.

---

## 5. Screen / frame inventory (minimum)

1. **Source page** — identity + description + Artifacts list (+ notes/metadata placement).
2. **Add Artifact** flow.
3. **Artifact detail** — description + primary File + derivatives.
4. **Add / replace File** (picker → success; optional failure).
5. Annotation of nested Artifact navigation **within** the Source page (and back to the Sources list).

---

## 6. Out of scope

- Redesigning the Sources **list** or **Add Source** dialog (S2-04) — only the entry/exit from the list.
- Create/draft mode for a not-yet-persisted Source (that is the S2-04 dialog).
- Deleting Sources, Artifacts, or primary Files.
- Orphan File GC / historical File version browser beyond “replace keeps old bytes.”
- Interpretation (citations, people); credibility grades.
- Creating types/fields here (link to S2-02 / S2-03 destinations OK).
- Project-wide Files browser (S2-20).

---

## 7. Acceptance checklist

- [ ] Separate Source page with back to list — not master–detail with the list; **no create mode**.
- [ ] Source: editable title/description + notes + metadata; Artifacts sublist with `ART-…`, display fallback, thumbnail.
- [ ] Artifact detail: description + primary File + derivatives (not multi-primary-file).
- [ ] Add Artifact / Add-or-replace File flows present.
- [ ] Nested Artifact nav pattern explicitly chosen on the board.
- [ ] No second app chrome; bytes not in models.

---

## 8. Implementation notes (for PRs — not Design homework)

| Gap | Status |
| --- | --- |
| Artifact ↔ File association | **Exists:** `CreateArtifact`, `IngestArtifactFile`. |
| List / workspace thumbnail refs | Likely **FFI gap:** ensure/list derivative paths for list cells — fold into S2-18 (or a thin precede PR). |
| Artifact “label” | **No column** — UI fallback only. |
| Sources list | Shipped earlier as S2-17 from S2-04; this board feeds S2-18 only. |
