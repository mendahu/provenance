# Provenance Genealogy — Data Model Philosophy

## Status

Draft architecture notes. This document captures the current working model for the three principal data layers:

1. **Source** — evidence as acquired.
2. **Interpretation** — a researcher's source-scoped reading of that evidence.
3. **Conclusion** — cross-source canonical entities and the claims that connect source-local records to them.

The model is intentionally evidence-first. It should preserve ambiguity, conflicting interpretations, missing information, and incomplete identity resolution without forcing premature reconciliation.

---

# 1. Design philosophy

## 1.1 The three layers

### Source

The Source layer answers:

> What evidence do we possess?

It should contain little or no genealogical interpretation. A source may be a birth certificate, census page, photograph, oral testimony, DNA match report, book, web page capture, GEDCOM file, or other evidentiary object.

A source may have one or more artifacts. An artifact is a concrete representation of the source: a scan, photograph, PDF, audio recording, downloaded JSON file, etc.

The Source layer deliberately does **not** attempt to identify people, normalize dates, resolve places, or decide what facts are true.

### Interpretation

The Interpretation layer answers:

> What does this particular source appear to say?

Everything in this layer is scoped to a source or source stack and may contain researcher interpretation.

The progression is:

```text
Artifact
  ↓ researcher selects a meaningful portion
Citation
  ↓ researcher interprets that portion
Observation
  ↓ researcher organizes observations into a source-local semantic graph
Record
```

A citation is therefore interpretive: selecting a page, crop, polygon, timestamp, row, or other locator already asserts that this portion of the artifact is meaningful.

An observation records an interpretation of cited evidence. Multiple observations may coexist even when they conflict.

Records organize observations into source-local entities and relationships. Records do **not** have cross-source identity. Two `person_record` rows in two different sources may describe the same historical person, but the Interpretation layer does not assume that.

### Conclusion

The Conclusion layer answers:

> What does the researcher currently conclude about the historical world after considering one or more source stacks?

This layer contains canonical research entities such as Persons, Events, Places, Relationships, and Participations.

Canonical does **not** mean complete, final, or universally authoritative. A canonical Person may be unnamed and provisional. A canonical Place may be only partially located. Two canonical entities may later be discovered to represent the same real-world entity and be merged.

The primary bridge from Interpretation to Conclusion is a **claim** that a source-local record resolves to or corresponds to a canonical entity.

For example:

```text
PersonRecord ── claim ──> Person
EventRecord  ── claim ──> Event
PlaceRecord  ── claim ──> Place
RelationshipRecord ── claim ──> Relationship
ParticipationRecord ── claim ──> Participation
```

A claim can be supported by one or more records from one or more source stacks.

The model intentionally avoids requiring a claim for every individual field. A claim that an `event_record` corresponds to an `event` makes the entire source-local event record available as evidence about that event.

---

# 2. Core architectural rules

## Preserve evidence; make interpretation revisable

The source artifact must never be rewritten to match later interpretations.

For example, if handwriting is ambiguous:

```text
Citation C1
  image crop

Observation O1
  transcription = "Robert Smith"

Observation O2
  transcription = "Richard Smith"
```

Both observations may coexist.

## Records are source-scoped

A record describes an entity as represented within a particular source stack.

```text
Birth certificate
  PersonRecord A — child
  PersonRecord B — father
  PersonRecord C — mother
  EventRecord D  — birth
```

These records do not become reusable cross-source entities.

## Canonical entities may be sparse

A researcher may know that an ancestor's parent must have existed without knowing the parent's name.

```text
Person PER-7KD45
  preferred_name = NULL
```

This is valid. The entity can later be merged with a more completely identified Person if evidence establishes that they are the same human.

## Merge means identity

Merge is reserved for cases where two canonical entities previously treated as distinct are later concluded to be the same real-world thing.

```text
PER-A same_as PER-B
PLC-A same_as PLC-B
```

A historical relationship such as York → Toronto is not necessarily a merge. It may instead be represented as a loose place reference.

## Resolver logic is application-level

The database preserves multiple source-backed values. Application-level resolvers may synthesize a useful display value without creating new persisted claims.

For example:

```text
1800
May 1800
```

may display as:

```text
May 1800
```

because the second value is more specific and non-conflicting.

This derived display state is disposable and reproducible.

---

# 3. Identifier strategy

Every persistent row should have a globally unique machine identifier, likely UUIDv7 stored as a 16-byte BLOB in SQLite.

