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

A Source may be a birth certificate, census page, photograph, oral testimony, DNA match report, book, website capture, GEDCOM file, family-tree export, or another evidentiary object.

The Source layer deliberately does not identify historical people, normalize historical assertions, resolve places, or decide what facts are true.

Its complete schema and storage rules are maintained in [`source-layer-data-model.md`](source-layer-data-model.md).

## 1.2 Interpretation

The Interpretation layer answers:

> What does this particular source appear to say?

Everything in this layer is scoped to a Source or Source Stack and may contain researcher interpretation.

The conceptual progression is:

```text
Artifact
  ↓ researcher selects a meaningful portion
Citation
  ↓ researcher interprets that portion
Observation
  ↓ researcher organizes observations into a source-local semantic graph
Record
```

A Citation is interpretive: selecting a page, crop, polygon, timestamp, row, or other locator already asserts that this portion of an Artifact is meaningful.

An Observation records an interpretation of cited evidence. Multiple Observations may coexist even when they conflict.

Records organize Observations into source-local entities and relationships. Records do not have cross-source identity. Two `person_record` rows in different Sources may describe the same historical person, but the Interpretation layer does not assume that.

Typical source-local record classes include:

```text
PersonRecord
EventRecord
PlaceRecord
RelationshipRecord
ParticipationRecord
```

Records must remain globally addressable even though they are source-scoped, because one Source may provide evidence about a Record interpreted from another Source—for example, oral testimony identifying a person depicted in a photograph.

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

The model intentionally avoids requiring a Claim for every individual field. A Claim that an EventRecord corresponds to an Event makes the source-local EventRecord available as evidence about that Event while retaining its detailed provenance beneath it.

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

## 2.2 Records are source-scoped

A Record describes an entity as represented within a particular Source Stack.

```text
Birth certificate
  PersonRecord A — child
  PersonRecord B — father
  PersonRecord C — mother
  EventRecord D  — birth
```

These Records do not become reusable cross-source entities. Cross-source identity belongs to the Conclusion layer.

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

For example:

```text
1800
May 1800
```

may display as:

```text
May 1800
```

when the values are compatible and the second is more specific.

Derived display state is disposable and reproducible.

## 2.7 Audit history owns generic change metadata

Generic persistence bookkeeping such as `created_at`, `updated_at`, `created_by_user_id`, and `updated_by_user_id` does not belong on core domain tables.

Creation, modification, deletion, user attribution, and revision ordering are recorded by the append-only audit/revision model in [`audit-revision-history.md`](audit-revision-history.md).

---

# 3. Shared persistence conventions

Persistent rows use globally unique machine identifiers, currently UUIDv7 stored as 16-byte SQLite `BLOB` values.

Ordinary schema tables use SQLite `STRICT` typing.

Structured genealogical dates use the shared model in [`structured-date-model.md`](structured-date-model.md).

Selected user-facing entities may additionally receive short human-readable references:

```text
PER-7KD45  Person
EVT-3M8QF  Event
PLC-92KX4  Place
REL-A71DZ  Relationship
SRC-F4N2P  Source
```

Human references are conveniences, not primary identity.

---

# 4. Interpretation layer — current draft schema

The following schema is a restored working draft and is intentionally subject to refinement.

## 4.1 `source_stacks`

A Source can contain multiple independent semantic matrices. A census is the clearest example: unrelated households on the same page may form separate Source Stacks.

```sql
CREATE TABLE source_stacks (
    id          BLOB PRIMARY KEY,
    source_id   BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    label       TEXT,
    notes       TEXT
) STRICT;
```

A simple certificate may have one stack. A census may have many.

## 4.2 `citations`

A Citation selects an addressable portion of an Artifact.

```sql
CREATE TABLE citations (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    artifact_id     BLOB NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    parent_id       BLOB REFERENCES citations(id) ON DELETE CASCADE,
    locator_type    TEXT NOT NULL,
    locator_json    TEXT NOT NULL,
    alt_text        TEXT,
    notes           TEXT
) STRICT;
```

Examples of `locator_type` / `locator_json`:

```json
{"type":"page","page":14}
```

```json
{"type":"image_region","x":0.31,"y":0.18,"width":0.12,"height":0.29}
```

```json
{"type":"time_range","start":802.4,"end":845.1}
```

```json
{"type":"table_row","page":14,"row":7}
```

Citation locators are intentionally polymorphic because different media require different addressing systems.

## 4.3 `observations`

An Observation is a source-scoped semantic interpretation of one or more Citations.

Multiple Observations may coexist and conflict.

```sql
CREATE TABLE observations (
    id               BLOB PRIMARY KEY,
    source_stack_id  BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    observation_type TEXT NOT NULL,
    value_type       TEXT,
    value_text       TEXT,
    value_json       TEXT,
    confidence       REAL,
    notes            TEXT
) STRICT;
```

Observations may be supported by multiple Citations:

