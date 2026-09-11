# S2-20 — Files list (project file browser)

**Kind:** Claude Design board  
**Spike:** Provenencia Spike 2 (Source layer validation)  
**Implements later as:** PR S2-21  
**Depends on:** S2-01 workspace chrome (done — **Files** destination already shipped as a placeholder); S2-23 Source page (link target for “open Source”)  
**Related briefs:** [`archive/S2-04-sources-list.md`](archive/S2-04-sources-list.md), [`archive/S2-23-source-detail.md`](archive/S2-23-source-detail.md)

Paste this entire document into Claude Design as the requirements for one board/flow.

---

## 1. Objective

Design the **Files** destination: a simple project-wide list of Files with enough identity to scan, plus a link to the **Source** each File is currently associated with (via its Artifact). This is the lightest of the four feature boards — browse and navigate, not a second ingest surface.

Assume S2-01 chrome. **Do not redraw a second window shell.** Mount in the existing **Files** sidebar destination.

---

## 2. Domain model (UI must reflect)

Authoritative: [`source-layer-data-model.md`](../../../source-layer-data-model.md) §§6–8.

### 2.1 `files`

| Field / concept | UI implication |
| --- | --- |
| `original_filename` | Primary text on the row when present. |
| `media_type` | Show on the row (e.g. `image/jpeg`, `application/pdf`). |
| Thumbnail | From `file_derivatives` (thumbnail of **this** File). Placeholder when missing / non-image. |
| Association | File ↔ Source is **indirect**: `artifacts.file_id` → `artifacts.source_id`. Surface a link to that Source (`SRC-…` and/or title). |
| Immutability | No edit-in-place of bytes; no delete in this spike. |

### 2.2 What to list

Prefer listing Files that are (or were) **primary Artifact files** — the researcher’s scans/documents — not every generated derivative row as a peer.

| Rule | UI implication |
| --- | --- |
| Derivative-only rows | Do **not** list a File whose only role is `file_derivatives.derived_file_id` as its own list row (those appear as the thumbnail column on their source File). |
| Orphans | A File whose Artifact pointer was later replaced may still exist with **no** current Source link — show the row; disable or omit the Source link calmly (optional caption: not currently attached). |
| Multiple Artifacts | Unusual for one `file_id`; if it happens, link to one Source clearly or list associations — prefer simplest: one primary Source link. |

### 2.3 Not this destination

- Not ingest / replace (that lives under Source → Artifact on the Source page, S2-23).
- Not Artifact detail.
- Not File byte management / GC / delete.

---

## 3. Requirements

### 3.1 List (Files destination)

| ID | Requirement |
| --- | --- |
| L-1 | List project Files inside the S2-01 **Files** content host. |
| L-2 | Each row shows **thumbnail** (or placeholder), **media type**, and **original filename** (fallback if null: short checksum / “Untitled file”). |
| L-3 | Each row includes a **link to the associated Source** when one exists (navigate to that Source’s **separate page** — match S2-23 navigation). |
| L-4 | Search/filter by filename (and optionally media type) recommended. |
| L-5 | Empty state when the project has no listable Files — calm copy; no forced ingest CTA here (ingest remains under Sources). |
| L-6 | No delete; no multi-select bulk actions required. |

### 3.2 Navigation and feedback

| ID | Requirement |
| --- | --- |
| L-7 | Activating the Source link switches context to that Source (sidebar may move to **Sources**; deep-link into the Source page per S2-23). |
| L-8 | Missing thumbnail / missing Source link are non-errors (placeholder / muted affordance). |
| L-9 | Optional: opening the File itself (Quick Look / reveal) is nice-to-have, not required for this board. |

---

## 4. Suggested mock content

- Mixed images and a PDF; one row without thumbnail placeholder.
- Rows with Source links (`SRC-…` + title).
- One orphan row without a Source link (replaced scan).

---

## 5. Screen / frame inventory (minimum)

1. Files **list** with thumbnail, media type, original filename, Source link.
2. Files **empty** state.
3. Annotation of Source-link navigation into the Sources destination.

---

## 6. Out of scope

- Ingest, replace, delete.
- Listing derivative Files as top-level peers.
- Editing File metadata beyond what’s shown.
- Interpretation / credibility.

---

## 7. Acceptance checklist

- [ ] Lives in **Files** content host; no second app chrome.
- [ ] Rows show thumbnail, media type, original filename.
- [ ] Source link present when associated; navigates to that Source.
- [ ] Derivative-only files not listed as peers.
- [ ] No ingest/delete chrome required on this board.

---

## 8. Implementation notes (for PRs — not Design homework)

| Gap | Status |
| --- | --- |
| Sidebar **Files** destination | **Exists** (placeholder + `CountFiles`). |
| `ListFiles` (or equivalent) with Source association | **Likely FFI gap** — only count exists today; add list + join via `artifacts` in S2-21. |
| Thumbnail `rel_path` on list rows | Share ensure/list wiring with S2-18 where practical. |
