---
name: add-date-value
description: >-
  Uses or extends Provenencia shared genealogical date_values (core/database/datevalues).
  Use when inserting/looking up DateValues, changing kind/qualifier/precision/timezone
  rules, date_value_id FKs, ABT/BEF/AFT, point/range dates, structured-date-model,
  or Source/Interpretation/Conclusion date metadata.
---

# Add or use a DateValue

Shared cross-layer civil dates live in **`core/database/datevalues`**, not in Source-only packages. Authoritative design: [`docs/structured-date-model.md`](../../../docs/structured-date-model.md).

New **columns** need a catalog migration first (`.cursor/skills/add-catalog-migration/SKILL.md`). Do not invent a second date representation.

## Package

```
core/database/datevalues/
  datevalues.go
  datevalues_test.go
```

Call sites: `datevalues.Insert(c, v)` / `datevalues.Lookup(c, id)`. Minted id is UUIDv7 BLOB. Domain errors: `datevalues.ErrInvalid` (`datevalues.invalid`).

## Model (authoritative)

Every DateValue is **one** genealogical date.

| `kind` | Meaning |
| --- | --- |
| `point` | One date; precision = which components are set (year / month / day / time…). |
| `range` | One date in a bounded window (`BET`); start = earliest, end = latest. Not an event duration. |

| `qualifier` (point only) | Meaning |
| --- | --- |
| `""` | As stated |
| `ABT` | About |
| `BEF` | Before / no later than the point |
| `AFT` | After / no earlier than the point |

`range` → qualifier empty (**between** is the kind, not a qualifier).

### Precision

Cascade on each side: year → month → day → hour → minute → second → millisecond. No gaps. Stop at any level. Missing finer = **unknown**, not midnight. `point` forbids `end_*`. Domain `value_text` holds attachment fidelity; DateValue `phrase` is optional wording on the value itself.

### Timezone

`StartTZ` / `EndTZ` are **free text**. Empty = unspecified. Do **not** parse to UTC in this package.

Phrase-only `point` values (no civil components) are valid when `Phrase` is set. `range` still requires a year on each side.

## Cross-layer use

Referencing tables use `date_value_id BLOB REFERENCES date_values(id)`. Prefer keeping source wording in the domain row’s `value_text` (or similar) and attaching structured `date_value_id`.

DateValues are value objects (UUID for persistence only). Concluded/refined zones or dates later should usually be **new** DateValue rows (or later-layer assertions), not silent mutation of Source evidence.

## Extending helpers

1. Prefer extending validation + constants in `datevalues` over ad-hoc SQL elsewhere.
2. Keep `apperr` codes in `core/apperr`; package owns `ErrInvalid`.
3. Functions take `*database.Catalog` today (same as `users`). Tx-scoped inserts wait until an audited write path needs them.
4. Table-driven tests in `datevalues_test.go`; run `CGO_ENABLED=1 go test ./core/database/datevalues/`.
5. Do **not** add shipped-SQL substring greps in `migrate_test.go`.

## Do not

- Store only UTC and discard civil components
- Require timezone whenever hour is set
- Put DateValue CRUD on `Catalog` or under `core/database/*.go` root
- Treat `range` as FROM–TO event duration
- Reintroduce `exact`/`year` kinds — use `point` + components
- Grep `00000N.sql` contents in unit tests to “prove” schema
