# Provenance Genealogy — Data Model Philosophy

## Status

Draft architecture notes. This document describes the relationship between Provenance's three principal research layers. Layer-specific schema belongs in dedicated data-model documents rather than being duplicated here.

The authoritative Source-layer schema is [`source-layer-data-model.md`](source-layer-data-model.md).

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

Generic persistence bookkeeping such as:

```text
created_at
updated_at
created_by_user_id
updated_by_user_id
```

does not belong on core domain tables.

Creation, modification, deletion, user attribution, and revision ordering are recorded by the append-only audit/revision model in [`audit-revision-history.md`](audit-revision-history.md).

A timestamp remains on a domain row only when time itself is domain data rather than persistence bookkeeping.

---

# 3. Shared persistence conventions

## 3.1 Identifiers

Persistent rows use globally unique machine identifiers, currently UUIDv7 stored as 16-byte SQLite `BLOB` values.

Selected user-facing entities may additionally receive short human-readable references:

```text
PER-7KD45  Person
EVT-3M8QF  Event
PLC-92KX4  Place
REL-A71DZ  Relationship
SRC-F4N2P  Source
```

Human references are conveniences, not primary identity.

## 3.2 Strict SQLite typing

Ordinary schema tables use SQLite `STRICT` typing. This is a project-wide persistence rule rather than a per-table preference.

## 3.3 Structured dates

Genealogical dates cannot be represented adequately by ordinary SQL `DATE` or `DATETIME` values. Provenance requires a shared structured date value capable of representing partial dates, approximations, bounds, ranges, periods, alternate calendars, and missing components.

GEDCOM 7 should be treated as the minimum semantic capability.

The structured DateValue is a shared value object used where date semantics are required across layers. Its persistence schema should have one authoritative definition rather than being copied into each layer document.

---

# 4. Layer boundaries

A useful shorthand is:

```text
SOURCE
What evidence do we possess?

INTERPRETATION
What does this evidence appear to say?

CONCLUSION
What do we currently conclude after considering the evidence?
```

Examples:

```text
Source
  1897 birth certificate

Artifact
  locally ingested scan

Citation
  line containing father's name

Observation
  transcription = "William Smith"

PersonRecord
  father represented by this certificate

Claim
  this PersonRecord resolves to PER-123

Person
  PER-123, the researcher's current canonical identity
```

Each layer preserves information needed by the next without collapsing into it.

---

# 5. Cross-layer examples

## 5.1 Photograph and testimony

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

The testimony remains evidence from the testimony Source even though it refers to a Record interpreted from the photograph Source.

## 5.2 DNA evidence

DNA matching can be treated as another source of genealogical evidence rather than requiring the core application to become genetics software.

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

A family-tree export can similarly become a Source containing interpreted PersonRecords and RelationshipRecords, including inferred anonymous connecting people.

Raw genotype Files may be preserved without being interpreted by the core genealogy model.

---

# 6. Documentation ownership

To avoid competing schema definitions:

- [`source-layer-data-model.md`](source-layer-data-model.md) is authoritative for Source-layer tables and Artifact/File storage.
- [`audit-revision-history.md`](audit-revision-history.md) is authoritative for audit and revision history.
- This document is authoritative only for the high-level three-layer philosophy and cross-layer boundaries.

As the Interpretation and Conclusion schemas are refined, their detailed table definitions should likewise move into dedicated layer documents rather than being reintroduced here.
