---
name: add-date-value
description: >-
  Uses or extends Provenencia shared genealogical date_values (core/database/datevalues).
  Use when inserting/looking up DateValues, changing kind/qualifier/precision/timezone
  rules, date_value_id FKs, ABT/BEF/AFT, exact/year/range dates, structured-date-model,
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

## Kinds (validated by Insert)

| Kind | Meaning | End side | Qualifier |
| --- | --- | --- | --- |
| `exact` | Calendar day required (Y/M/D); optional cascading time | Forbidden (incl. `end_tz`) | `""` / `ABT` / `BEF` / `AFT` |
| `year` | `start_year` only | Forbidden | `""` / `ABT` / `BEF` / `AFT` |
| `range` | Start + end, each cascading from year; `start <= end` | Required | Empty only |

Constants: `KindExact`, `KindYear`, `KindRange`.

### Qualifiers (point kinds only)

- `ABT` — about / approximately  
- `BEF` — before / no later than `start_*`  
- `AFT` — after / no earlier than `start_*`  

Closed spans use `range`, not BEF+AFT together.

### Precision

Cascade on each side: year → month → day → hour → minute → second → millisecond. No gaps. Missing finer fields = **unknown**, not midnight/zero.

### Timezone

`StartTZ` / `EndTZ` are **free text** (IANA, offset, historical label, “local time”). Empty = unspecified. Do **not** parse to UTC in this package; do not treat empty as UTC.

## Cross-layer use

Referencing tables use `date_value_id BLOB REFERENCES date_values(id)`. Prefer keeping source wording in the domain row’s `value_text` (or similar) and attaching structured `date_value_id` — fidelity first.

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
- Freeze a full GEDCOM date language in one PR without updating the structured-date doc
- Grep `00000N.sql` contents in unit tests to “prove” schema
