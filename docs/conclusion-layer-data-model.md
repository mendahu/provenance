# Provenance Genealogy — Conclusion Layer Data Model

## Status

Draft architecture notes. This document is the authoritative schema and design reference for the Provenance Conclusion layer.

The Conclusion layer answers:

> What does the researcher currently conclude about the historical world after considering one or more sources?

Cross-layer philosophy is summarized in [`data-model-source-interpretation-conclusion.md`](data-model-source-interpretation-conclusion.md). Interpretation subjects (Nodes, Observations, Properties) are defined in [`interpretation-layer-data-model.md`](interpretation-layer-data-model.md). Shared date and name value models are [`structured-date-model.md`](structured-date-model.md) and [`structured-name-model.md`](structured-name-model.md). Audit history is [`audit-revision-history.md`](audit-revision-history.md).

---

# 1. Conclusion-layer principles

## 1.1 Canonical entities may be sparse

A researcher may know that an ancestor's parent must have existed without knowing that parent's name.

```text
Person PER-7KD45
  label = "Mother of James"
```

This is valid. Genealogical names, when known, come from cited NameValue Observations on member Nodes (and optional name Reconciliation Claims). The canonical `label` is only a researcher working identifier. The entity can later be reconciled or merged when additional evidence establishes its identity.

## 1.2 Sameness and merge are related but distinct

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

Accepting Node sameness may cause two person entities' membership components to connect; the application should then merge or otherwise reconcile those canonical entities. Historical relationships or succession between entities are not necessarily sameness or merge.

## 1.3 Negation and conflict at Conclusion

At Conclusion, Node co-reference is expressed with Sameness Claims (`same_as` / `distinct_from`) rather than by omitting a link. Absence of a Sameness Claim is not `distinct_from`.

Attribute-level conflicts across member Observations are handled by soft display merges and, when durable, by Reconciliation Claims. That is separate from Observation polarity and from Node sameness.

## 1.4 Resolver logic is application-level

The database preserves multiple source-backed values. Application-level resolvers may synthesize useful display values without creating new persisted Claims.

## 1.5 Persistence conventions

Persistent rows use globally unique machine identifiers, currently UUIDv7 stored as 16-byte SQLite `BLOB` values. Ordinary schema tables use SQLite `STRICT` typing.

Structured genealogical dates use [`structured-date-model.md`](structured-date-model.md). Structured personal names use [`structured-name-model.md`](structured-name-model.md).

Generic change metadata belongs to [`audit-revision-history.md`](audit-revision-history.md).

Selected user-facing entities may receive short human-readable references (`ref`), unique within the project. This draft requires `ref` on `canonical_entities`.

---

# 2. Design summary

This draft replaces the earlier Record-resolution Claim model. Records no longer exist; Interpretation subjects are Nodes. Conclusion correlates Nodes and maintains canonical research entities.

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

---

# 3. `sameness_claims`

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

---

# 4. `sameness_claim_evidence`

Evidence rows are pointers to Observations that participate in the claim's exhibit list. An individual Observation does not carry a stance toward the Sameness Claim; the claim's `relation` and `argument` express the researcher's conclusion over the whole set.

```sql
CREATE TABLE sameness_claim_evidence (
    sameness_claim_id   BLOB NOT NULL REFERENCES sameness_claims(id) ON DELETE CASCADE,
    observation_id      BLOB NOT NULL REFERENCES observations(id),

    PRIMARY KEY (sameness_claim_id, observation_id)
) STRICT;
```

Pin every relevant Observation here; write the conclusion and inference in `sameness_claims.argument`.

---

# 5. `canonical_entities`

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

## 5.1 Derived endpoints

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

---

# 6. `reconciliation_claims`

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

## Name format as reconciliation

Cultural name display/entry ordering is not a column on `canonical_entities`. It is concluded like other Person-scoped facts:

```text
Property name_format -> text   # value is a name_format_profiles.key, e.g. "western"
```

- `project_settings.default_name_format_key` supplies the UI default when a person entity has no accepted `name_format` Reconciliation Claim.
- When the researcher commits a format for a Person (including as part of reconciling names across cultures), they persist a Reconciliation Claim for `name_format`.
- Evidence pins are optional for `name_format` (it is often a preference rather than source-derived); `argument` may still record why that profile was chosen.
- Concluded `name` values remain separate Reconciliation Claims (`property_key = name`, NameValue). Format and name content are related in the UI but distinct Properties.

See [`structured-name-model.md`](structured-name-model.md).

