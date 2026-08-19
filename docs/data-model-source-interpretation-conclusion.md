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
  ↓ researcher interprets that portion
Observation
  ↓ observation contributes normalized data to
Record
```

A Citation identifies an addressable portion of an Artifact.

An Observation is the interpretive bridge between cited evidence and a source-local Record. It records what the researcher believes that cited evidence says about that Record.

Records organize those normalized observations into source-local entities and relationships. Records do not directly reference Sources; their provenance is derived through the chain:

```text
Record
  ← Observation
  ← Citation
  ← Artifact
  ← Source
```

There is no persisted `source_stack` grouping. If a Source produces several disconnected semantic matrices, those matrices arise naturally from the resulting Citation/Observation/Record graph. Optional user-facing grouping can be introduced later if a concrete workflow requires it.

Typical source-local Record classes include:

```text
PersonRecord
EventRecord
PlaceRecord
RelationshipRecord
ParticipationRecord
```

Records remain globally addressable even though they are source-local in meaning, because evidence from one Source may refer to a Record interpreted from another Source.

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

For ambiguous handwriting, for example:

```text
Citation C1
  image crop

Observation O1
  transcription = "Robert Smith"

Observation O2
  transcription = "Richard Smith"
```

Both interpretations may coexist while the underlying Artifact remains unchanged.

## 2.2 Records are source-local through provenance

A Record describes an entity as represented by interpreted evidence from a Source. It does not need a direct `source_id`; its provenance is carried by the Observation and Citation chain.

Cross-source identity belongs to the Conclusion layer.

## 2.3 Canonical entities may be sparse

A researcher may know that an ancestor's parent must have existed without knowing that parent's name.

```text
Person PER-7KD45
  preferred_name = NULL
```

This is valid. The entity can later be reconciled or merged when additional evidence establishes its identity.

## 2.4 Merge means identity

Merge is reserved for cases where two canonical entities previously treated as distinct are later concluded to be the same real-world thing.

```text
PER-A same_as PER-B
PLC-A same_as PLC-B
```

Historical relationships or succession between entities are not necessarily merges.

## 2.5 Negative claims are explicit

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

## 2.6 Resolver logic is application-level

The database preserves multiple source-backed values. Application-level resolvers may synthesize useful display values without creating new persisted Claims.

## 2.7 Audit history owns generic change metadata

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

The Interpretation schema is being refined table-by-table. The current high-level relationship is authoritative even where individual Record fields remain provisional:

```text
Source
  └── Artifact
        └── Citation
              └── Observation
                    └── Record
```

An Observation is the edge between a Citation and a Record. Separate `observation_citations` and `record_observations` join tables are therefore not part of the current model.

## 4.1 `citations`

A Citation selects an addressable portion of exactly one Artifact.

Each Citation is independently resolvable from its `artifact_id` and locator. Citations are not nested; a locator contains all information required to identify its target within the Artifact.

```sql
CREATE TABLE citations (
    id              BLOB PRIMARY KEY,
    artifact_id     BLOB NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    locator_type    TEXT NOT NULL,
    locator_json    TEXT NOT NULL,
    alt_text        TEXT,
    notes           TEXT
) STRICT;
```

Examples of `locator_type` / `locator_json` include pages, image regions, time ranges, and table rows. The locator representation remains intentionally polymorphic because different media require different addressing systems.

For example, a table row on a particular page should be represented by a self-contained locator such as:

```json
{"type":"table_row","page":14,"row":7}
```

rather than by making a row Citation a child of a separate page Citation.

This keeps Citation identity simple:

```text
Citation = Artifact + complete locator
```

UI hierarchy or containment can be derived from locators when useful without making that hierarchy part of the persisted evidence model.

## 4.2 `observations`

An Observation normalizes/interprets one Citation and associates that interpretation with one Record.

Conceptually:

```text
Citation
  "this region of the artifact"

Observation
  "this region says William Smith is the name of this PersonRecord"

Record
  source-local person represented by the evidence
```

The exact SQL representation of the Record target is intentionally still open because SQLite cannot enforce a foreign key from one polymorphic `record_id` to several Record tables.

A provisional shape is:

```sql
CREATE TABLE observations (
    id               BLOB PRIMARY KEY,
    citation_id      BLOB NOT NULL REFERENCES citations(id),
    record_type      TEXT NOT NULL,
    record_id        BLOB NOT NULL,
    field_name       TEXT,
    observation_type TEXT NOT NULL,
    value_type       TEXT,
    value_text       TEXT,
    value_json       TEXT,
    confidence       REAL,
    notes            TEXT
) STRICT;
```

This shape is illustrative rather than finalized. In particular, `record_type` / `record_id`, field targeting, and typed value storage are the next areas to refine.

## 4.3 Record tables

Records represent normalized source-local entities and relationships. They do not directly carry `source_id` or `source_stack_id`; their evidentiary provenance is derived from attached Observations.

### `person_records`

```sql
CREATE TABLE person_records (
    id      BLOB PRIMARY KEY,
    label   TEXT,
    notes   TEXT
) STRICT;
```

### `place_records`

```sql
CREATE TABLE place_records (
    id              BLOB PRIMARY KEY,
    display_value   TEXT,
    notes           TEXT
) STRICT;
```

### `event_records`

```sql
CREATE TABLE event_records (
    id              BLOB PRIMARY KEY,
    event_type      TEXT,
    date_value_id   BLOB REFERENCES date_values(id),
    place_record_id BLOB REFERENCES place_records(id),
    notes           TEXT
) STRICT;
```

### `relationship_records`

```sql
CREATE TABLE relationship_records (
    id                BLOB PRIMARY KEY,
    relationship_type TEXT NOT NULL,
    person_a_id       BLOB NOT NULL REFERENCES person_records(id),
    person_b_id       BLOB NOT NULL REFERENCES person_records(id),
    notes             TEXT
) STRICT;
```

### `participation_records`

```sql
CREATE TABLE participation_records (
    id               BLOB PRIMARY KEY,
    person_record_id BLOB NOT NULL REFERENCES person_records(id),
    event_record_id  BLOB NOT NULL REFERENCES event_records(id),
    role             TEXT,
    notes            TEXT
) STRICT;
```

These Record fields remain provisional and will be refined after Citations and Observations are settled.

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

1. **Observation → Record representation**
   - Observation is conceptually the direct Citation-to-Record edge.
   - Determine whether SQL should use a polymorphic target, typed Observation tables, or another integrity-preserving representation.

2. **Observation value structure**
   - Refine `field_name`, `observation_type`, and typed values instead of committing prematurely to generic JSON/text.

3. **Cross-source Record references**
   - Needed for evidence such as testimony identifying a PersonRecord interpreted from a photograph.

4. **Generic Claims vs typed Claim tables**
   - Domain model benefits from generic Claims; SQLite foreign-key integrity favors typed tables.

5. **Claim evidence implementation**
   - Generic `(record_type, record_id)` is simple but weakly constrained.

6. **Record fields**
   - Which properties belong directly on Record tables vs are assembled from Observations?

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
