# Omnibar search

**Status:** idea only — not roadmapped.

## Problem

As the workspace grows (Sources, vocabulary, Files, later Interpretation and Conclusion), sidebar destinations become a slow way to *find* something you already know exists. Researchers often remember a title fragment, a filename, a person name, or a short ref (`SRC-…`, `PER-C-…`) and want to jump there without hunting through menus and nested lists.

Provenencia already has **per-destination** search (Source fields / types filter on label/key/description; Sources and Files briefs recommend list search). That does not help when you are not sure *which* destination owns the thing, or when the thing lives several clicks deep (Artifact under a Source, Observation on a Node).

## Idea

A single **omnibar** at the top of the app: one search field that queries across catalog entities and offers **navigable hits**. Typing jumps the researcher into the right destination (and deep link when we have one) faster than clicking through the sidebar.

Think command-palette / Spotlight energy, scoped to the **open project** — not web search, not Settings.

### What should be searchable (horizon)

Grouped by layer; not all exist in the shipped catalog yet:

| Kind | Layer | Typical match fields | Ref? |
| --- | --- | --- | --- |
| Source types | Source (vocab) | `label`, `key`, `description` | no |
| Source fields | Source (vocab) | `label`, `key`, `description` | no |
| Sources | Source | `title`, `ref`, type label, `description`, notes, metadata text | `SRC-…` |
| Artifacts | Source | `ref`, `description`, primary File filename | `ART-…` |
| Files | Source | `original_filename`, `media_type` | no |
| Citations | Interpretation | `ref`, transcription / quote / page label, description | `CIT-…` |
| Observations | Interpretation | `ref`, property label + value text / name form / date | `OBS-…` |
| Nodes (candidates) | Interpretation | `ref`, `label`, type, description | `{P}-C-…` |
| Canonical entities | Conclusion | `ref`, working `label`, projected names | `{P}-…` |
| Relationships | Conclusion | mostly claims/views over entities — weak standalone identity today | usually none |

Contributors (`USR-…` / display name) are optional later if “who added this” becomes a jump target.

Exact match on a **ref prefix + token** should be a first-class fast path (paste `SRC-F4N2P` → one obvious hit).

## Display problem

Hits are **heterogeneous**. A Source wants title + type + thumbnail + `SRC-…`. A File wants filename + media type. A Person Node wants name / label + `PER-C-…`. A vocabulary field wants label + key + data type. Forcing every row through one Source-list cell will feel wrong; inventing a unique cell per kind will feel like ten apps in one dropdown.

### Display ideas (rough)

**1. Shared skeleton, kind-specific slots**

One row chrome for all hits:

```text
[icon / thumb]  primary title                 kind · secondary
                tertiary / match context        REF-…
```

- **Icon or thumb:** vocabulary = type glyph; Source/Artifact = list thumbnail or placeholder; File = media glyph; Person/Place = entity glyph.
- **Primary:** best human title (Source title, filename, Node/entity label, vocab label, NameValue `form` when that is what matched).
- **Kind chip:** short layer/kind label (`Source`, `File`, `Field`, `Person`, …) — the main disambiguator when titles collide.
- **Secondary:** type name, media type, `data_type`, origin, etc.
- **Ref** (when present): mono, trailing — always shown if the entity has one.
- **Tertiary / match context:** optional one line explaining *why* it matched (“note: …”, “metadata author: …”, “filename: …”) when the primary title itself did not contain the query.

Same spacing and typography; only the slots change. Avoid per-kind card layouts inside the results list.

**2. Grouped results**

Sections: Sources · Files · People · Vocabulary · … Empty sections omitted. Within a section, rows can stay closer to that destination’s list cell. Tradeoff: more vertical chrome; clearer when the query is ambiguous.

**3. Faceted omnibar**

Query syntax or trailing chips: `type:person alice`, `in:files`, or filter pills after the first keystroke. Reduces mixed-shape pressure by narrowing kind before rendering. Good complement to (1), not a substitute for a default “search everything” mode.

**4. Rank, then unify**

