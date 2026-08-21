# Provenance Genealogy — Data Model Philosophy

## Status

Draft architecture notes. This document describes the relationship between Provenance's three principal research layers and retains the current draft schema for the Interpretation and Conclusion layers while those models are being refined.

The authoritative Source-layer schema is [`source-layer-data-model.md`](source-layer-data-model.md).

The shared structured date model is defined in [`structured-date-model.md`](structured-date-model.md).

The shared structured name model is defined in [`structured-name-model.md`](structured-name-model.md).

The cross-cutting audit/revision model is defined in [`audit-revision-history.md`](audit-revision-history.md).

---

# 1. The three layers

Provenance uses an evidence-first model with three principal layers:

```text
Source
  ↓
Interpretation
  ↓
Conclusion
```

The boundaries are intentional. Evidence should be preserved without forcing interpretation, and interpretation should remain revisable without rewriting the evidence from which it was derived.

## 1.1 Source

The Source layer answers:

> What evidence do we possess?

It contains the evidence as acquired, descriptive catalog metadata, concrete Artifacts, and locally managed Files.

The Source layer deliberately does not identify historical people, normalize historical assertions, resolve places, or decide what facts are true.

Its complete schema and storage rules are maintained in [`source-layer-data-model.md`](source-layer-data-model.md).

## 1.2 Interpretation

The Interpretation layer answers:

> What does this particular source appear to say?

The conceptual progression is:

```text
Artifact
  ↓ researcher selects a meaningful portion
Citation
  ↓ supports
Observation
  ↓ asserts a Property about
Node
```

A Citation identifies an addressable portion of an Artifact and may preserve the researcher's transcription and description of that evidence.

A Node is a source-local, globally addressable thing encountered while interpreting evidence. Nodes deliberately carry very little domain structure themselves. Their semantics come from their Node Type and the Observations that describe and connect them.

Each Node records a home `source_id` for the Source in which it was primarily encountered. That is a UI and organization aid, not a confinement rule: Observations from Citations under other Sources may still target the Node.

An Observation is the smallest independently addressable unit of interpreted evidence. It is an atomic, cited assertion with the general shape:

```text
subject Node -- Property --> typed value
```

