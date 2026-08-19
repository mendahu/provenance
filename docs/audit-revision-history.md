# Provenance Genealogy — Audit and Revision History

## Status

Draft architecture notes. This document defines the cross-cutting audit and revision model used by Provenance.

Audit history is **first-class research data**. It is part of the database design from the first schema version rather than a feature to retrofit after research data already exists.

The audit model applies across the Source, Interpretation, and Conclusion layers as well as supporting configuration data.

---

# 1. Design philosophy

## 1.1 Research changes are provenance

Genealogical research is iterative. Sources are described, interpretations are revised, identities are resolved, claims are accepted or rejected, and earlier conclusions may later be changed.

Those changes are themselves useful provenance.

The audit history should answer questions such as:

```text
Who created this source?
Who changed this title?
What did the value say before the change?
Which records were changed as part of this import?
What did the project contain at revision 142?
When was this person merge performed?
Was a later action an explicit undo of an earlier action?
```

The history must therefore be durable, lossless, and queryable.

## 1.2 Append-only history

Audit records are append-only.

Normal application behavior must not update or delete previous audit revisions. If a researcher reverses an earlier operation, the reversal is recorded as a new revision.

```text
Revision 140
  change title A → B

Revision 157
  undo revision 140
  change title B → A
```

Both actions remain visible.

## 1.3 Diffs are authoritative

Provenance does not store a full duplicate snapshot of every changed row at every revision.

Instead, each revision stores **lossless field-level diffs** containing both the old and new values. Because historical reconstruction is expected to be relatively infrequent, an old state may be rebuilt by replaying the revision stream.

This provides a compact history while retaining enough information to reconstruct any historical state.

## 1.4 Audit history is not domain history

The audit system records database mutations, but it does not replace explicit genealogy-domain concepts.

For example:

- a Person merge may have first-class merge semantics in the Conclusion layer;
- a rejected Claim remains a domain concept;
- a negative Claim is not merely an audit deletion;
- conflicting Interpretations remain explicit research data.

The audit log records that those domain objects changed. It does not substitute for them.

---

# 2. Revisions

A revision represents one **logical application action**.

One action may modify several rows or several tables, and those changes should remain grouped together.

```sql
CREATE TABLE audit_transactions (
    id              BLOB PRIMARY KEY,          -- UUIDv7
    revision        INTEGER NOT NULL UNIQUE,
    user_id         BLOB REFERENCES users(id),
    action_type     TEXT,
    description     TEXT,
    created_at      TEXT NOT NULL
);
```

## 2.1 `revision`

`revision` is a monotonically increasing project-local sequence number.

It provides deterministic ordering independent of wall-clock timestamps:

```text
Revision 140
Revision 141
Revision 142
```

`created_at` remains useful descriptive information, but timestamps are not the authoritative ordering mechanism.

For a local SQLite project, revision allocation and the corresponding domain changes should occur inside the same database transaction.

## 2.2 `user_id`

`user_id` identifies the researcher or application user responsible for the logical action.

This provides durable creator/editor traceability without requiring `created_by_user_id` and `updated_by_user_id` columns on every domain table.

For example, the creator of a Source can be determined from the revision containing that Source's `create` audit change.

Major entities may later denormalize creator information if a concrete performance or UX need appears, but the audit history remains authoritative.

Some system-generated operations may require a system actor rather than a human user. The exact user/system-actor model remains a separate schema concern.

## 2.3 Action type

`action_type` describes the human-meaningful operation represented by the revision.

Possible examples:

```text
create_source
update_source
update_source_metadata
attach_artifact
create_interpretation
resolve_record
merge_person
reject_claim
import_gedcom
undo_revision
```

The action vocabulary is extensible and may evolve independently of the row-level mutation model.

`description` may contain additional human-readable context but should not be required for deterministic reconstruction.

---

# 3. Row-level changes

Each row affected by a revision receives an `audit_changes` entry.

```sql
CREATE TABLE audit_changes (
    id                      BLOB PRIMARY KEY,   -- UUIDv7
    audit_transaction_id    BLOB NOT NULL
        REFERENCES audit_transactions(id),

    entity_type             TEXT NOT NULL,
    entity_id               BLOB NOT NULL,
    action                  TEXT NOT NULL,
    changes_json            TEXT NOT NULL,

    CHECK (action IN ('create', 'update', 'delete'))
);
```

The audit tables themselves should not be audited recursively.

## 3.1 Entity identity

`entity_type` identifies the table/domain row type and `entity_id` identifies the persistent row.

For example:

```text
entity_type = source
entity_id   = <UUID>
```

or:

```text
entity_type = source_metadata
entity_id   = <UUID>
```

The generic reference intentionally does not use a relational foreign key because audit history must continue to describe rows after those rows have been deleted.

## 3.2 Lossless diffs

`changes_json` contains only fields affected by the operation, but each changed field records both its previous and resulting value.

```json
{
  "title": {
    "old": "Robins Family History",
    "new": "The Robins Family History"
  },
  "description": {
    "old": null,
    "new": "Compiled family history"
  }
}
```