## Auto versus persisted reconciliation

| Situation | Typical handling |
|---|---|
| Compatible values (May 1985 with 14 May 1985; James with James K. Robins) | Application projection for display; no claim required |
| Light conflict with a graceful blend (Apr 1985 vs May 1985 → range) | Projection, or optional persisted claim with `origin = automatic` |
| Hard conflict or explicit researcher choice | Persisted claim with `origin = researcher`, evidence pins, and `argument` |

Absence of a Reconciliation Claim means “no durable concluded value yet,” not “no evidence.” The UI may still show member Observations and soft merges. For `name_format`, absence means “use the project default.”

## 6.1 `reconciliation_claim_evidence`

```sql
CREATE TABLE reconciliation_claim_evidence (
    reconciliation_claim_id BLOB NOT NULL
        REFERENCES reconciliation_claims(id) ON DELETE CASCADE,
    observation_id          BLOB NOT NULL REFERENCES observations(id),

    PRIMARY KEY (reconciliation_claim_id, observation_id)
) STRICT;
```

Evidence rows are pointers to Observations that participate in the claim's exhibit list — typically Observations on member Nodes that assert the same Property (or otherwise bear on the conclusion). Individual Observations do not carry a stance toward the claim; `argument` and the concluded value express the conclusion over the set.

## 6.2 Example

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

---

# 7. Canonical merge

When two canonical entities of the same `kind` should become one working subject:

```text
E-A label = "Unknown father"
E-B label = "William Smith"

Merge:
  E-A.merged_into_id = E-B
```

Typical trigger: an accepted `same_as` Claim connects Nodes that currently sit under two different canonical entities of that kind. The application merges the entities and keeps a single representative in the combined component.

Old ids and human refs should continue resolving to the surviving entity. Merge remains explicit and auditable. Reconciliation Claims on the absorbed entity must be merged or re-pointed by application rules.

---

# 8. Conclusion-layer invariants

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

# 9. Claims scope note

This draft's Conclusion Claims are:

- **Sameness Claims** (`sameness_claims`) — Node co-reference;
- **Reconciliation Claims** (`reconciliation_claims`) — concluded Property values on `canonical_entities`.

The older generic `claims` / Record-resolution tables and per-kind canonical tables (`persons`, `events`, …) are removed in favor of this model. Sameness and reconciliation remain distinct claim kinds.

---

---

# 10. Cross-layer examples

## 10.1 Photograph and testimony

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

## 10.2 Conflicting certificate and letter

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

## 10.3 DNA evidence

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

---

# 11. Open schema questions

1. **Sameness claim status vocabulary**
   - Finalize statuses (provisional, accepted, rejected, superseded, and similar) and which statuses participate in membership closure.

2. **Sameness claim evidence breadth**
   - Observations-only exhibit pins plus claim `argument` may be enough; revisit only if premise Sameness Claims or other exhibit types become common.

3. **Same-type enforcement**
   - Whether Node Type pairs on sameness Claims are application-validated only or schema-assisted.

4. **Reconciliation claim status and origin**
   - Align status vocabulary with Sameness Claims where useful; decide when automatic soft merges should be persisted (`origin = automatic`) versus display-only.

5. **Canonical `label` vs concluded names**
   - `label` remains the only intentional working field on `canonical_entities`; genealogical names and `name_format` use Reconciliation Claims.

6. **Place domain**
   - Parked for a later rewrite. `kind = place` is reserved on `canonical_entities`; Place-specific structure is out of scope until then.

7. **Human-readable refs**
   - Confirm ref assignment/format for `canonical_entities` (nullable vs required, prefix conventions by `kind`).

---

# 12. Documentation ownership

To avoid competing schema definitions:

- [`source-layer-data-model.md`](source-layer-data-model.md) is authoritative for Source-layer tables and Artifact/File storage.
- [`interpretation-layer-data-model.md`](interpretation-layer-data-model.md) is authoritative for Interpretation-layer tables and vocabulary.
- This document is authoritative for Conclusion-layer tables and Claims.
- [`structured-date-model.md`](structured-date-model.md) is authoritative for shared DateValue persistence.
- [`structured-name-model.md`](structured-name-model.md) is authoritative for shared NameValue persistence.
- [`audit-revision-history.md`](audit-revision-history.md) is authoritative for audit and revision history.
- [`data-model-source-interpretation-conclusion.md`](data-model-source-interpretation-conclusion.md) summarizes the three-layer philosophy and points here for schema detail.
