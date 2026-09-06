---
name: add-seeded-vocabulary
description: >-
  Extends Provenencia product-seeded catalog vocabulary (origin=provenencia)
  via declarative registries and idempotent Ensure. Use when adding or changing
  source types, source metadata fields, type→field suggestions, sourcevocab
  registry/Ensure, seeding Interpretation grades or name profiles later, or when
  the user mentions seeded vocabulary, dogfood seeds, or reconcile on open.
---

# Add seeded vocabulary

Shipped taxonomy is **data** reconciled at catalog open, not SQL enums and not
migration `INSERT`s. Authoritative key catalog (horizon intent): [`docs/seeded-vocabulary.md`](../../../docs/seeded-vocabulary.md) §1.1.
Source schema: [`docs/source-layer-data-model.md`](../../../docs/source-layer-data-model.md).

## Current Source seed (S2-07+)

```
core/database/sourcetypes/     # Upsert / Lookup(key, origin) / List
core/database/sourcefields/    # same + data_type text|date
core/database/sourcevocab/     # suggestions + registry.go + Ensure
```

1. Edit **`core/database/sourcevocab/registry.go`** — declarative lists:
   - `seedTypes` — `key`, `label`, `description`
   - `seedFields` — `key`, `label`, `data_type` (`text`|`date`), optional description
   - `seedSuggestions` — `(type_key, field_key, sort_order)`
2. Prefer broad semantic keys (`birth_record`) over jurisdiction document names.
3. All registry rows are **`origin = provenencia`**. Researcher/plugin rows use Upsert APIs with `user` / `plugin:<id>` — never put those in the registry.
4. **No seed `INSERT`s** in `migrations/*.sql`. DDL-only migrations for new tables.
5. Extend **`sourcevocab.Ensure`** only if the reconcile shape changes (new join table, etc.). Adding rows to the registry is enough for normal growth.
6. Tests in `sourcevocab_test.go`: empty → counts; Ensure twice idempotent; delete provenencia row/join → restored; `user` twin with same key left alone.
7. Run `CGO_ENABLED=1 go test ./core/database/sourcevocab/... ./core/onboarding/...`.

Uniqueness is **`UNIQUE (key, origin)`**. Lookup is always `(key, origin)`, never bare key. Domain FKs store vocabulary **`id`**, not key.

### Ensure semantics (pinned)

- Upsert missing `provenencia` types/fields; **refresh** label / description / data_type from registry (product owns that copy).
- Ensure suggestion joins + `sort_order`; **restore** registry joins the user removed.
- **Do not** delete `user` / `plugin:*` rows.
- **Do not** delete extra user-added suggestion joins.
- **Do not** drop `provenencia` rows retired from the registry until a later explicit policy.
- Recreating a deleted `provenencia` row mints a **new UUID**.

## Where reconcile runs (single gate)

`database.Create` / `database.Open` stay **migrate-only** (tests, low-level). Researcher-facing opens go through onboarding:

```
core/onboarding/ready.go
  createCatalog → database.Create + reconcile
  openCatalog   → database.Open + reconcile
  reconcile     → users.EnsureRefs + sourcevocab.Ensure (+ future Ensures)
```

Complete / Open / ProjectInfo / ListContributors must use **`createCatalog` / `openCatalog`**, not raw `database.Create`/`Open`. Do **not** scatter `sourcevocab.Ensure` at each use-case.

When adding another seed domain’s `Ensure`, call it from **`reconcile` only**.

## Future vocabulary domains (Interpretation, names, …)

Mirror Source — do **not** build a generic multi-domain seed framework:

1. Migration for definition tables (`origin`, `UNIQUE (key, origin)`). Follow `.cursor/skills/add-catalog-migration/SKILL.md`.
2. Nested query package(s) under `core/database/<domain>/`. Follow `.cursor/skills/add-catalog-query/SKILL.md`.
3. Package owning the seed: `registry` lists + `Ensure(c) error`.
4. Wire `Ensure` into `onboarding.reconcile` in `ready.go`.
5. Document intended keys in `docs/seeded-vocabulary.md`; implement only the dogfood slice needed now.

Join/suggestion tables have **no `origin`** column.

## Do not

- Seed via SQL migrations
- Call `sourcevocab.Ensure` from FFI handlers or Swift
- Put seed reconcile inside `database.Open`/`Create` (import cycle; couples migrate to product policy)
- Treat `provenencia` as a `builtin` boolean — use `origin`
- Expand the full horizon catalog in one PR “just because” it is listed in the docs