Storing both sides makes a revision independently understandable and allows replay in either direction.

### Create

A create records the complete initial persistent state of the row as transitions from non-existence to values.

Conceptually:

```json
{
  "id": {
    "old": null,
    "new": "..."
  },
  "title": {
    "old": null,
    "new": "The Robins Family History"
  }
}
```

The create event must contain enough information to construct the original row without consulting the current live row.

### Update

An update records only changed fields:

```json
{
  "title": {
    "old": "Robins Family History",
    "new": "The Robins Family History"
  }
}
```

Unchanged columns are omitted.

### Delete

A delete records enough previous state to reconstruct the deleted row, with values transitioning to non-existence.

Conceptually:

```json
{
  "id": {
    "old": "...",
    "new": null
  },
  "title": {
    "old": "The Robins Family History",
    "new": null
  }
}
```

Deletion therefore does not destroy the historical content needed for reconstruction.

---

# 4. Transaction grouping

One application operation may modify many rows.

For example, creating a Source could produce:

```text
Revision 142
User: Jake
Action: create_source

Changes:
  CREATE source SRC-F4N2P
  CREATE source_metadata author
  CREATE source_metadata publication_date
  CREATE artifact scan.pdf
```

All four `audit_changes` rows reference the same `audit_transaction_id`.

This preserves two complementary views of history:

1. **Research action** — what the researcher did.
2. **Row mutations** — exactly what persistent data changed.

The first is useful to humans. The second makes the history lossless and replayable.

---

# 5. Atomicity requirements

A domain mutation and its audit revision must commit atomically.

The application must not be able to successfully change research data without recording the corresponding audit history, nor should an audit revision survive if the underlying domain mutation rolls back.

Conceptually:

```text
BEGIN TRANSACTION

allocate revision
insert audit_transaction
perform domain writes
insert audit_changes

COMMIT
```

If any part fails, the entire SQLite transaction rolls back.

Audit creation should therefore be part of the central persistence/write path rather than an optional logging call individual features may forget to make.

Direct writes that bypass the audited persistence path should be treated as exceptional maintenance operations.

---

# 6. Historical reconstruction

The audit history must be sufficient to reconstruct project or entity state at any revision.

To reconstruct forward from project creation:

```text
start with empty state
apply revisions 1..N
```

To reconstruct a particular entity, the application may replay only changes for its `(entity_type, entity_id)`.

Because reconstruction is expected to be infrequent, the initial design favors correctness and audit clarity over optimized historical reads.

If historical reconstruction later becomes expensive, Provenance may introduce **derived checkpoints** or cached snapshots at intervals. Such snapshots would be performance artifacts only; the append-only diff stream would remain authoritative and disposable checkpoints could always be rebuilt from it.

---

# 7. Schema evolution

Long-lived audit history will span multiple database schema versions. This needs to be considered from the beginning.

Audit diffs describe the persistent representation that existed when the change occurred. Older revisions may therefore contain fields that were later renamed or removed, and may lack fields introduced in newer schemas.

Historical reconstruction code must be version-aware rather than assuming that every historical diff matches the current schema.

A likely future addition is a schema-version identifier on `audit_transactions`, for example:

```sql
schema_version INTEGER NOT NULL
```

The exact migration/versioning mechanism should be designed alongside the application's migration system before implementation begins.

---

# 8. Relationship to timestamps on domain rows

Tables may continue to contain ordinary fields such as:

```text
created_at
updated_at
```

These are convenient current-state data and should not be considered the historical record.

The audit stream answers who changed a row, how it changed, and in which revision. The domain timestamps answer when the current row was created or last updated without requiring an audit query.

Similarly, explicit `created_by_user_id` or `updated_by_user_id` columns should not be added mechanically to every table. Creator/editor attribution is already represented authoritatively by revisions unless a specific current-state query justifies denormalization.

---

# 9. Undo and reversal

Undo must create a new revision rather than remove history.

For example:

```text
Revision 200
  merge PER-A into PER-B

Revision 208
  undo Revision 200
```

Revision 208 applies inverse domain mutations and records their diffs normally.

Where the domain has explicit semantics for reversal, those semantics should also be respected. Audit reversal is not a shortcut around domain invariants.

A future `reverses_transaction_id` reference on `audit_transactions` may be useful to explicitly connect undo revisions with the revisions they reverse.

---

# 10. Initial implementation principles

The first implementation should follow these rules:

1. Audit support exists in schema version 1.
2. Ordinary persistent writes are always wrapped in an `audit_transaction`.
3. Revision numbers provide deterministic ordering.
4. A revision groups every row mutation belonging to one logical action.
5. Diffs contain both old and new values.
6. Create and delete events contain enough state for full reconstruction.
7. Audit rows are append-only.
8. Undo creates a new revision.
9. The audit stream is authoritative; snapshots are derived data.
10. Audit history supplements rather than replaces Source, Interpretation, Conclusion, Claim, and merge semantics.

The goal is not merely to know that data changed. Provenance should be able to explain **how the research database arrived at its current state**.