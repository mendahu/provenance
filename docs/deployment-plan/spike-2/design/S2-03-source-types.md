# S2-03 — Source types (types + suggested fields)

**Kind:** Claude Design board  
**Spike:** Provenencia Spike 2 (Source layer validation)  
**Implements later as:** PR S2-16  
**Depends on:** S2-01 workspace chrome (done); S2-02 Source fields vocabulary (fields must exist to assign)  
**Related briefs:** [`S2-02-source-fields.md`](S2-02-source-fields.md); [`S2-04-sources-catalog.md`](S2-04-sources-catalog.md)

Paste this entire document into Claude Design as the requirements for one board/flow.

---

## 1. Objective

Design the **Source types** destination inside the app workspace: browse `source_types`, open a type to see description and its **suggested metadata fields** (`source_type_metadata_fields`), assign/remove those associations, and create new types. One step up from S2-02 — this board **depends on Source fields existing** as the picker pool for associations.

Assume S2-01 chrome exists. **Do not redraw a second window shell.** Mount only in the existing **Source types** sidebar destination.

---

## 2. Domain model (UI must reflect)

Authoritative schema: [`source-layer-data-model.md`](../../../source-layer-data-model.md) §§3, 5.2; origin rules: [`seeded-vocabulary.md`](../../../seeded-vocabulary.md) §1.1.

### 2.1 `source_types`

| Field / concept | UI implication |
| --- | --- |
| `label` | Primary human name. Show in list and detail. |
| `key` | Stable machine id within an origin. Show in list (secondary) and/or detail (mono). |
| `description` | Optional help text. **Detail / expanded view only** — not required on collapsed list rows. |
| `origin` | `provenencia` / `user` / later `plugin:…`. Same list for all origins; surface origin (badge/column). |
| Uniqueness | `(key, origin)` — do not collapse colliding keys across origins. |

### 2.2 `source_type_metadata_fields` (suggestions)

| Rule | UI implication |
| --- | --- |
| Join only | Associations are many-to-many; the join has no `origin` of its own. |
| Suggested, not required | These fields are **suggestions** for Sources of this type — not a hard schema. Copy should not imply every Source must fill them. |
| `sort_order` | Preserve a stable display order when listing associations; Design may allow reorder if it stays simple. |
| Field identity | Show field **label** (and data type) from `source_metadata_fields`; pool comes from the Source fields vocabulary (S2-02). |
| Remove association | User **may remove** a type↔field join. That does **not** delete the field vocabulary row. |
| No delete type | Do **not** delete `source_types` rows in this spike. |

### 2.3 What this destination is not

- Not creating/editing field vocabulary definitions (that is S2-02) — except navigating or picking existing fields.
- Not editing metadata **values** on a Source instance.
- Not the Sources catalog list/detail.
- Not deleting Source types.

---

## 3. Requirements

### 3.1 List (Source types destination)

| ID | Requirement |
| --- | --- |
| T-1 | List all Source types for the open project inside the S2-01 content host. |
| T-2 | Each row shows at least **label**; prefer also showing **key** (secondary / mono). |
| T-3 | Origin visible in the list (badge/column) — system vs user in **one** list, not split lists. |
| T-4 | Search (or filter) at the top is recommended for parity with Source fields. |
| T-5 | Obvious **Add type** action from the list. |
| T-6 | Empty state + Add CTA if zero types (unlikely after seed). |

### 3.2 Detail / expanded type

| ID | Requirement |
| --- | --- |
| T-7 | Detail shows **description** (and label/key/origin). |
| T-8 | Detail shows **all metadata fields currently associated** with this type (from the join table), with enough identity to scan (label + data type at minimum). |
| T-9 | **Assign** association: pick from existing Source fields (S2-02 data) and attach to this type. Do not invent fields inline unless Design offers a clear shortcut that still creates a real `source_metadata_fields` row first. |
| T-10 | **Remove** association: detach a field from this type without deleting the field vocabulary row. Confirm only if needed for calm UX — not a destructive “delete type” pattern. |
| T-11 | Edit type **label** / **description** for `user` origin types. Prefer `provenencia` types **view-only** for type mutations (associations may still be adjustable — Design call; default: allow association edit on seeded types so dogfood can tune suggestions). |
| T-12 | No delete/archive control for the Source type itself. |
| T-13 | **Navigation pattern is open:** in-list expand/collapse of a row **or** push to a nested detail with back/breadcrumb are both acceptable. Document the choice on the board; requirements above must hold either way. |

### 3.3 Add (create type)

| ID | Requirement |
| --- | --- |
| T-14 | Add flow collects at least **label**; optional **description**; **key** derived or collected explicitly (same calm rule as S2-02). New rows use `origin = user`. |
| T-15 | Associating suggested fields during create is optional — may happen on detail after save. |
| T-16 | Cancel / dismiss without orphan chrome. |
| T-17 | Add chrome may match S2-02’s chosen pattern (modal vs nested pane) for consistency, but is not required to be identical if detail navigation differs. |

### 3.4 Errors and feedback

| ID | Requirement |
| --- | --- |
| T-18 | Validation (duplicate key under user origin, missing label) uses calm inline or toast patterns — not modal panic. |
| T-19 | Busy/saving states should disable duplicate submits. |
| T-20 | Removing an association that is already “in use” as Source metadata values elsewhere must not imply those values are deleted — only the suggestion link is removed. |

---

## 4. Suggested mock content

Mixed origins, e.g.:

**System:** Photograph, Book, Birth certificate — Book already suggesting Author, Publisher, Publication date  

**User:** Family scrapbook — with one or two assigned custom fields from S2-02 mocks  

Show one type with **no** associations yet (empty suggestions state + assign CTA).

---

## 5. Screen / frame inventory (minimum)

1. Source types **list** (label + key; origin visible).
2. **Detail or expanded** type with description + associated fields list.
3. **Assign field** flow (picker from existing Source fields).
4. **Remove association** affordance (before/after).
5. **Add type** flow.
6. Optional: same type in the alternate nav pattern annotation if Design explored both expand vs breadcrumb.

---

## 6. Out of scope

- Deleting Source types.
- Deleting Source field vocabulary rows (S2-02 also has no delete).
- Source instance create/edit / metadata values.
- Artifact ingest.
- Credibility / Interpretation.

---

## 7. Acceptance checklist

- [ ] Lives in **Source types** content host; no second app chrome.
- [ ] List shows label (+ key); description is detail/expanded-only.
- [ ] Associated fields from join table are visible; assign pulls from Source fields; remove association allowed.
- [ ] No delete Source type.
- [ ] Expand-in-list vs breadcrumb detail is an explicit Design decision on the board.
- [ ] Does not redefine field vocabulary (S2-02 owns that).
