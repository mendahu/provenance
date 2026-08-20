# Provenance Genealogy — Data Model Philosophy

## Status

Draft architecture notes. This document describes the relationship between Provenance's three principal research layers and retains the current draft schema for the Interpretation and Conclusion layers while those models are being refined.

The authoritative Source-layer schema is [`source-layer-data-model.md`](source-layer-data-model.md).

The shared structured date model is defined in [`structured-date-model.md`](structured-date-model.md).

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

An Observation is the smallest independently addressable unit of interpreted evidence. It is an atomic, cited assertion with the general shape:

```text
subject Node -- Property --> typed value
```

The value may be a scalar/structured value or another Node. A Node-valued Observation therefore forms an edge in the Interpretation graph.

The Interpretation layer is an extensible, schema-described property graph. It stores explicit normalized assertions derived from evidence but does not persist relationships or conclusions that can merely be inferred from those assertions. Genealogical inference and higher-order semantics belong to application and Conclusion logic.

A Node's provenance is derived through its Observations:

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
```

Canonical does not mean complete, final, or universally authoritative. A canonical Person may be unnamed and provisional. A Place may be only partially located. Two canonical entities may later be discovered to represent the same real-world entity and be merged.

The primary bridge from Interpretation to Conclusion is a Claim that a source-local Record resolves to or corresponds to a canonical entity:

```text
PersonRecord        ── claim ──> Person
EventRecord         ── claim ──> Event
PlaceRecord         ── claim ──> Place
RelationshipRecord  ── claim ──> Relationship
ParticipationRecord ── claim ──> Participation
```

A Claim may be supported by multiple Records from multiple Sources.

---

# 2. Core architectural rules

## 2.1 Preserve evidence; make interpretation revisable

Source evidence must never be rewritten to match a later interpretation.

For ambiguous handwriting, the Citation may preserve a faithful researcher transcription such as `Robins [?]` or `[William?] Smith`. Normalization of that reading belongs to an Observation rather than rewriting the Citation transcription.

## 2.2 Interpretation is a cited property graph

Nodes provide stable identity for source-local things. Observations provide atomic, cited assertions about those Nodes. Properties define the meaning and primitive value type of those assertions.

The database should enforce generic graph integrity and primitive typing. It should not attempt to encode the entire genealogy ontology into rigid table structure.

## 2.3 Interpretation vocabulary is extensible

Node Types and Properties are first-class data. Provenance ships with a useful built-in vocabulary, but researchers may add new Node Types and Properties without a database schema migration.

All Properties, including user-defined Properties, declare a value type. Unknown or custom vocabulary remains preservable and generically usable even when the core application has no specialized semantics for it.

Core application logic and future plugins may provide first-class behavior for recognized vocabulary while leaving storage generic.

## 2.4 Derived semantics belong to the application layer

The Interpretation schema stores explicit normalized assertions derived from evidence. Relationships that can be inferred from those assertions are application-level projections rather than duplicated persisted Interpretation data.

For example, a birth Event with child and father Participations can allow the application to infer a father/child relationship without separately persisting that inferred relationship.

## 2.5 Canonical entities may be sparse

A researcher may know that an ancestor's parent must have existed without knowing that parent's name.

```text
Person PER-7KD45
  preferred_name = NULL
```

This is valid. The entity can later be reconciled or merged when additional evidence establishes its identity.

## 2.6 Merge means identity

Merge is reserved for cases where two canonical entities previously treated as distinct are later concluded to be the same real-world thing.

```text
PER-A same_as PER-B
PLC-A same_as PLC-B
```

Historical relationships or succession between entities are not necessarily merges.

## 2.7 Negative claims are explicit

Absence of a positive Claim is not equivalent to a negative Claim.

```text
No claim:
  unknown whether Robert is Jake's father

Positive claim:
  Robert is Jake's father

Negative claim:
  Robert is not Jake's father
```

Negation belongs to the proposition. Conflicting evidence is a separate property of the evidence supporting or opposing a Claim.

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

Selected user-facing entities may additionally receive short human-readable references.

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
    artifact_id     BLOB NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    locator_json    TEXT NOT NULL,
    transcription   TEXT,
    description     TEXT,
    notes           TEXT
) STRICT;
```

`transcription` preserves the researcher's reading of textual or spoken content within the cited evidence. It is intended to remain faithful to the evidence, including uncertainty where appropriate, rather than silently normalizing abbreviations, names, places, or other values. For example, `Wm Robins` may be transcribed as written and normalized to `William Robins` later through an Observation.

`description` records what the researcher observes in the cited evidence. It is media-neutral and may describe visual, textual, audio, or other characteristics. It is not specifically an accessibility `alt_text` field.