The assertion may be positive or negative. A negative Observation records that the source appears to deny the proposition (for example, that a person's name is not Jake), rather than merely omitting a positive assertion.

The value may be a scalar/structured value or another Node. A Node-valued Observation therefore forms an edge in the Interpretation graph.

The Interpretation layer is an extensible, schema-described property graph. It stores explicit normalized assertions derived from evidence but does not persist relationships or conclusions that can merely be inferred from those assertions. Genealogical inference and higher-order semantics belong to application and Conclusion logic.

A Node's assertion provenance is derived through its Observations:

```text
Node
  ← Observation
  ← Citation
  ← Artifact
  ← Source
```

There is no persisted `source_stack` or specialized Record hierarchy. Disconnected semantic matrices arise naturally from the resulting Node/Observation graph.

## 1.3 Conclusion

The Conclusion layer answers:

> What does the researcher currently conclude about the historical world after considering one or more sources?

This layer contains canonical research entities such as:

```text
Person
Event
Place
Relationship
Participation
Location
```

These are rows in one `canonical_entities` table distinguished by `kind`, not parallel per-kind tables.

Canonical does not mean complete, final, or universally authoritative. A person entity may be unnamed and provisional. A Place may be only partially located. Two canonical entities may later be discovered to represent the same real-world entity and be merged.

Interpretation keeps source-local Nodes separate for traceability: two Sources that mention the same historical person normally produce two `person` Nodes. The Conclusion layer correlates those Nodes and gives the researcher a durable working subject.

The primary bridge is therefore **sameness**, not field-level resolution onto a Record:

```text
Node A ── sameness claim (same_as / distinct_from) ── Node B

canonical_entities E (kind = person)
  representative_node_id → one Node in an accepted same_as component
  members(E) = Nodes reachable from that representative via accepted same_as
```

Sameness Claims are higher-order than Observations. An Observation says what a particular Source appears to assert about a Node. A Sameness Claim says the researcher concludes that two Nodes do or do not co-refer, with its own evidence chain.

The same sameness and promotion pattern applies across Node Types that need working subjects (`person`, `event`, `relationship`, `participation`, `location`, and later `place`). Canonical entities are rows in one shared table — durable handles for Node clusters (ref, label, notes, merge). Domain payload and association links are derived from the Interpretation graph, not duplicated onto canonical rows.

When a promoted cluster carries conflicting member Observations, soft display merges may be computed automatically. Durable conclusions about a Property on a canonical entity are **Reconciliation Claims**.

Places as a domain are parked for a later rewrite; `kind = place` may exist in the unified table, but Place-specific structure is out of scope for this draft.

---

# 2. Core architectural rules

## 2.1 Preserve evidence; make interpretation revisable

Source evidence must never be rewritten to match a later interpretation.

For ambiguous handwriting, the Citation may preserve a faithful researcher transcription such as `Robins [?]` or `[William?] Smith`. Normalization of that reading belongs to an Observation rather than rewriting the Citation transcription.

## 2.2 Interpretation is a cited property graph

Nodes provide stable identity for source-local things. Observations provide atomic, cited assertions about those Nodes. Properties define the meaning and primitive value type of those assertions.

The database should enforce generic graph integrity and primitive typing. It should not attempt to encode the entire genealogy ontology into rigid table structure.

## 2.3 Interpretation vocabulary is extensible

Node Types and Properties are first-class data. Provenance ships with a useful seeded vocabulary, but researchers may add new Node Types and Properties without a database schema migration.

All Properties, including user-defined Properties, declare a value type. Unknown or custom vocabulary remains preservable and generically usable even when the core application has no specialized semantics for it.

Predicate _values_ such as `event_type` and participation `role` are likewise open text vocabulary: seeded with useful defaults, researcher-extensible, and not enforced as closed database enums. The Interpretation layer must remain ready for event kinds and roles the product cannot anticipate.

Core application logic and future plugins may provide first-class behavior for recognized keys and values while leaving storage generic. For example, the application may treat an Event with `event_type = birth` and a Participation with `role = subject` as that person's birth, without requiring the schema to encode birth-specific tables or mandatory role constraints.

## 2.4 Derived semantics belong to the application layer

The Interpretation schema stores explicit normalized assertions derived from evidence. Relationships that can be inferred from those assertions are application-level projections rather than duplicated persisted Interpretation data.

For example, a birth Event with subject and father Participations can allow the application to infer a father/child relationship without separately persisting that inferred relationship.

## 2.5 Canonical entities may be sparse

A researcher may know that an ancestor's parent must have existed without knowing that parent's name.

```text
Person PER-7KD45
  label = "Mother of James"
```

This is valid. Genealogical names, when known, come from cited NameValue Observations on member Nodes (and optional name Reconciliation Claims). The canonical `label` is only a researcher working identifier. The entity can later be reconciled or merged when additional evidence establishes its identity.

## 2.6 Sameness and merge are related but distinct

**Node sameness** correlates Interpretation subjects:

```text
Node A same_as Node B
Node A distinct_from Node B
```

**Canonical merge** joins two Conclusion entities that were previously treated as distinct working subjects:

```text
PER-A merged_into PER-B
PLC-A merged_into PLC-B
```

Accepting Node sameness may cause two Persons' membership components to connect; the application should then merge or otherwise reconcile those canonical entities. Historical relationships or succession between entities are not necessarily sameness or merge.

## 2.7 Negation is explicit

Absence of a positive assertion is not equivalent to a negative assertion.

This applies at both Interpretation and Conclusion:

```text
No Observation / no Claim:
  unknown whether the name is Jake

Positive:
  the name is Jake

Negative:
  the name is not Jake
```

At Interpretation, polarity belongs on the Observation: it records what a particular source appears to assert or deny. At Conclusion, Node co-reference is expressed with Sameness Claims (`same_as` / `distinct_from`) rather than by omitting a link. Future attribute-level conclusions may use their own polarity; that is separate from Observation polarity and from Node sameness.

Conflicting evidence remains a separate concern from negation. Two positive Observations with different values conflict; a negative Observation denies a specific proposition.

## 2.8 Resolver logic is application-level

The database preserves multiple source-backed values. Application-level resolvers may synthesize useful display values without creating new persisted Claims.

## 2.9 Audit history owns generic change metadata

Generic persistence bookkeeping such as `created_at`, `updated_at`, `created_by_user_id`, and `updated_by_user_id` does not belong on core domain tables.

Creation, modification, deletion, user attribution, and revision ordering are recorded by the append-only audit/revision model in [`audit-revision-history.md`](audit-revision-history.md).

---

# 3. Shared persistence conventions

Persistent rows use globally unique machine identifiers, currently UUIDv7 stored as 16-byte SQLite `BLOB` values.

Ordinary schema tables use SQLite `STRICT` typing.

Structured genealogical dates use the shared model in [`structured-date-model.md`](structured-date-model.md).

Structured personal names use the shared model in [`structured-name-model.md`](structured-name-model.md).

Selected user-facing entities may additionally receive short human-readable references (`ref`), unique within the project. Current Interpretation and Conclusion drafts include `ref` on Sources, Citations, Nodes, Observations, and `canonical_entities`.

---

# 4. Interpretation layer — current draft schema

The Interpretation layer is a generic, schema-described property graph:

```text
Source
  └── Artifact
        └── Citation
              └── Observation
                    ├── subject Node
                    ├── Property
                    └── typed value
                          └── may be another Node
```

There are no specialized `person_records`, `event_records`, `place_records`, `relationship_records`, or `participation_records` tables. A Node's type and its cited Observations provide the structure that those Record tables previously attempted to encode.

## 4.1 `citations`

A Citation selects an addressable portion of exactly one Artifact.

Each Citation is independently resolvable from its `artifact_id` and locator. Citations are not nested; the locator contains all information required to identify its target within the Artifact.

```sql
CREATE TABLE citations (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE,               -- e.g. CIT-3K9M2
    artifact_id     BLOB NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    locator_json    TEXT NOT NULL,
    transcription   TEXT,
    description     TEXT
) STRICT;
```

`ref` is an optional short human-readable reference for UI and discussion, parallel to Source refs.
`transcription` preserves the researcher's reading of textual or spoken content within the cited evidence. It is intended to remain faithful to the evidence, including uncertainty where appropriate, rather than silently normalizing abbreviations, names, places, or other values. For example, `Wm Robins` may be transcribed as written and normalized to `William Robins` later through an Observation.

`description` records what the researcher observes in the cited evidence. It is media-neutral and may describe visual, textual, audio, or other characteristics. It is not specifically an accessibility `alt_text` field.

Researcher commentary about the Citation itself belongs in `citation_notes`.

Conceptually:

```text
Artifact
    raw evidence

Citation.transcription
    what I read/hear

Citation.description
    what I observe

citation_notes
    researcher commentary about this Citation

Observation
    what I think it means
```

Research notes attached to a Citation live in a typed child table. Multiple notes are allowed so commentary can accumulate without overwriting earlier remarks.

```sql
CREATE TABLE citation_notes (
    id              BLOB PRIMARY KEY,
    citation_id     BLOB NOT NULL REFERENCES citations(id) ON DELETE CASCADE,
    body            TEXT NOT NULL
) STRICT;
```

Notes use a typed table with a real foreign key rather than a polymorphic notes table. Creation, edit, and deletion attribution belong to audit history.

### 4.1.1 Locator design

A locator is a versioned JSON document containing an ordered list of selectors. Each selector narrows the context established by the selectors before it.

This makes locators composable rather than forcing every Citation into one mutually exclusive `locator_type`.

For example:

```text
Artifact: PDF
  → artifact page 37 / marked page 23
  → polygon region on that page
```

is one Citation with two selectors, not a page Citation containing a child region Citation.

The top-level locator schema is:

```json
{
  "version": 1,
  "selectors": [{ "type": "..." }]
}
```

Semantically:

```text
LocatorV1 {
    version: 1
    selectors: Selector[]   // ordered, at least one
}
```

The application must validate the selector chain as a whole. A selector is interpreted relative to the context produced by the preceding selector. For example, `page` can select a page from a PDF and `region` can then select a polygon within that page.

The selector vocabulary is application-defined but extensible. The MVP should implement only selectors needed by concrete workflows. Unknown selector types must be preserved losslessly even if the current client cannot render or edit them.

There is intentionally no separate `locator_type` database column. A composable locator may contain several selector types, so a single database-level type would be ambiguous and redundant.

### 4.1.2 `page` selector

The `page` selector identifies a page by its position in the Artifact itself.

For a PDF, `artifact_page` is the 1-based page position the application uses to navigate the PDF and is the authoritative locator value.

A scanned book, register, newspaper, or archival document may display a different page number or label on the scanned page itself. That source pagination is retained separately as optional descriptive information in `page_label`.

```json
{
  "type": "page",
  "artifact_page": 37,
  "page_label": "23"
}
```

Schema:

```text
PageSelector {
    type: "page"
    artifact_page: integer >= 1
    page_label?: string
}
```

`page_label` is deliberately text rather than an integer because source pagination may contain values such as:

```text
iv
xii
A-3
23a
folio 17r
```

An unnumbered page simply omits `page_label`.

The general rule is:

> `artifact_page` answers where the Citation is in the digital Artifact. `page_label` records how that page identifies itself in the underlying source.

### 4.1.3 `region` selector

Selects an arbitrary polygonal region from an image-like context, including a standalone image, a rendered PDF page, or a video frame context.

A polygon is used rather than a rectangle so the same selector can represent simple rectangular crops as well as irregular evidence such as handwriting blocks, seals, marginal notes, damaged fragments, or people in photographs.

```json
{
  "type": "region",
  "points": [
    { "x": 0.31, "y": 0.18 },
    { "x": 0.73, "y": 0.18 },
    { "x": 0.7, "y": 0.39 },
    { "x": 0.34, "y": 0.42 }
  ],
  "unit": "normalized"
}
```

Schema:

```text
RegionSelector {
    type: "region"
    points: Point[]       // at least 3 points
    unit: "normalized"
}

Point {
    x: number between 0 and 1
    y: number between 0 and 1
}
```

The polygon is implicitly closed by connecting the final point back to the first point. The first point should not be repeated at the end of the array.

For version 1:

- `points` must contain at least three distinct points;
- every point must lie within the normalized media bounds;
- points are interpreted in array order as the polygon boundary;
- the polygon must not self-intersect;
- degenerate polygons with zero area are invalid.

Normalized coordinates keep Citations stable across rendering resolutions and generated previews.

A rectangle is represented as an ordinary four-point polygon. The application may provide rectangular drag-selection as a UI convenience and serialize it as four points.

A crop within a PDF is represented compositionally:

```json
{
  "version": 1,
  "selectors": [
    {
      "type": "page",
      "artifact_page": 37,
      "page_label": "23"
    },
    {
      "type": "region",
      "points": [
        { "x": 0.31, "y": 0.18 },
        { "x": 0.73, "y": 0.18 },
        { "x": 0.7, "y": 0.39 },
        { "x": 0.34, "y": 0.42 }
      ],
      "unit": "normalized"
    }
  ]
}
```

The same `region` selector works directly against a standalone image without a preceding `page` selector.

### 4.1.4 `time_range` selector

Selects an interval from time-based media such as audio or video.

```json
{
  "type": "time_range",
  "start_ms": 802400,
  "end_ms": 845100
}
```

Schema:

```text
TimeRangeSelector {
    type: "time_range"
    start_ms: integer >= 0
    end_ms: integer > start_ms
}
```

Milliseconds are used as the canonical stored unit so the representation is unambiguous and integer-based.

Selectors may be composed. For example, a Citation could identify a polygonal region of a video frame during a particular interval:

```json
{
  "version": 1,
  "selectors": [
    {
      "type": "time_range",
      "start_ms": 15120,
      "end_ms": 19440
    },
    {
      "type": "region",
      "points": [
        { "x": 0.12, "y": 0.08 },
        { "x": 0.42, "y": 0.08 },
        { "x": 0.42, "y": 0.53 },
        { "x": 0.12, "y": 0.53 }
      ],
      "unit": "normalized"
    }
  ]
}
```

### 4.1.5 `text_quote` selector

Selects textual content by its text rather than by unstable paragraph numbering or rendered coordinates.

```json
{
  "type": "text_quote",
  "exact": "William Robins, carpenter",
  "prefix": "household of ",
  "suffix": " aged 43"
}
```

Schema:

```text
TextQuoteSelector {
    type: "text_quote"
    exact: non-empty string
    prefix?: string
    suffix?: string
}
```

`exact` contains the text being selected. Optional `prefix` and `suffix` provide surrounding context to disambiguate repeated text without becoming part of the selected content.

For a PDF with a text layer, a page plus text quote can identify a paragraph or phrase without relying on a paragraph number:

```json
{
  "version": 1,
  "selectors": [
    {
      "type": "page",
      "artifact_page": 37,
      "page_label": "23"
    },
    {
      "type": "text_quote",
      "exact": "William Robins, carpenter",
      "prefix": "household of ",
      "suffix": " aged 43"
    }
  ]
}
```

### 4.1.6 Future selectors

The selector system is intentionally open to additional addressable media and structured data. Possible future selectors include:

```text
text_position
table_row
table_cell
csv_row
json_pointer
xpath
```

These are not part of the version 1 supported vocabulary until a concrete workflow requires them.

Adding a selector type does not require changing the `citations` table. It requires defining that selector's JSON shape, validation rules, and application behavior.

### 4.1.7 Locator invariants

For locator version 1:

1. `version` must equal `1`.
2. `selectors` must contain at least one selector.
3. Selectors are ordered and interpreted from the Artifact inward.
4. Every selector must contain a string `type` discriminator.
5. Known selector types must satisfy their type-specific schema and context requirements.
6. Unknown selector types are preserved losslessly for forward compatibility.
7. A Citation must be independently resolvable from `artifact_id` plus `locator_json`; it never depends on another Citation.
8. Region vertices use normalized coordinates relative to the selected media context, not a particular UI rendering.
9. Region polygons contain at least three distinct points, are non-self-intersecting, and have non-zero area.
10. For paginated digital Artifacts, the Artifact page position is authoritative for navigation.
11. Printed or marked source pagination is supplementary descriptive data and does not replace the Artifact page position.
12. Locator JSON identifies where the evidence is; transcription, description, and interpretation remain separate concerns.

Conceptually:

```text
Citation = Artifact + complete composable locator
```

UI hierarchy or containment can be derived from locator selector chains when useful without making Citation hierarchy part of the persisted evidence model.

## 4.2 Node vocabulary

### 4.2.1 `node_types`

Node Types define the semantic category of a Node. They are data rather than a database enum so the vocabulary can be extended without schema migrations.

```sql
CREATE TABLE node_types (
    key             TEXT PRIMARY KEY,
    label           TEXT NOT NULL,
    description     TEXT
) STRICT;
```

Application semantics attach to stable `key` values rather than a persisted built-in flag. The initial seeded vocabulary is expected to include at least:

```text
person
    A person represented by interpreted evidence.

event
    An occurrence represented by interpreted evidence.

place
    A geographic or named place represented by interpreted evidence.

relationship
    A general association that is useful when the evidence cannot be faithfully
    represented through a more specific event/context structure.

participation
    An association between a person and an event, including the person's role
    in that event.

location
    An association between an event and a place.

source
    A Source reified as an Interpretation subject so other evidence can
    refer to it or comment on it.
```

These names describe application semantics, not different SQL structures. Every instance is stored in the same `nodes` table.

`relationship`, `participation`, and `location` are examples of bridge-like Nodes. `source` is a reification Node: it lets the Interpretation graph talk about evidentiary objects, not only historical persons, events, and places. Structurally, however, the database does not distinguish these categories. Any Node can be related to any other Node through a Node-valued Observation. The application vocabulary defines what those relationships mean and which combinations are semantically useful.

### 4.2.2 `nodes`

A Node gives stable identity to a source-local thing or association encountered during interpretation.

```sql
CREATE TABLE nodes (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE,               -- e.g. NOD-7KD45
    source_id       BLOB NOT NULL REFERENCES sources(id),
    node_type_key   TEXT NOT NULL REFERENCES node_types(key),
    label           TEXT,
    description     TEXT
) STRICT;
```

`ref` is an optional short human-readable reference for UI and discussion.
`source_id` is the Node's home Source — typically the Source being interpreted when the Node was created. It exists so the application can efficiently surface Nodes that belong with a given Source during common same-source workflows. It does not restrict which Citations or Observations may reference the Node; cross-source Observations remain valid.

For Nodes of type `source`, `source_id` has a stronger meaning: it identifies the Source this Node reifies. The application should maintain at most one `source` Node per Source row. Other Sources may then make cited Observations about that Node—bare references such as “this book mentions that marriage certificate,” free-text remarks about authenticity or errors, or both—without collapsing that material into Observations about historical persons alone, and without requiring structured Source-quality columns.

Nodes deliberately contain little domain data. A person's name, an Event's date, a Place's name, or a Participation's role belongs in cited Observations rather than fixed Node columns.

`description` is an optional short summary of the Node itself. Nodes do not have a multi-note table; researcher commentary about interpreted assertions belongs on the supporting Observations and can be aggregated from `observation_notes` when a Node-centric view is needed.

A Node can therefore be sparse. Creating a `person` Node does not require knowing a name, date, or any other property.

## 4.3 Property vocabulary

### 4.3.1 `properties`

Properties are first-class, user-extensible definitions of predicates that may appear in Observations.

```sql
CREATE TABLE properties (
    key             TEXT PRIMARY KEY,
    label           TEXT NOT NULL,
    description     TEXT,
    value_type      TEXT NOT NULL,

    CHECK (value_type IN (
        'text',
        'integer',
        'real',
        'boolean',
        'date',
        'name',
        'node'
    ))
) STRICT;
```

A Property's `value_type` is intrinsic to the Property. For example:

```text
name          -> name
name_format   -> text    # name_format_profiles.key; primarily Conclusion reconciliation
birth_date    -> date
age_at_event  -> integer
place         -> node
person        -> node
role          -> text
event_type    -> text
remark        -> text
mentions      -> node
```

The semantic vocabulary is open, but the primitive value system is intentionally constrained. A researcher may define a new Property without introducing a new storage type.

`value_type = 'date'` always means the shared structured DateValue model in [`structured-date-model.md`](structured-date-model.md), not a SQL date or free-text date string.

`value_type = 'name'` always means the shared structured NameValue model in [`structured-name-model.md`](structured-name-model.md), not a single undifferentiated text string. A NameValue always has a full-form `form` and may optionally include ordered parts with an open part-type vocabulary for search and reconciliation.

`name_format` is primarily a Conclusion Property (Reconciliation Claim on a person entity). It need not appear in `node_type_properties` for Interpretation unless a Source itself asserts a naming convention.

Application semantics attach to stable `key` values, matching `node_types`. Seeded Properties may receive first-class application behavior. User-defined Properties remain first-class persisted data and can be generically displayed, searched, audited, synced, and referenced. Plugins may add specialized semantics for additional Properties later.

Open text values such as `event_type` and `role` are seeded with common defaults (for example `birth`, `death`, `marriage`, and participation roles such as `subject`, `father`, `mother`, `witness`) but remain researcher-extensible. The schema does not close those sets or require particular roles for particular event types; first-class workflows recognize well-known values in application logic.

Interactions between `source` Nodes should stay deliberately lightweight. Provenance does not seed a structured source-quality ontology (`is_authentic`, defect codes, and similar).

Two common shapes:

```text
mentions   -> node   # bare source-to-source reference; target is typically a source Node
remark     -> text   # free-text commentary about a source Node
```

A book that merely cites a marriage certificate can record `BookSource -- mentions --> CertificateSource` with no remark. A letter that challenges a certificate can add text `remark` Observations and, when needed, ordinary person-level Observations as well. Structured Properties beyond this may be added later only if a concrete workflow requires them.

### 4.3.2 `node_type_properties`

This table defines which Properties are valid for which Node Types.

```sql
CREATE TABLE node_type_properties (
    node_type_key   TEXT NOT NULL REFERENCES node_types(key),
    property_key    TEXT NOT NULL REFERENCES properties(key),

    PRIMARY KEY (node_type_key, property_key)
) STRICT;
```

For example:

```text
person        -> name
person        -> birth_date

event         -> event_type
event         -> date

participation -> person
participation -> event
participation -> role

location      -> event
location      -> place

source        -> mentions
source        -> remark
```

This is a vocabulary/schema relationship, not historical research data. It says that `participation.person` is a meaningful shape in the Interpretation graph; it does not assert that any particular Person participated in any particular Event.

The vocabulary should be seeded with common definitions but remain researcher-extensible.

For Node-valued Properties, the application vocabulary may additionally constrain allowed target Node Types (for example, `participation.person` should target a `person` Node). The exact persistence mechanism for those target constraints remains to be finalized; it should not force the core graph into genealogy-specific SQL tables.

## 4.4 Relationships between Nodes

There is intentionally no separate table containing historical graph edges.

A relationship between two Nodes is an Observation whose Property has `value_type = 'node'`:

```text
subject Node -- Property --> object Node
```

For example:

```text
Participation PT1 -- person --> Person P1
Participation PT1 -- event  --> Event E1
Participation PT1 -- role   --> "subject"
```

or, where the evidence gives only an indeterminate/general association:

```text
Relationship R1 -- participant --> Person P1
Relationship R1 -- participant --> Person P2
Relationship R1 -- relationship_type --> "cousin"
```

The graph stores only explicit normalized interpretation. It does not need to persist an additional `father_of` edge if application logic can infer that relationship from a birth Event and its Participations.

This allows the same structural model to represent nuclear family roles, extended kinship, step relationships, guardianship, employment, friendship, household roles, and unanticipated historical associations without adding bridge tables.

The same mechanism covers source-to-source evidence. That includes bare references and optional free-text commentary:

```text
Source Node SB1 (reifies book B)
Source Node SC1 (reifies marriage certificate C)
Person Node P1

Book Citation B1 supports a bare reference:
  SB1 -- mentions --> SC1

Letter Citation L1 supports commentary and historical-world facts:
  SC1 -- remark --> "birth certificate is fake"
  # or, when the document is trusted but a fact is disputed:
  SC1 -- remark --> "date of birth on certificate mistyped"
  P1  -- birth_date --> DateValue(2 JAN 1800)          # polarity positive
  P1  -- birth_date --> DateValue(1 JAN 1800)          # polarity negative
```

`mentions` is a Node-valued edge and need not say anything further about the referenced Source. `remark` is ordinary text-valued Interpretation of what a citing Source appears to say about another Source. Neither is a Source-layer column or a closed authenticity taxonomy. Historical-world Observations remain separate and independently citable.

## 4.5 `observations`

An Observation is the atomic unit of interpreted evidence. Every Observation is independently addressable and is supported by one Citation.

Conceptually:

```text
Observation {
    citation
    subject Node
    Property
    polarity          -- positive | negative
    typed value
}
```

The Citation preserves what the source actually contains; the Observation may normalize that evidence into a domain value. For example:

```text
Citation.transcription
    "Age: 42"

Observation
    polarity = positive
    Person P1 -- birth_date --> DateValue(...)
```

A Source may also appear to deny a proposition. That is still Interpretation, not a Conclusion-layer judgment:

```text
Citation.transcription
    "not Jake"

Observation
    polarity = negative
    Person P1 -- name --> NameValue(form = "Jake")
```

Absence of any name Observation means the name is unknown from that evidence. It does not mean the name is not Jake.

This distinction lets Observation values remain strongly typed without attempting to reproduce every possible source representation.

The intended primitive value categories are currently:

```text
text
integer
real
boolean
date
name
node
```

A provisional SQL shape is:

```sql
CREATE TABLE observations (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE,               -- e.g. OBS-2F8Q1
    citation_id     BLOB NOT NULL REFERENCES citations(id),
    subject_node_id BLOB NOT NULL REFERENCES nodes(id),
    property_key    TEXT NOT NULL REFERENCES properties(key),
    polarity        TEXT NOT NULL DEFAULT 'positive',

    value_text      TEXT,
    value_integer   INTEGER,
    value_real      REAL,
    value_boolean   INTEGER,
    value_date_id   BLOB REFERENCES date_values(id),
    value_name_id   BLOB REFERENCES name_values(id),
    value_node_id   BLOB REFERENCES nodes(id),

    CHECK (polarity IN ('positive', 'negative')),
    CHECK (value_boolean IS NULL OR value_boolean IN (0, 1))
) STRICT;
```

`ref` is an optional short human-readable reference for UI and discussion.
Exactly one value representation must be populated, and it must match `properties.value_type`. The final database-level enforcement mechanism for that cross-table constraint is still open; likely options include composite foreign-key structure plus a small validation trigger.

Reading uncertainty belongs in Citation transcription or description when needed. Alternative or competing interpretations are modeled as separate Observations rather than a numeric confidence score on a single row. Researcher commentary about a particular Observation belongs in `observation_notes`.

```sql
CREATE TABLE observation_notes (
    id              BLOB PRIMARY KEY,
    observation_id  BLOB NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
    body            TEXT NOT NULL
) STRICT;
```

Notes use a typed table with a real foreign key rather than a polymorphic notes table. Creation, edit, and deletion attribution belong to audit history.

For Node-valued Observations, the object Node must exist and should satisfy any target Node Type constraint defined by the vocabulary. Polarity applies to Node-valued Observations as well: a negative Observation denies that particular edge rather than deleting or omitting it.

A single Citation may support many atomic Observations:

```text
Citation C1
  -> Person P1 -- name       --> NameValue(form = "William Robins", …)
  -> Person P1 -- occupation --> "Carpenter"
  -> Person P1 -- birth_date --> DateValue(...)
```

Multiple Observations may also make different assertions about the same Property without forcing a single value onto the Node. Conflicting or alternative interpretations therefore remain independently citable and auditable. Multiple name Observations on one person Node are expected when Sources use different forms, nicknames, or name changes.

## 4.6 Interpretation-layer invariants

The current design aims to preserve these invariants:

1. Every Node has exactly one Node Type.
2. Every Node has a home `source_id`; that home Source does not confine which Observations may target the Node.
3. A Node of type `source` reifies the Source identified by its `source_id`; the application should keep at most one such Node per Source.
4. Node Types and Properties are extensible persisted vocabulary, not closed application enums.
5. Every Observation has its own stable identity.
6. Every Observation is supported by exactly one Citation.
7. Every Observation has exactly one subject Node and one Property.
8. Every Observation has exactly one typed value.
9. Every Observation has an explicit polarity of `positive` or `negative`; absence of an Observation is not negation.
10. The Observation value must match the Property's declared `value_type`.
11. Date-valued Observations reference a structured DateValue; they do not store SQL dates or free-text dates as the typed value.
12. Name-valued Observations reference a structured NameValue; they do not store an undifferentiated name string as the typed value.
13. A Property used on a Node must be allowed for that Node's Node Type.
14. A Node-valued Observation forms a graph edge and its object Node must exist.
15. Application vocabulary may constrain the target Node Type of Node-valued Properties.
16. Citation text/description preserves the evidence representation; Observations contain normalized interpretation.
17. Derived genealogical semantics are not duplicated into the Interpretation graph merely for convenience.
18. Unknown/custom Node Types, Properties, and open vocabulary values (such as event types and roles) remain preservable and generically usable without first-class application support.
19. First-class application behavior may recognize seeded keys and values; it must not require the schema to close those vocabularies or encode every genealogical edge case.

---

# 5. Conclusion layer — current draft schema

This draft replaces the earlier Record-resolution Claim model. Records no longer exist; Interpretation subjects are Nodes. Conclusion correlates Nodes and maintains canonical research entities.

## 5.1 Design summary

```text
Interpretation Nodes  <── sameness_claims (same_as / distinct_from) ──>  Interpretation Nodes
                                    │
                                    │ accepted same_as edges form components
                                    ▼
canonical_entities
  - kind (person | event | relationship | participation | location | …)
  - stable UUID and human ref
  - representative_node_id (mutable anchor into one component)
  - label (researcher working identifier)
  - members = derived closure over accepted same_as from that representative
  - domain payload derived from member-Node Observations + reconciliation_claims
```

Important separations:

1. **Sameness Claim** — proposition about two Nodes, with its own evidence.
2. **Canonical entity** — one table for all promoted kinds; durable id not tied forever to the progenitor Node.
3. **Membership** — derived from the claim graph + representative; not an independently edited join table.
4. **Derived structure and payload** — participants, roles, types, dates, names, and similar facts are read from Observations on member Nodes, optionally overridden by Reconciliation Claims.
5. **Canonical merge** — `merged_into_id` within the same `kind`.
6. **Promotion is sparse and independent** — promoting one entity does not auto-promote related Nodes.
7. **Reconciliation Claim** — concluded value of one Property on one canonical entity; real FK to `canonical_entities`.

SQLite can enforce foreign keys and basic checks. Connected-component membership, kind/representative consistency, and representative repointing on split are **application invariants**.

## 5.2 `sameness_claims`

A Sameness Claim asserts that two Nodes do or do not refer to the same historical thing.

```sql
CREATE TABLE sameness_claims (
    id              BLOB PRIMARY KEY,
    node_a_id       BLOB NOT NULL REFERENCES nodes(id),
    node_b_id       BLOB NOT NULL REFERENCES nodes(id),
    relation        TEXT NOT NULL,
    status          TEXT NOT NULL,
    argument        TEXT,

    CHECK (relation IN ('same_as', 'distinct_from')),
    CHECK (node_a_id < node_b_id),
    UNIQUE (node_a_id, node_b_id)
) STRICT;
```

`relation = same_as` means the researcher concludes the Nodes co-refer.  
`relation = distinct_from` means the researcher concludes they do not.

There is at most one Sameness Claim per unordered Node pair. Endpoint order is canonicalized with `node_a_id < node_b_id` so `(A, B)` and `(B, A)` cannot both exist. A pair therefore cannot simultaneously carry `same_as` and `distinct_from`; changing the conclusion updates the existing row (and is audited), rather than inserting a second Claim.

`status` is application-defined for workflow (for example provisional vs accepted vs rejected). Only **accepted** `same_as` Claims participate in membership closure. The exact status vocabulary can be refined later.

`argument` holds the researcher's reasoning chain for the claim — correlation narrative, circumstantial synthesis, or a short note when a single Observation already makes the case. Reasoning stays here rather than scattered across evidence rows.

Sameness Claims point at Nodes, not at canonical entities. Each pairwise correlation has its own row and evidence so `A same_as B` and `B same_as C` can be justified independently. Transitive membership follows from the accepted graph; evidence does not have to be repeated onto a single “cluster claim.”

Both Nodes in a Claim should normally share the same Node Type. Enforcing that is an application rule unless a later schema mechanism is added.

## 5.3 `sameness_claim_evidence`

Evidence rows are pointers to Observations that participate in the claim's exhibit list. An individual Observation does not carry a stance toward the Sameness Claim; the claim's `relation` and `argument` express the researcher's conclusion over the whole set.

```sql
CREATE TABLE sameness_claim_evidence (
    sameness_claim_id   BLOB NOT NULL REFERENCES sameness_claims(id) ON DELETE CASCADE,
    observation_id      BLOB NOT NULL REFERENCES observations(id),

    PRIMARY KEY (sameness_claim_id, observation_id)
) STRICT;
```

Pin every relevant Observation here; write the conclusion and inference in `sameness_claims.argument`.

## 5.4 `canonical_entities`

Because canonical rows are thin handles, they share one table instead of parallel `persons` / `events` / … tables.

```sql
CREATE TABLE canonical_entities (
    id                      BLOB PRIMARY KEY,
    kind                    TEXT NOT NULL,
    ref                     TEXT UNIQUE NOT NULL,
    representative_node_id  BLOB NOT NULL REFERENCES nodes(id),
    label                   TEXT,
    merged_into_id          BLOB REFERENCES canonical_entities(id),

    CHECK (kind IN (
        'person',
        'place',
        'event',
        'relationship',
        'participation',
        'location'
    ))
) STRICT;
```

```text
members(entity) =
  all Nodes reachable from entity.representative_node_id
  via accepted sameness_claims where relation = 'same_as'
```

Rules:

- `kind` must match the representative Node's `node_type_key` (application invariant).
- `merged_into_id`, when set, should reference another entity of the same `kind`.
- `label` is an optional researcher working identifier (for example `Mother of James`). It is not a genealogical name and must not substitute for NameValue Observations or name Reconciliation Claims.
- `ref` is the stable short public reference (for example `PER-7KD45`).
- Creating an entity from a single Node sets `representative_node_id` to that Node. Later accepted `same_as` Claims expand membership automatically.
- Promotion is independent across kinds: promoting a person entity does not auto-promote related events, participations, or locations.
- **Places:** `kind = place` is reserved, but Place-specific modeling (hierarchy, gazetteer behavior, and similar) is parked for a later domain pass.

```sql
CREATE TABLE canonical_entity_notes (
    id                      BLOB PRIMARY KEY,
    canonical_entity_id     BLOB NOT NULL
        REFERENCES canonical_entities(id) ON DELETE CASCADE,
    body                    TEXT NOT NULL
) STRICT;
```

One notes table covers every kind because there is a single parent table and a real foreign key.

### 5.4.1 Derived endpoints

Association kinds (`relationship`, `participation`, `location`) do not store foreign keys to other canonical entities. Endpoints are derived:

```text
Participation entity C
  representative → participation Node PT1
  members(C) = {PT1, PT2, …}

For each member Node:
  Observations: PT -- person --> person Node N
                PT -- event  --> event Node E
                PT -- role   --> "father"

Resolve N → canonical entity P where P.kind = person and N ∈ members(P)
Resolve E → canonical entity Ev where Ev.kind = event and E ∈ members(Ev)
```

The UI can show “Person P participated in Event Ev as father” without canonical association FKs. The same pattern applies to Relationships and Locations.

## 5.5 `reconciliation_claims`

After Nodes are correlated and a canonical entity is promoted, conflicting or competing member Observations may still disagree about a Property (name, birth date, role, event type, and so on). Soft display merges can often be computed automatically without persistence. When the researcher (or a persisted automatic process) needs a durable concluded value, that is a **Reconciliation Claim**.

A Reconciliation Claim asserts:

```text
for canonical entity E, Property P has concluded value V
```

It is extensible across kinds and Properties because it references `properties.key` and stores a typed value the same way Observations do.

```sql
CREATE TABLE reconciliation_claims (
    id              BLOB PRIMARY KEY,
    entity_id       BLOB NOT NULL REFERENCES canonical_entities(id) ON DELETE CASCADE,
    property_key    TEXT NOT NULL REFERENCES properties(key),
    status          TEXT NOT NULL,
    origin          TEXT NOT NULL DEFAULT 'researcher',
    argument        TEXT,

    value_text      TEXT,
    value_integer   INTEGER,
    value_real      REAL,
    value_boolean   INTEGER,
    value_date_id   BLOB REFERENCES date_values(id),
    value_name_id   BLOB REFERENCES name_values(id),
    value_node_id   BLOB REFERENCES nodes(id),

    CHECK (origin IN ('researcher', 'automatic')),
    CHECK (value_boolean IS NULL OR value_boolean IN (0, 1)),
    UNIQUE (entity_id, property_key)
) STRICT;
```

`entity_id` is a real foreign key to `canonical_entities`. The entity's `kind` is available via that join; it is not duplicated on the claim row.

`property_key` is the extensibility hook. Any Property in the vocabulary may be concluded on a suitable entity (subject to application rules about which Properties make sense for that `kind`).

Exactly one value representation must be populated, and it must match `properties.value_type`, parallel to Observations. The concluded value may:

- match one member Observation's value (researcher selects a winner);
- be a synthesized value that no single Observation holds exactly (for example a DateValue spanning Apr–May 1985, or a NameValue merging parts);
- be produced by an automatic reconciler and persisted with `origin = automatic` when the project wants a durable soft merge.

There is at most one Reconciliation Claim per `(entity, property)`. Changing the concluded value updates that row (and is audited).

`argument` holds researcher reasoning when needed. Soft display-only merges that are never persisted do not require a claim.

### Name format as reconciliation

Cultural name display/entry ordering is not a column on `canonical_entities`. It is concluded like other Person-scoped facts:

```text
Property name_format -> text   # value is a name_format_profiles.key, e.g. "western"
```

- `project_settings.default_name_format_key` supplies the UI default when a person entity has no accepted `name_format` Reconciliation Claim.
- When the researcher commits a format for a Person (including as part of reconciling names across cultures), they persist a Reconciliation Claim for `name_format`.
- Evidence pins are optional for `name_format` (it is often a preference rather than source-derived); `argument` may still record why that profile was chosen.
- Concluded `name` values remain separate Reconciliation Claims (`property_key = name`, NameValue). Format and name content are related in the UI but distinct Properties.

See [`structured-name-model.md`](structured-name-model.md).

### Auto versus persisted reconciliation

| Situation | Typical handling |
|---|---|
| Compatible values (May 1985 with 14 May 1985; James with James K. Robins) | Application projection for display; no claim required |
| Light conflict with a graceful blend (Apr 1985 vs May 1985 → range) | Projection, or optional persisted claim with `origin = automatic` |
| Hard conflict or explicit researcher choice | Persisted claim with `origin = researcher`, evidence pins, and `argument` |

Absence of a Reconciliation Claim means “no durable concluded value yet,” not “no evidence.” The UI may still show member Observations and soft merges. For `name_format`, absence means “use the project default.”

### 5.5.1 `reconciliation_claim_evidence`

```sql
CREATE TABLE reconciliation_claim_evidence (
    reconciliation_claim_id BLOB NOT NULL
        REFERENCES reconciliation_claims(id) ON DELETE CASCADE,
    observation_id          BLOB NOT NULL REFERENCES observations(id),

    PRIMARY KEY (reconciliation_claim_id, observation_id)
) STRICT;
```

Evidence rows are pointers to Observations that participate in the claim's exhibit list — typically Observations on member Nodes that assert the same Property (or otherwise bear on the conclusion). Individual Observations do not carry a stance toward the claim; `argument` and the concluded value express the conclusion over the set.

### 5.5.2 Example

```text
canonical_entities row E1
  kind = person
  members: person Nodes N1, N2

N1 Observation: birth_date → DateValue(14 MAY 1985)
N2 Observation: birth_date → DateValue(MAY 1985)
  → soft display merge; no claim required

N1 Observation: birth_date → DateValue(MAY 1985)
N2 Observation: birth_date → DateValue(APR 1985)
  → optional automatic claim on E1 / birth_date
  → or researcher claim choosing one side / synthesizing a range

N1 Observation: name → NameValue(form="James K. Robins", …)
N2 Observation: name → NameValue(form="James Robins", …)
  → often soft-mergeable; claim on E1 / name if committing a preferred NameValue
  → optional claim on E1 / name_format = "western" when committing display/entry convention
```

## 5.6 Canonical merge

When two canonical entities of the same `kind` should become one working subject:

```text
E-A label = "Unknown father"
E-B label = "William Smith"

Merge:
  E-A.merged_into_id = E-B
```

Typical trigger: an accepted `same_as` Claim connects Nodes that currently sit under two different canonical entities of that kind. The application merges the entities and keeps a single representative in the combined component.

Old ids and human refs should continue resolving to the surviving entity. Merge remains explicit and auditable. Reconciliation Claims on the absorbed entity must be merged or re-pointed by application rules.

## 5.7 Conclusion-layer invariants

1. Sameness Claims reference two distinct Nodes and never substitute for Observations.
2. There is at most one Sameness Claim per unordered Node pair (`UNIQUE (node_a_id, node_b_id)` with canonical endpoint order).
3. Each accepted `same_as` component should correspond to at most one non-merged `canonical_entities` row of the matching `kind`.
4. A canonical entity's members are exactly the Nodes in the accepted `same_as` component containing its `representative_node_id`.
5. Membership is not stored as an independently editable join table.
6. `representative_node_id` may change when the previous representative leaves the component; the canonical entity id does not change for that reason alone.
7. `kind` matches the representative Node's `node_type_key`.
8. `distinct_from` and rejected Claims do not enlarge membership.
9. Canonical entities do not store association endpoint FKs or denormalized Interpretation payload; durable concluded values use Reconciliation Claims.
10. Promoting one canonical entity does not require or imply promoting related entities.
11. There is at most one Reconciliation Claim per `(entity_id, property_key)`.
12. A Reconciliation Claim's typed value must match `properties.value_type`, parallel to Observations.
13. Soft display merges may exist without a Reconciliation Claim; absence of a claim is not absence of evidence.
14. Person name format is concluded via Property `name_format` (or falls back to `project_settings.default_name_format_key`), not a column on `canonical_entities`.
15. Place-specific domain structure is out of scope for this draft.

---

# 6. Claims scope note

This draft's Conclusion Claims are:

- **Sameness Claims** (`sameness_claims`) — Node co-reference;
- **Reconciliation Claims** (`reconciliation_claims`) — concluded Property values on `canonical_entities`.

The older generic `claims` / Record-resolution tables and per-kind canonical tables (`persons`, `events`, …) are removed in favor of this model. Sameness and reconciliation remain distinct claim kinds.

---

# 7. Cross-layer examples

## 7.1 Photograph and testimony

```text
Photograph Source
  Artifact: scan.jpg
  Citation: crop around one person
  Observation: cited crop depicts person Node N1
  Node N1 (person, home Source = photograph)

Testimony Source
  Artifact: audio or research note
  Citation: "That's my grandfather"
  Observation: testimony refers to the same depicted person as Node N1
  Node N2 (person, home Source = testimony)

Conclusion
  canonical_entities E1 (kind=person, representative_node_id = N1)
  sameness_claim: N1 same_as N2 (accepted), with evidence Observations
  members(E1) = {N1, N2}
```

## 7.2 Conflicting certificate and letter

```text
Birth certificate Source C
  person Node NC, birth_date Observation → 1 JAN 1800
  source Node SC reifying C

Letter Source L
  Observations:
    SC -- remark --> "date of birth on certificate mistyped"
    person Node NL -- birth_date --> 2 JAN 1800
    person Node NL -- birth_date --> 1 JAN 1800 (polarity negative)

Conclusion
  sameness_claim: NC same_as NL (accepted), evidence cites both Sources' Observations
  canonical_entities E (kind=person, representative → NC or NL); members = {NC, NL}
  reconciliation_claim on E, property birth_date:
    value → DateValue(2 JAN 1800)   # researcher choice, or synthesized
    evidence → the birth_date Observations (and related letter Observations as needed)
    argument → why the letter's correction is preferred
```

## 7.3 DNA evidence

```text
Source: DNA match report
Artifact: locally retained export/screenshot/JSON/CSV
Citation: match result
Observations on person Node ND:
  shared DNA
  predicted relationship
  match display name

Conclusion
  sameness_claims may later correlate ND with other person Nodes
  canonical person entity created/extended via representative + accepted same_as closure
```

---

# 8. Open schema questions

1. **Observation value enforcement**
   - Finalize database-level enforcement that an Observation has exactly one value and that its storage column matches the referenced Property's `value_type`.

2. **Node-valued Property target constraints**
   - Define how the vocabulary expresses allowed target Node Types without hard-coding genealogy-specific edges into SQL tables.

3. **Seeded vocabulary**
   - Define the initial Node Types, Properties, and common open values (event types, participation roles, and similar) shipped with new projects while keeping all of them researcher-extensible. Keep `source`-Node commentary as lightweight free text unless a concrete workflow requires structured source-quality Properties.

4. **Sameness claim status vocabulary**
   - Finalize statuses (provisional, accepted, rejected, superseded, and similar) and which statuses participate in membership closure.

5. **Sameness claim evidence breadth**
   - Observations-only exhibit pins plus claim `argument` may be enough; revisit only if premise Sameness Claims or other exhibit types become common.

6. **Same-type enforcement**
   - Whether Node Type pairs on sameness Claims are application-validated only or schema-assisted.

7. **Reconciliation claim status and origin**
   - Align status vocabulary with Sameness Claims where useful; decide when automatic soft merges should be persisted (`origin = automatic`) versus display-only.

8. **Canonical `label` vs concluded names**
   - `label` remains the only intentional working field on `canonical_entities`; genealogical names and `name_format` use Reconciliation Claims.

9. **Place domain**
   - Parked for a later rewrite. `kind = place` is reserved on `canonical_entities`; Place-specific structure is out of scope until then.

10. **Human-readable refs**
   - Confirm ref assignment/format across Sources, Citations, Nodes, Observations, and canonical entities (nullable vs required, prefix conventions).

---

# 9. Documentation ownership

To avoid competing schema definitions:

- [`source-layer-data-model.md`](source-layer-data-model.md) is authoritative for Source-layer tables and Artifact/File storage.
- [`structured-date-model.md`](structured-date-model.md) is authoritative for shared DateValue persistence.
- [`structured-name-model.md`](structured-name-model.md) is authoritative for shared NameValue persistence.
- [`audit-revision-history.md`](audit-revision-history.md) is authoritative for audit and revision history.
- This document currently retains the working Interpretation and Conclusion schema until those layers are extracted into dedicated documents.