Selected canonical entities also receive short human-readable references:

```text
PER-7KD45  Person
EVT-3M8QF  Event
PLC-92KX4  Place
REL-A71DZ  Relationship
SRC-F4N2P  Source
```

Human references are conveniences, not primary identity. Internal source-scoped rows such as observations and records do not necessarily need human-readable references.

---

# 4. Source layer

## 4.1 `sources`

A source is the canonical evidentiary object.

```sql
CREATE TABLE sources (
    id              BLOB PRIMARY KEY,          -- UUIDv7
    ref             TEXT UNIQUE,               -- e.g. SRC-F4N2P
    source_type     TEXT NOT NULL,
    title           TEXT,
    description     TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

Examples of `source_type`:

```text
birth_certificate
census
photograph
oral_testimony
dna_match_report
book
website_capture
gedcom_file
family_tree_export
```

`source_type` should probably use an extensible vocabulary rather than a closed SQL enum.

## 4.2 `artifacts`

An artifact is a concrete representation of a source.

```sql
CREATE TABLE artifacts (
    id              BLOB PRIMARY KEY,
    source_id       BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    artifact_type   TEXT NOT NULL,
    file_path       TEXT,
    media_type      TEXT,
    checksum_sha256 TEXT,
    byte_size       INTEGER,
    metadata_json   TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

Examples:

```text
Source: original birth certificate
  Artifact: photocopy PDF
  Artifact: JPEG photograph

Source: family photograph
  Artifact: original TIFF scan
  Artifact: smaller JPEG derivative

Source: oral testimony
  Artifact: audio recording
  Artifact: written notes
```

Artifact metadata is technical metadata rather than genealogical interpretation.

---

# 5. Interpretation layer

## 5.1 Source stacks

A source can contain multiple independent semantic matrices. A census is the clearest example: two unrelated households on the same census page may form separate source stacks.

```sql
CREATE TABLE source_stacks (
    id          BLOB PRIMARY KEY,
    source_id   BLOB NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    label       TEXT,
    notes       TEXT,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
);
```

A simple certificate may have one stack. A census may have many.

## 5.2 `citations`

A citation selects an addressable portion of an artifact.

```sql
CREATE TABLE citations (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    artifact_id     BLOB NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    parent_id       BLOB REFERENCES citations(id) ON DELETE CASCADE,
    locator_type    TEXT NOT NULL,
    locator_json    TEXT NOT NULL,
    alt_text        TEXT,
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
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

## 5.3 `observations`

An observation is a source-scoped semantic interpretation of one or more citations.

Multiple observations may coexist and conflict.

```sql
CREATE TABLE observations (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    observation_type TEXT NOT NULL,
    value_type       TEXT,
    value_text       TEXT,
    value_json       TEXT,
    confidence       REAL,
    notes            TEXT,
    created_at       TEXT NOT NULL,
    updated_at       TEXT NOT NULL
);
```

Observations may be supported by multiple citations:

```sql
CREATE TABLE observation_citations (
    observation_id  BLOB NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
    citation_id     BLOB NOT NULL REFERENCES citations(id) ON DELETE CASCADE,
    PRIMARY KEY (observation_id, citation_id)
);
```

Examples:

```text
transcription = "Robert Smith"
reported_date = DateValue(...)
reported_relationship = "father"
reported_place = "York, Upper Canada"
explicitly_blank = true
```

An observation may also refer to a record in another source stack. This is needed for evidence such as oral testimony identifying a person depicted in a photograph.

Rather than hard-coding every possible target type here, the exact implementation of cross-record observation references remains an open schema question.

## 5.4 Record tables

Records form the semantic graph described by a source stack.

### `person_records`

```sql
CREATE TABLE person_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    label           TEXT,
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

### `event_records`

```sql
CREATE TABLE event_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    event_type      TEXT,
    date_value_id   BLOB,
    place_record_id BLOB,
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,
    FOREIGN KEY (place_record_id) REFERENCES place_records(id)
);
```

The forward reference to `place_records` is shown conceptually; table creation order would be adjusted in the real migration.

### `place_records`

A PlaceRecord describes the place expression contained in one source stack. It does not recreate the canonical place hierarchy.

```sql
CREATE TABLE place_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    display_value   TEXT,
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

For example:

```text
"York, Upper Canada, British North America"
```

may be one `place_record`, later resolved to canonical Place `York`.

### `relationship_records`

```sql
CREATE TABLE relationship_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    relationship_type TEXT NOT NULL,
    person_a_id     BLOB NOT NULL REFERENCES person_records(id),
    person_b_id     BLOB NOT NULL REFERENCES person_records(id),
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

The meaning of `person_a` and `person_b` depends on `relationship_type`; this may later evolve into explicitly named roles.

### `participation_records`

```sql
CREATE TABLE participation_records (
    id              BLOB PRIMARY KEY,
    source_stack_id BLOB NOT NULL REFERENCES source_stacks(id) ON DELETE CASCADE,
    person_record_id BLOB NOT NULL REFERENCES person_records(id),
    event_record_id BLOB NOT NULL REFERENCES event_records(id),
    role            TEXT,
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

Examples:

```text
child participates in birth as subject
father participates in birth as father
John participates in wedding as witness
```

## 5.5 Connecting observations to records

Observations should retain field-level provenance without requiring fields themselves to become claims.

A generic record-field assignment table is one possible design:

```sql
CREATE TABLE record_observations (
    record_type     TEXT NOT NULL,
    record_id       BLOB NOT NULL,
    field_name      TEXT NOT NULL,
    observation_id  BLOB NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
    PRIMARY KEY (record_type, record_id, field_name, observation_id)
);
```

This is intentionally provisional. SQLite cannot enforce a foreign key from `record_id` to several possible record tables. We may instead use typed join tables such as `person_record_observations`, `event_record_observations`, etc.

Typed join tables are more verbose but provide stronger relational integrity.

---

# 6. Structured value objects

## 6.1 Date values

Genealogical dates should not be SQL `DATE` or `DATETIME` values. They need to represent partial dates, approximations, before/after bounds, ranges, periods, alternate calendars, and missing components.

GEDCOM 7 should be treated as the minimum semantic capability.

Dates are domain value objects, but may still be stored in a dedicated relational table.

```sql
CREATE TABLE date_values (
    id              BLOB PRIMARY KEY,
    kind            TEXT NOT NULL,
    qualifier       TEXT,
    calendar        TEXT,

    start_year      INTEGER,
    start_month     INTEGER,
    start_day       INTEGER,

    end_year        INTEGER,
    end_month       INTEGER,
    end_day         INTEGER,

    phrase          TEXT,

    CHECK (start_month IS NULL OR start_month BETWEEN 1 AND 12),
    CHECK (end_month   IS NULL OR end_month BETWEEN 1 AND 12),
    CHECK (start_day   IS NULL OR start_day BETWEEN 1 AND 31),
    CHECK (end_day     IS NULL OR end_day BETWEEN 1 AND 31)
);
```

Examples:

```text
14 MAY 1985
MAY 1985
1985
ABT 1985
BEF 1900
BET 1880 AND 1885
FROM 1880 TO 1885
```

A persistence ID does not imply that a DateValue has domain identity. It is still conceptually a value object.

Application-level date resolvers can compare multiple source values and synthesize display values without modifying the stored evidence.

---

# 7. Conclusion layer

## 7.1 `persons`

```sql
CREATE TABLE persons (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE NOT NULL,
    preferred_name  TEXT,
    status          TEXT,
    notes           TEXT,
    merged_into_id  BLOB REFERENCES persons(id),
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

A Person may have no name or dates. Sparse and provisional Persons are valid.

## 7.2 `places`

The canonical Place model is intentionally modest. It is intended to support genealogy, not historical GIS.

Core capabilities:

1. Nest places.
2. Create loose references between places.
3. Merge places when they are discovered to be identical.

```sql
CREATE TABLE places (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    place_type      TEXT,
    parent_place_id BLOB REFERENCES places(id),
    valid_date_id   BLOB REFERENCES date_values(id),
    notes           TEXT,
    merged_into_id  BLOB REFERENCES places(id),
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

Examples:

```text
Canada
  Ontario
    Toronto
```

An underspecified canonical place is allowed:

```text
Springfield
  parent = NULL
```

If later shown to be Springfield, Illinois, it may be merged with that canonical place.

### `place_references`

```sql
CREATE TABLE place_references (
    id              BLOB PRIMARY KEY,
    from_place_id   BLOB NOT NULL REFERENCES places(id),
    to_place_id     BLOB NOT NULL REFERENCES places(id),
    reference_type  TEXT NOT NULL,
    valid_date_id   BLOB REFERENCES date_values(id),
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

Examples:

```text
York --historically_related--> Toronto
Upper Canada --historically_related--> Ontario
```

The relationship may be modeled as coarsely or precisely as the researcher wishes.

## 7.3 `events`

```sql
CREATE TABLE events (
    id              BLOB PRIMARY KEY,
    ref             TEXT UNIQUE NOT NULL,
    event_type      TEXT NOT NULL,
    date_value_id   BLOB REFERENCES date_values(id),
    place_id        BLOB REFERENCES places(id),
    notes           TEXT,
    merged_into_id  BLOB REFERENCES events(id),
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
);
```

## 7.4 `relationships`

```sql
CREATE TABLE relationships (
    id                BLOB PRIMARY KEY,
    ref               TEXT UNIQUE NOT NULL,
    relationship_type TEXT NOT NULL,
    person_a_id       BLOB NOT NULL REFERENCES persons(id),
    person_b_id       BLOB NOT NULL REFERENCES persons(id),
    status            TEXT,
    notes             TEXT,
    merged_into_id    BLOB REFERENCES relationships(id),
    created_at        TEXT NOT NULL,
    updated_at        TEXT NOT NULL
);
```

Examples:

```text
parent / child
spouse
sibling
adoptive parent
other researcher-defined relationship
```

Derived relationships such as sibling or niece/nephew may be calculated by application logic rather than always persisted.

## 7.5 `participations`

```sql
CREATE TABLE participations (
    id            BLOB PRIMARY KEY,
    person_id     BLOB NOT NULL REFERENCES persons(id),
    event_id      BLOB NOT NULL REFERENCES events(id),
    role          TEXT,
    notes         TEXT,
    merged_into_id BLOB REFERENCES participations(id),
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);
```

---

# 8. Claims

Claims are the explicit interface between source-local records and the canonical graph, and can also support researcher conclusions assembled from multiple records.

The current simplifying principle is:

> Claims cite records, not individual fields.

A record is the Interpretation layer's semantic unit. Observations provide detailed provenance beneath it.

## 8.1 Generic claim table

A first-pass claim representation:

```sql
CREATE TABLE claims (
    id              BLOB PRIMARY KEY,
    claim_type      TEXT NOT NULL,
    polarity        TEXT NOT NULL DEFAULT 'positive',
    confidence      REAL,
    status          TEXT NOT NULL,
    notes           TEXT,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL,

    CHECK (polarity IN ('positive', 'negative'))
);
```

`claim_type` examples:

```text
record_resolves_to_entity
same_as
not_same_as
research_conclusion
```

## 8.2 Claim subjects and objects

Generic polymorphic subject/object references are awkward in relational SQL. A pragmatic first implementation may use typed claim tables for the common reconciliation cases.

### Person record resolution

```sql
CREATE TABLE person_record_claims (
    claim_id         BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    person_record_id BLOB NOT NULL REFERENCES person_records(id),
    person_id        BLOB NOT NULL REFERENCES persons(id)
);
```

### Event record resolution

```sql
CREATE TABLE event_record_claims (
    claim_id         BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    event_record_id  BLOB NOT NULL REFERENCES event_records(id),
    event_id         BLOB NOT NULL REFERENCES events(id)
);
```

### Place record resolution

```sql
CREATE TABLE place_record_claims (
    claim_id         BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    place_record_id  BLOB NOT NULL REFERENCES place_records(id),
    place_id         BLOB NOT NULL REFERENCES places(id)
);
```

### Relationship record resolution

```sql
CREATE TABLE relationship_record_claims (
    claim_id              BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    relationship_record_id BLOB NOT NULL REFERENCES relationship_records(id),
    relationship_id       BLOB NOT NULL REFERENCES relationships(id)
);
```

### Participation record resolution

```sql
CREATE TABLE participation_record_claims (
    claim_id                BLOB PRIMARY KEY REFERENCES claims(id) ON DELETE CASCADE,
    participation_record_id BLOB NOT NULL REFERENCES participation_records(id),
    participation_id        BLOB NOT NULL REFERENCES participations(id)
);
```

Typed tables avoid weak polymorphic foreign keys while preserving a common Claim abstraction.

## 8.3 Claim evidence

Claims may be supported by multiple records.

The generic domain concept is:

```text
Claim
  evidence:
    Record A
    Record B
    Record C
```

A strict relational implementation may use typed evidence tables rather than a polymorphic `(record_type, record_id)` pair.

A provisional compact form is:

```sql
CREATE TABLE claim_evidence (
    claim_id        BLOB NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
    record_type     TEXT NOT NULL,
    record_id       BLOB NOT NULL,
    stance          TEXT NOT NULL DEFAULT 'supporting',
    notes           TEXT,
    PRIMARY KEY (claim_id, record_type, record_id),
    CHECK (stance IN ('supporting', 'conflicting'))
);
```

This does not provide database-enforced foreign-key integrity for `record_id`. If that proves undesirable, split this into typed evidence tables.

## 8.4 Negative claims

A negative claim is distinct from absence of a positive claim.

```text
No claim:
  unknown whether Robert is Jake's father

Positive claim:
  Robert is Jake's father

Negative claim:
  Robert is not Jake's father
```

Negation belongs to the proposition (`claims.polarity`). Conflicting evidence belongs to the claim-evidence edge (`claim_evidence.stance`).

These must remain separate concepts.

---

# 9. Merge model

A merge should be explicit and reversible/auditable in principle.

Example:

```text
PER-A "Unknown father"
PER-B "William Smith"

Claim:
  PER-A same_as PER-B

Merge:
  PER-A.merged_into_id = PER-B
```

Old IDs and human references should continue resolving to the surviving entity. This is important for sync, external references, old notes, and imports.

The same mechanism can apply to Place, Event, Relationship, and other canonical entities where identity reconciliation is meaningful.

---

# 10. Photos and testimony example

## Photo source

```text
Source: unmarked family photograph
Artifact: scan.jpg
Citation: crop around one person
Observation: a person is depicted
PersonRecord: unidentified depicted person
```

## Testimony source

```text
Source: oral testimony from relative
Artifact: audio or research note
Citation: "That's my grandfather"
Observation:
  subject = PersonRecord from photo source
  meaning = speaker identifies depicted person as grandfather
```

The testimony observation belongs to the testimony source stack but may reference a globally addressable record from the photograph stack.

The Conclusion layer can then claim that the photo `person_record` resolves to a canonical Person.

This requires records to be source-scoped but globally addressable.

---

# 11. DNA example

DNA matching can be treated as another source of genealogical evidence rather than requiring the core application to become genetics software.

Example:

```text
Source: 23andMe DNA match report
Artifact: export, screenshot, JSON, CSV, etc.
Citation: match result
Observations:
  shared DNA
  predicted relationship
  match display name
PersonRecord:
  the matched person/profile
```

A 23andMe Family Tree export can similarly become a source containing PersonRecords and RelationshipRecords, including inferred anonymous connecting people.

Raw genotype artifacts may be preserved without being interpreted by the core genealogy model.

---

# 12. Open schema questions

The following should remain explicitly unresolved until implementation pressure clarifies them:

1. **Observation → Record references**
   - Generic polymorphic table vs typed join tables.

2. **Observation references to records in other source stacks**
   - Required for testimony identifying a person in a photograph.
   - Needs strong provenance while preserving source-stack ownership.

3. **Generic claims vs typed claim tables**
   - Domain model benefits from generic claims.
   - SQLite foreign-key integrity favors typed claim tables.

4. **Claim evidence implementation**
   - Generic `(record_type, record_id)` is simple but weakly constrained.
   - Typed evidence tables are verbose but safe.

5. **Record fields**
   - Which properties belong directly on record tables vs are exclusively assembled from observations?

6. **Canonical entity fields**
   - Canonical entities should remain usable without turning every field into a Claim.
   - Conflicting source values can remain unresolved and be synthesized by application-level resolvers.

7. **Place reference semantics**
   - Keep deliberately loose unless actual genealogy workflows require more formal types.

8. **Human-readable refs**
   - Determine which entity classes warrant visible refs. Internal source-scoped records probably do not.

---

# 13. Current high-level schema

```text
SOURCE

Source
  └── Artifact


INTERPRETATION

Source
  └── SourceStack
       ├── Citation
       │    └── Observation
       │
       └── source-local record graph
            ├── PersonRecord
            ├── EventRecord
            ├── PlaceRecord
            ├── RelationshipRecord
            └── ParticipationRecord


CONCLUSION

Person
Event
Place
Relationship
Participation

     ▲
     │ claims resolve / connect records
     │
source-local record graph

Canonical entities may also be related to one another through ordinary
canonical relationships and may later be merged when identity is established.
```

The central distinction is:

> **Source:** what evidence exists.
>
> **Interpretation:** what a particular source appears to say.
>
> **Conclusion:** what the researcher currently believes about the historical world.