`notes` is available for other researcher commentary about the Citation itself.

Conceptually:

```text
Artifact
    raw evidence

Citation.transcription
    what I read/hear

Citation.description
    what I observe

Observation
    what I think it means
```

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
  "selectors": [
    { "type": "..." }
  ]
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
    { "x": 0.70, "y": 0.39 },
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
        { "x": 0.70, "y": 0.39 },
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
    description     TEXT,
    is_builtin      INTEGER NOT NULL DEFAULT 0,

    CHECK (is_builtin IN (0, 1))
) STRICT;
```

The initial built-in vocabulary is expected to include at least:

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

event_location
    An association between an event and a place.
```

These names describe application semantics, not different SQL structures. Every instance is stored in the same `nodes` table.

`relationship`, `participation`, and `event_location` are examples of bridge-like Nodes. Structurally, however, the database does not distinguish root entities from bridge entities. Any Node can be related to any other Node through a Node-valued Observation. The application vocabulary defines what those relationships mean and which combinations are semantically useful.

### 4.2.2 `nodes`

A Node gives stable identity to a source-local thing or association encountered during interpretation.

```sql
CREATE TABLE nodes (
    id              BLOB PRIMARY KEY,
    node_type_key   TEXT NOT NULL REFERENCES node_types(key),
    label           TEXT,
    notes           TEXT
) STRICT;
```

Nodes deliberately contain little domain data. A person's name, an Event's date, a Place's name, or a Participation's role belongs in cited Observations rather than fixed Node columns.

A Node can therefore be sparse. Creating a `person` Node does not require knowing a name, date, or any other property.

## 4.3 Property vocabulary

### 4.3.1 `properties`

Properties are first-class, user-extensible definitions of predicates that may appear in Observations.

```sql
CREATE TABLE properties (
    id              BLOB PRIMARY KEY,
    key             TEXT UNIQUE NOT NULL,
    label           TEXT NOT NULL,
    description     TEXT,
    value_type      TEXT NOT NULL,
    is_builtin      INTEGER NOT NULL DEFAULT 0,

    CHECK (value_type IN (
        'text',
        'integer',
        'real',
        'boolean',
        'date',
        'node'
    )),
    CHECK (is_builtin IN (0, 1))
) STRICT;
```

A Property's `value_type` is intrinsic to the Property. For example:

```text
name          -> text
birth_date    -> date
age_at_event  -> integer
place         -> node
person        -> node
role          -> text
```

The semantic vocabulary is open, but the primitive value system is intentionally constrained. A researcher may define a new Property without introducing a new storage type.

Built-in Properties may receive first-class application behavior. User-defined Properties remain first-class persisted data and can be generically displayed, searched, audited, synced, and referenced. Plugins may add specialized semantics for additional Properties later.

### 4.3.2 `node_type_properties`

This table defines which Properties are valid for which Node Types.

```sql
CREATE TABLE node_type_properties (
    node_type_key   TEXT NOT NULL REFERENCES node_types(key),
    property_id     BLOB NOT NULL REFERENCES properties(id),

    PRIMARY KEY (node_type_key, property_id)
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

event_location -> event
event_location -> place
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
Participation PT1 -- role   --> "father"
```

or, where the evidence gives only an indeterminate/general association:

```text
Relationship R1 -- participant --> Person P1
Relationship R1 -- participant --> Person P2
Relationship R1 -- relationship_type --> "cousin"
```

The graph stores only explicit normalized interpretation. It does not need to persist an additional `father_of` edge if application logic can infer that relationship from a birth Event and its Participations.

This allows the same structural model to represent nuclear family roles, extended kinship, step relationships, guardianship, employment, friendship, household roles, and unanticipated historical associations without adding bridge tables.

## 4.5 `observations`

An Observation is the atomic unit of interpreted evidence. Every Observation is independently addressable and is supported by one Citation.

Conceptually:

```text
Observation {
    citation
    subject Node
    Property
    typed value
}
```

The Citation preserves what the source actually contains; the Observation may normalize that evidence into a domain value. For example:

```text
Citation.transcription
    "Age: 42"

Observation
    Person P1 -- birth_date --> DateValue(...)
```

This distinction lets Observation values remain strongly typed without attempting to reproduce every possible source representation.

The intended primitive value categories are currently:

```text
text
integer
real
boolean
date
node
```

A provisional SQL shape is:

```sql
CREATE TABLE observations (
    id              BLOB PRIMARY KEY,
    citation_id     BLOB NOT NULL REFERENCES citations(id),
    subject_node_id BLOB NOT NULL REFERENCES nodes(id),
    property_id     BLOB NOT NULL REFERENCES properties(id),

    value_text      TEXT,
    value_integer   INTEGER,
    value_real      REAL,
    value_boolean   INTEGER,
    value_date_id   BLOB REFERENCES date_values(id),
    value_node_id   BLOB REFERENCES nodes(id),

    confidence      REAL,
    notes           TEXT,

    CHECK (value_boolean IS NULL OR value_boolean IN (0, 1))
) STRICT;
```

Exactly one value representation must be populated, and it must match `properties.value_type`. The final database-level enforcement mechanism for that cross-table constraint is still open; likely options include composite foreign-key structure plus a small validation trigger.

For Node-valued Observations, the object Node must exist and should satisfy any target Node Type constraint defined by the vocabulary.

A single Citation may support many atomic Observations:

```text
Citation C1
  -> Person P1 -- name       --> "William Robins"
  -> Person P1 -- occupation --> "Carpenter"
  -> Person P1 -- birth_date --> DateValue(...)
```

Multiple Observations may also make different assertions about the same Property without forcing a single value onto the Node. Conflicting or alternative interpretations therefore remain independently citable and auditable.

## 4.6 Interpretation-layer invariants

The current design aims to preserve these invariants:

1. Every Node has exactly one Node Type.
2. Node Types and Properties are extensible persisted vocabulary, not closed application enums.
3. Every Observation has its own stable identity.
4. Every Observation is supported by exactly one Citation.
5. Every Observation has exactly one subject Node and one Property.
6. Every Observation has exactly one typed value.
7. The Observation value must match the Property's declared `value_type`.
8. A Property used on a Node must be allowed for that Node's Node Type.
9. A Node-valued Observation forms a graph edge and its object Node must exist.
10. Application vocabulary may constrain the target Node Type of Node-valued Properties.
11. Citation text/description preserves the evidence representation; Observations contain normalized interpretation.
12. Derived genealogical semantics are not duplicated into the Interpretation graph merely for convenience.
13. Unknown/custom Node Types and Properties remain preservable and generically usable without first-class application support.

---

# 5. Conclusion layer — current draft schema

## 5.1 `persons`

```sql
CREATE TABLE persons (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE NOT NULL,
    preferred_name  TEXT,
    status          TEXT,
    notes           TEXT,
    merged_into_id  BLOB REFERENCES persons(id)
) STRICT;
```

A Person may have no name or dates. Sparse and provisional Persons are valid.

## 5.2 `places`

```sql
CREATE TABLE places (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    place_type      TEXT,
    parent_place_id BLOB REFERENCES places(id),
    valid_date_id   BLOB REFERENCES date_values(id),
    notes           TEXT,
    merged_into_id  BLOB REFERENCES places(id)
) STRICT;
```

The canonical Place model is intentionally modest: nesting, loose references, and merge when identity is established.

### `place_references`

```sql
CREATE TABLE place_references (
    id              BLOB PRIMARY KEY,
    from_place_id   BLOB NOT NULL REFERENCES places(id),
    to_place_id     BLOB NOT NULL REFERENCES places(id),
    reference_type  TEXT NOT NULL,
    valid_date_id   BLOB REFERENCES date_values(id),
    notes           TEXT
) STRICT;
```

## 5.3 `events`

```sql
CREATE TABLE events (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE NOT NULL,
    event_type      TEXT NOT NULL,
    date_value_id   BLOB REFERENCES date_values(id),
    place_id        BLOB REFERENCES places(id),
    notes           TEXT,
    merged_into_id  BLOB REFERENCES events(id)
) STRICT;
```

## 5.4 `relationships`

```sql
CREATE TABLE relationships (
    id                BLOB PRIMARY KEY,
    ref               TEXT UNIQUE NOT NULL,
    relationship_type TEXT NOT NULL,
    person_a_id       BLOB NOT NULL REFERENCES persons(id),
    person_b_id       BLOB NOT NULL REFERENCES persons(id),
    status            TEXT,
    notes             TEXT,
    merged_into_id    BLOB REFERENCES relationships(id)
) STRICT;
```

## 5.5 `participations`

```sql
CREATE TABLE participations (
    id             BLOB PRIMARY KEY,
    person_id      BLOB NOT NULL REFERENCES persons(id),
    event_id       BLOB NOT NULL REFERENCES events(id),
    role           TEXT,
    notes           TEXT,
    merged_into_id BLOB REFERENCES participations(id)
) STRICT;
```

---

# 6. Claims — current draft schema

Claims are the explicit interface between source-local Records and the canonical graph.

The current simplifying principle is:

> Claims cite Records, not individual fields.

## 6.1 `claims`

