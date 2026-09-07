# S2-04 — Sources catalog (list → Source → Artifact → File)

**Kind:** Claude Design board  
**Spike:** Provenencia Spike 2 (Source layer validation)  
**Implements later as:** PRs S2-17 (Sources list + Source detail), S2-18 (Artifact detail + file ingest + thumbnails)  
**Depends on:** S2-01 workspace chrome (done); S2-02 / S2-03 vocabulary (types + fields exist to classify and describe Sources)  
**Related briefs:** [`S2-02-source-fields.md`](S2-02-source-fields.md), [`S2-03-source-types.md`](S2-03-source-types.md), [`S2-20-files-list.md`](S2-20-files-list.md)

Paste this entire document into Claude Design as the requirements for one board/flow.

---

## 1. Objective

Design the **Sources** destination — the most complex Spike 2 surface. Three nested layers of evidence:

```text
Sources list
  └─ Source detail
       └─ Artifacts list
            └─ Artifact detail
                 └─ primary File + its derivatives (e.g. thumbnail)
```

Include **add flows** at each layer: create Source; add Artifact under a Source; attach/ingest a File on an Artifact. Assume S2-01 chrome. **Do not redraw a second window shell.**

---

## 2. Domain model (UI must reflect)

Authoritative: [`source-layer-data-model.md`](../../../source-layer-data-model.md) §§4, 6–8; stack rules for ingest (bytes never in protobuf).

### 2.1 Source

| Field / concept | UI implication |
| --- | --- |
| `title` | Primary list headline (fallback when empty: type label + `SRC-…`). |
| `ref` (`SRC-…`) | Always visible on list + detail; mono; not editable. |
| Type (`source_types.label`) | Show type **name** on list and detail; picker uses S2-03 vocabulary. |
| `description` | Catalog text about the Source — **detail only**. |
| Notes / metadata | Part of Source detail (workspace already models them). Notes = multi-entry commentary; metadata = suggested + extra fields from vocabulary. Keep secondary to the evidence tree if the board gets crowded, but do not omit. |
| List thumbnail | **Derived from child data** (typically a thumbnail of an Artifact’s primary File). Reserve a consistent thumbnail slot even when missing (placeholder). |

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

### 3.1 Sources list

| ID | Requirement |
| --- | --- |
| C-1 | List Sources in the **Sources** content host. |
| C-2 | Each row shows **title** (or fallback), **`SRC-…`**, and **source type name**. |
| C-3 | Each row reserves a **thumbnail** slot (image or placeholder) derived from child Artifact/File data when available. |
| C-4 | Search/filter recommended (title / ref / type). |
| C-5 | Empty state + primary **Add Source** CTA. |
| C-6 | Selecting / expanding a row opens Source detail (pattern open — see C-20). |

### 3.2 Source detail

| ID | Requirement |
| --- | --- |
| C-7 | Show identity: `SRC-…`, type, title; **description** editable. |
| C-8 | List **all Artifacts** for this Source: each row shows **`ART-…`**, display name fallback (§2.2), and **thumbnail** slot. |
| C-9 | **Add Artifact** from Source detail (fileless OK). |
| C-10 | Notes list (add/edit/delete note) and metadata editor (type suggestions + extras) belong on Source detail — keep layout one composition, not a dashboard of cards. |
| C-11 | No delete Source in this spike (omit or defer). |

### 3.3 Artifact detail (nested)

| ID | Requirement |
| --- | --- |
| C-12 | Show `ART-…` + **description** (editable). |
| C-13 | Show the **primary File** when present: filename, media type, size; affordance to open/preview when practical. |
| C-14 | Show **derivatives** of that primary File (at least thumbnail when present) as a sub-list or related files — labeled as generated, not as separate Artifacts. |
| C-15 | Fileless empty state: explain physical-only; CTA to **Add file…** (ingest). |
| C-16 | If a primary File already exists, **Replace file…** uses the same ingest path (pointer update). |
| C-17 | No multi-primary-file attach UI. Extra scans = add another Artifact. |

### 3.4 Add flows

| ID | Requirement |
| --- | --- |
| C-18 | **Add Source:** type (required), title (optional), optional description; land on new Source with minted `SRC-…`. |
| C-19 | **Add Artifact:** under current Source; description optional; may start fileless. |
| C-20 | **Add / replace File:** NSOpenPanel-style pick → path to ingest; show progress/errors calmly. |
| C-21 | **Navigation pattern is open** at each level: in-list expand vs push + breadcrumb/back. Three levels deep — Design should pick what stays scannable on macOS and document it. Consistency with S2-03’s choice is nice but not mandatory if Sources need a deeper stack. |

### 3.5 Errors and feedback

| ID | Requirement |
| --- | --- |
| C-22 | Validation / ingest failures use toast or inline patterns consistent with onboarding. |
| C-23 | Busy states disable duplicate submits; ingest may take noticeable time. |
| C-24 | Missing thumbnail is a placeholder, not an error. |

---

## 4. Suggested mock content

- Several Sources mixed types (Photograph, Book, custom), one untitled fallback.
- One Source with two Artifacts (two scans) + one fileless Artifact.
- One Artifact expanded showing primary File + thumbnail derivative.
- Empty Sources list; Source with zero Artifacts.

---

## 5. Screen / frame inventory (minimum)

1. Sources **list** with thumbnails, title, ref, type.
2. Sources **empty** + Add Source.
3. **Add Source** flow.
4. **Source detail** — description + Artifacts list (+ notes/metadata placement).
5. **Add Artifact** flow.
6. **Artifact detail** — description + primary File + derivatives.
7. **Add / replace File** (picker → success; optional failure).
8. Annotation of navigation pattern (expand vs breadcrumb) across the three levels.

---

## 6. Out of scope

- Deleting Sources, Artifacts, or primary Files.
- Orphan File GC / historical File version browser beyond “replace keeps old bytes.”
- Interpretation (citations, people).
- Credibility grades.
- Creating types/fields here (link to S2-02 / S2-03 destinations OK).

---

## 7. Acceptance checklist

- [ ] Sources list: title, `SRC-…`, type name, thumbnail slot.
- [ ] Source detail: description + Artifacts sublist with `ART-…`, display fallback, thumbnail.
- [ ] Artifact detail: description + primary File + derivatives (not multi-primary-file).
- [ ] Add Source / Add Artifact / Add-or-replace File flows present.
- [ ] Three-level nav pattern explicitly chosen on the board.
- [ ] No second app chrome; bytes not in models.

---

## 8. Implementation notes (for PRs — not Design homework)

| Gap | Status |
| --- | --- |
| Artifact ↔ File association | **Exists:** `CreateArtifact`, `IngestArtifactFile`. |
| List / workspace thumbnail refs | Likely **FFI gap:** ensure/list derivative paths for list cells — fold into S2-18 (or a thin precede PR). |
| Artifact “label” | **No column** — UI fallback only. |
