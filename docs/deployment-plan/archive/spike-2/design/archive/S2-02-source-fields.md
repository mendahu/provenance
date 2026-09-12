# S2-02 — Source fields (metadata field vocabulary)

**Kind:** Claude Design board  
**Spike:** Provenencia Spike 2 (Source layer validation)  
**Implements later as:** PR S2-15  
**Depends on:** S2-01 workspace chrome (content mounts in the **Source fields** destination) — already shipped  
**Related briefs:** later S2-03 (Source types — associations use this field pool); [`S2-04-sources-list.md`](S2-04-sources-list.md); [`S2-23-source-detail.md`](S2-23-source-detail.md)

Paste this entire document into Claude Design as the requirements for one board/flow.

---

## 1. Objective

Design the **Source fields** destination inside the app workspace: browse the project’s `source_metadata_fields` vocabulary, search/filter it, open a field to view/edit, and create new fields. This is the **simplest** Spike 2 feature UI — no Source instances, no type↔field suggestions, no Artifacts.

Assume S2-01 chrome exists. **Do not redraw a second window shell.** Mount only in the existing **Source fields** sidebar destination.

---

## 2. Domain model (UI must reflect)

Authoritative schema: [`source-layer-data-model.md`](../../../../../source-layer-data-model.md) §5.1; origin rules: [`seeded-vocabulary.md`](../../../../../seeded-vocabulary.md) §1.1.

### 2.1 `source_metadata_fields`

| Field / concept | UI implication |
| --- | --- |
| `label` | Primary human name. Show in list and edit form. |
| `data_type` | `text` or `date` only. Chosen at create; **immutable** afterward. Show in list; picker on add only. |
| `description` | Optional help text. **Detail/edit only** — not required on list rows. |
| `key` | Stable machine id within an origin. **Auto-generated on create** as a kebab-case slug of the label (not typed by the user). Show on detail (mono); do not expose as an editable form field. |
| `origin` | Namespace: `provenencia` (product seed / “system”), `user` (researcher-added), later `plugin:<id>`. **Same list** for all origins — not separate lists. Surface origin as a column, badge, or sortable facet. |
| Uniqueness | `(key, origin)` — same label/key can exist under different origins; UI should not collapse them. |

### 2.2 What this destination is not

- Not attaching fields to Source **types** (join table / suggestions) — later board.
- Not editing metadata **values** on a Source — later catalog board.
- Not Source types admin.
- Not delete / retire vocabulary (out of Spike 2 for this board).

---

## 3. Requirements

### 3.1 List (Source fields destination)

| ID | Requirement |
| --- | --- |
| F-1 | List all metadata fields for the open project inside the S2-01 content host. |
| F-2 | Presentation may be a **list** or a **table**. Each row shows at least **label** and **data type**. |
| F-3 | Origin is visible in the list (column, badge, or equivalent) so system (`provenencia`) vs user-added rows are distinguishable **without** splitting into two lists. |
| F-4 | Support **sort** (at least by label and/or origin) and/or a clear origin column if tabular — researcher can scan “what’s mine vs seeded.” |
| F-5 | **Search** control at the top of the list filters by label (and optionally key/description). Empty search = full list. |
| F-6 | Empty state only if the project somehow has zero fields (unlikely after seed); still design a calm empty + primary **Add** CTA. |
| F-7 | Selecting a row opens that field’s detail/edit surface. |
| F-8 | Obvious **Add field** action from the list (toolbar and/or empty state). |

### 3.2 Detail / edit

| ID | Requirement |
| --- | --- |
| F-9 | Detail shows **label**, **data type**, and **description** (multiline OK). |
| F-10 | Edit allows changing **label** and **description**. **Data type is immutable** after create. |
| F-11 | Show **origin** and **key** as identity context (mono for key). **`user` and create-time `provenencia` (starter) rows are editable** for label and description. Plugin-origin rows stay view-only unless a later spike says otherwise. |
| F-12 | No delete / archive control on this board. |
| F-13 | No `created_at` / author chrome — attribution is audit, not domain columns. |

### 3.3 Add (create)

| ID | Requirement |
| --- | --- |
| F-14 | Add flow collects at least **label**, **data type** (`text` \| `date`), optional **description**. New rows use `origin = user`. |
| F-15 | **Key is generated automatically** as a kebab-case **slug** of the label (e.g. “Grandma’s album code” → something like `grandmas-album-code`). Do **not** collect key in the add form. Detail may show the minted key read-only. If the label cannot form a slug, show a calm validation error before save. |
| F-16 | On save, return to the list (or the new field’s detail) with the new row findable via search. |
| F-17 | Cancel / dismiss create without orphan chrome. |
| F-18 | **Chrome pattern is open:** modal/sheet vs push into a nested pane with back/breadcrumb are both acceptable on macOS. Prefer whatever stays consistent with Provenencia density and the S2-01 content host — Design decides; requirements above must hold either way. |

### 3.4 Errors and feedback

| ID | Requirement |
| --- | --- |
| F-19 | Validation (unslugifiable label, duplicate key under user origin after slugify, missing label, invalid data type) uses calm inline or toast patterns consistent with onboarding — not modal panic. |
| F-20 | Busy/saving states should disable duplicate submits. |

---

## 4. Suggested mock content

Use seeded-looking rows mixed with a few `user` rows so origin differentiation is obvious, e.g.:

**System (`provenencia`):** Author (text), Publication date (date), Photographer (text), Certificate number (text)  

**User:** Grandma’s album code (text), Scanned at church (text)

---

## 5. Screen / frame inventory (minimum)

1. Source fields **list/table** with mixed origins, search filled and cleared.
2. List sorted or filtered to show origin affordance clearly.
3. **Add field** flow (whatever chrome pattern Design chooses).
4. **Detail/edit** for a user field (label, type, description editable).
5. **Detail/edit** for a proveniencia starter field (same mutations as user).
6. Validation / error example (e.g. duplicate key) optional but useful.

---

## 6. Out of scope

- Delete / retire fields.
- Attaching fields to Source types (`source_type_metadata_fields`).
- Source catalog, notes, Artifact ingest.
- Plugin origin UX beyond not crashing if a `plugin:…` row appears (treat like another non-user origin badge).
- Credibility / Interpretation.

---

## 7. Acceptance checklist

- [ ] Lives in **Source fields** content host; no second app chrome.
- [ ] List shows label + data type; description is detail-only.
- [ ] Single list with visible origin (system vs user); search at top.
- [ ] Add + edit cover create/update for **user** and create-time **`provenencia`** fields; plugin detail is view-only; no delete on this board.
- [ ] Create flow does not ask for a key; key is a slug of the label (shown read-only on detail).
- [ ] Add chrome (modal vs nested pane) is intentional and documented on the board.
- [ ] No type-suggestion or Source-instance UI on this board.