```sql
CREATE TABLE observation_citations (
    observation_id  BLOB NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
    citation_id     BLOB NOT NULL REFERENCES citations(id) ON DELETE CASCADE,
    PRIMARY KEY (observation_id, citation_id)
) STRICT;
```

Examples:

```text
transcription = "Robert Smith"
reported_date = DateValue(...)
reported_relationship = "father"
reported_place = "York, Upper Canada"
explicitly_blank = true
```

An Observation may also refer to a Record in another Source Stack. This is needed for evidence such as oral testimony identifying a person depicted in a photograph. The exact implementation remains an open schema question.

## 4.4 Record tables

Records form the semantic graph described by a Source Stack.

### `person_records`

```sql
CREATE TABLE person_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    label           TEXT,
    notes           TEXT
) STRICT;
```

### `place_records`

```sql
CREATE TABLE place_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    display_value   TEXT,
    notes           TEXT
) STRICT;
```

A PlaceRecord describes the place expression contained in one Source Stack. It does not recreate the canonical place hierarchy.

### `event_records`

```sql
CREATE TABLE event_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
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
    source_stack_id   BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    relationship_type TEXT NOT NULL,
    person_a_id       BLOB NOT NULL REFERENCES person_records(id),
    person_b_id       BLOB NOT NULL REFERENCES person_records(id),
    notes             TEXT
) STRICT;
```

The meaning of `person_a` and `person_b` depends on `relationship_type`; this may later evolve into explicitly named roles.

### `participation_records`

```sql
CREATE TABLE participation_records (
    id               BLOB PRIMARY KEY,
    source_stack_id  BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    person_record_id BLOB NOT NULL REFERENCES person_records(id),
    event_record_id  BLOB NOT NULL REFERENCES event_records(id),
    role             TEXT,
    notes            TEXT
) STRICT;
```

Examples:

```text
child participates in birth as subject
father participates in birth as father
John participates in wedding as witness
```

## 4.5 Connecting Observations to Records

A generic Record-field assignment table was the previous working draft:

```sql
CREATE TABLE record_observations (
    record_type     TEXT NOT NULL,
    record_id       BLOB NOT NULL,
    field_name      TEXT NOT NULL,
    observation_id  BLOB NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
    PRIMARY KEY (record_type, record_id, field_name, observation_id)
) STRICT;
```

This remains provisional because SQLite cannot enforce a foreign key from `record_id` to several possible Record tables. Typed join tables may ultimately provide stronger relational integrity.

---

# 5. Conclusion layer — current draft schema

The following is likewise a restored working draft rather than a finalized schema.

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

Examples:

```text
York --historically_related--> Toronto
Upper Canada --historically_related--> Ontario
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

Derived relationships such as sibling or niece/nephew may be calculated by application logic rather than always persisted.

## 5.5 `participations`

```sql
CREATE TABLE participations (
    id             BLOB PRIMARY KEY,
    person_id      BLOB NOT NULL REFERENCES persons(id),
    event_id       BLOB NOT NULL REFERENCES events(id),
    role           TEXT,
    notes          TEXT,
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

`claim_type` examples:

```text
record_resolves_to_entity
same_as
not_same_as
research_conclusion
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

Typed tables avoid weak polymorphic foreign keys while preserving a common Claim abstraction.

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
  Observation: a person is depicted
  PersonRecord: unidentified depicted person

Testimony Source
  Artifact: audio or research note
  Citation: "That's my grandfather"
  Observation: speaker identifies the depicted PersonRecord as grandfather

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

1. **Observation → Record references**
   - Generic polymorphic table vs typed join tables.

2. **Observation references to Records in other Source Stacks**
   - Required for testimony identifying a person in a photograph.

3. **Generic Claims vs typed Claim tables**
   - Domain model benefits from generic Claims; SQLite foreign-key integrity favors typed tables.

4. **Claim evidence implementation**
   - Generic `(record_type, record_id)` is simple but weakly constrained.

5. **Record fields**
   - Which properties belong directly on Record tables vs are assembled from Observations?

6. **Canonical entity fields**
   - Canonical entities should remain usable without turning every field into a Claim.

7. **Place reference semantics**
   - Keep deliberately loose unless actual genealogy workflows require more formal types.

8. **Human-readable refs**
   - Determine which entity classes warrant visible refs.

---

# 10. Documentation ownership

To avoid competing schema definitions:

- [`source-layer-data-model.md`](source-layer-data-model.md) is authoritative for Source-layer tables and Artifact/File storage.
- [`structured-date-model.md`](structured-date-model.md) is authoritative for shared DateValue persistence.
- [`audit-revision-history.md`](audit-revision-history.md) is authoritative for audit and revision history.
- This document currently retains the working Interpretation, Conclusion, and Claim schema until those layers are extracted into dedicated documents.

The restored SQL above comes from the schema removed in commit `4a27111483f8a826f23c47d16322771e8f6c9935`, updated only to conform to current persistence conventions.