```sql
CREATE TABLE claims (
    id          BLOB PRIMARY KEY,
    claim_type  TEXT NOT NULL,
    polarity    TEXT NOT NULL DEFAULT 'positive',
    confidence  REAL,
    status      TEXT NOT NULL,
    notes       TEXT,

    CHECK (polarity IN ('positive', 'negative'))
) STRICT;
```

## 6.2 Typed Record-resolution Claims

```sql
CREATE TABLE person_record_claims (
    claim_id         BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    person_record_id BLOB NOT NULL REFERENCES person_records(id),
    person_id        BLOB NOT NULL REFERENCES persons(id)
) STRICT;

CREATE TABLE event_record_claims (
    claim_id         BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    event_record_id  BLOB NOT NULL REFERENCES event_records(id),
    event_id         BLOB NOT NULL REFERENCES events(id)
) STRICT;

CREATE TABLE place_record_claims (
    claim_id         BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    place_record_id  BLOB NOT NULL REFERENCES place_records(id),
    place_id         BLOB NOT NULL REFERENCES places(id)
) STRICT;

CREATE TABLE relationship_record_claims (
    claim_id               BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    relationship_record_id BLOB NOT NULL REFERENCES relationship_records(id),
    relationship_id        BLOB NOT NULL REFERENCES relationships(id)
) STRICT;

CREATE TABLE participation_record_claims (
    claim_id                BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    participation_record_id BLOB NOT NULL REFERENCES participation_records(id),
    participation_id        BLOB NOT NULL REFERENCES participations(id)
) STRICT;
```

## 6.3 Claim evidence

```sql
CREATE TABLE claim_evidence (
    claim_id        BLOB NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
    record_type     TEXT NOT NULL,
    record_id       BLOB NOT NULL,
    stance          TEXT NOT NULL DEFAULT 'supporting',
    notes           TEXT,

    PRIMARY KEY (claim_id, record_type, record_id),
    CHECK (stance IN ('supporting', 'conflicting'))
) STRICT;
```

This remains provisional because the generic `record_id` cannot have a database-enforced foreign key to multiple Record tables.

---

# 7. Merge model

A merge should be explicit and reversible/auditable in principle.

```text
PER-A "Unknown father"
PER-B "William Smith"

Claim:
  PER-A same_as PER-B

Merge:
  PER-A.merged_into_id = PER-B
```

Old IDs and human references should continue resolving to the surviving entity.

---

# 8. Cross-layer examples

## 8.1 Photograph and testimony

```text
Photograph Source
  Artifact: scan.jpg
  Citation: crop around one person
  Observation: cited crop depicts PersonRecord A
  PersonRecord A: unidentified depicted person

Testimony Source
  Artifact: audio or research note
  Citation: "That's my grandfather"
  Observation: cited testimony refers to the depicted PersonRecord

Conclusion
  Claim: photograph PersonRecord resolves to canonical Person
```

## 8.2 DNA evidence

```text
Source: DNA match report
Artifact: locally retained export/screenshot/JSON/CSV
Citation: match result
Observations:
  shared DNA
  predicted relationship
  match display name
PersonRecord:
  matched person/profile
```

---

# 9. Open schema questions

1. **Observation value enforcement**
   - Finalize database-level enforcement that an Observation has exactly one value and that its storage column matches the referenced Property's `value_type`.

2. **Node-valued Property target constraints**
   - Define how the vocabulary expresses allowed target Node Types without hard-coding genealogy-specific edges into SQL tables.

3. **Built-in vocabulary**
   - Define the initial Node Types and Properties shipped with new projects while keeping both researcher-extensible.

4. **Generic Claims vs typed Claim tables**
   - Domain model benefits from generic Claims; SQLite foreign-key integrity favors typed tables.

5. **Claim evidence implementation**
   - Generic `(record_type, record_id)` is simple but weakly constrained.

6. **Conclusion integration with the new Interpretation graph**
   - The existing Conclusion/Claim schema still reflects the earlier Record model and has intentionally not been changed as part of this Interpretation-layer revision.

7. **Canonical entity fields**
   - Canonical entities should remain usable without turning every field into a Claim.

8. **Place reference semantics**
   - Keep deliberately loose unless actual genealogy workflows require more formal types.

9. **Human-readable refs**
   - Determine which entity classes warrant visible refs.

---

# 10. Documentation ownership

To avoid competing schema definitions:

- [`source-layer-data-model.md`](source-layer-data-model.md) is authoritative for Source-layer tables and Artifact/File storage.
- [`structured-date-model.md`](structured-date-model.md) is authoritative for shared DateValue persistence.
- [`audit-revision-history.md`](audit-revision-history.md) is authoritative for audit and revision history.
- This document currently retains the working Interpretation, Conclusion, and Claim schema until those layers are extracted into dedicated documents.