Rank by: exact ref → prefix ref → exact primary title → substring on primary → secondary fields (notes, metadata, transcription). Show a flat list with the shared skeleton; put kind in the chip so shape differences matter less than relevance order.

**5. Two densities**

Compact rows while typing (icon + title + kind + ref). Expanding a hit or holding ⌥ shows the richer secondary/tertiary block. Keeps the palette calm when many kinds collide.

**Recommendation to explore in Design:** start with **(1) + (4)** — one row skeleton and strong ranking — plus exact-ref promotion. Add grouping or facets only if mixed results stay confusing in dogfood.

## Implementation sketch (data model → search)

Today there are **no `Search*` FFI methods**. Lists are list-all (or workspace get); Fields/Types already filter **client-side** after `List*`. That is fine for small vocabulary tables and early dogfood; it will not scale to Sources + Files + Interpretation text.

Rough path:

1. **v0 (Source layer only):** omnibar calls existing list RPCs (and future `ListFiles` / artifact index), filters in Go or Swift on title/ref/label/filename. Enough to prove chrome and navigation.
2. **v1:** one catalog-open RPC, e.g. `SearchCatalog(query, kinds[], limit)` returning a **normalized hit DTO**:
   - `kind`, `id`, `ref?`, `title`, `subtitle?`, `match_reason?`, `destination` (sidebar + deep-link payload)
   - Engine owns ranking and which columns are searched; Swift only renders the skeleton.
3. **Indexing later:** FTS5 or a maintained search table over titles, refs, filenames, note bodies, metadata values, transcriptions, name forms — still emitting the same hit DTO so UI stays stable as layers land.
4. **Navigation:** hit → switch sidebar destination + select/open (Sources page, Fields detail, Files row, later Node/entity page). Deep links need destinations that exist; stub kinds can be omitted from search until their UI ships.

Artifacts are awkward: no project-wide list today (only under `GetSourceWorkspace`). Omnibar either searches Artifacts via a new index keyed by `source_id` for navigation, or surfaces them only as secondary lines under Source hits until a flat Artifact index exists.

Relationships without refs are poor primary hits; prefer navigating to the related Person/Event entities and treat “relationship” as a claim detail, not a top-level result kind, until the model gives them clearer identity.

## Why it fits Provenencia

Local-first catalogs invite keyboard navigation. Short refs were designed to be citable and memorable — an omnibar is the natural consumer. A single project-scoped search also reinforces that Evidence / Interpretation / Conclusion are one workspace, not separate products.

## Open questions

- Mounting: always-visible top bar vs ⌘K palette only vs both?
- Should vocabulary (types/fields) appear in the default “everything” query, or only under an Admin / Vocabulary facet?
- Thumbnail cost: show Source/File thumbs in the palette, or icons only until selected?
- Empty query: recent destinations / recent entities, or blank until type?
- Cross-project search (later installs) — out of scope, but does the chrome imply it?
- How aggressively to search note bodies and transcriptions (noise vs recall)?
- Candidate `PER-C-…` vs canonical `PER-…` — same list with a layer badge, or separate sections?

## Explicitly out of scope for this note

- Spike scheduling, Claude Design board, or concrete Swift layout
- Choosing FTS5 vs ad hoc SQL vs client filter
- Searching audit history, settings, or help docs
- Natural-language / AI “ask the catalog” queries

## Related docs

- [`catalog-refs.md`](../catalog-refs.md)
- [`source-layer-data-model.md`](../source-layer-data-model.md)
- [`artifact-file-storage.md`](../artifact-file-storage.md)
- [`interpretation-layer-data-model.md`](../interpretation-layer-data-model.md)
- [`conclusion-layer-data-model.md`](../conclusion-layer-data-model.md)
- [`macos-client-patterns.md`](../macos-client-patterns.md)
- [`navigation-history.md`](navigation-history.md) (Back/Forward after omnibar jumps)
- Deployment briefs that already assume local list search: [`S2-04-sources-list.md`](../deployment-plan/spike-2/design/S2-04-sources-list.md), [`S2-20-files-list.md`](../deployment-plan/spike-2/design/S2-20-files-list.md)
