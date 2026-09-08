---
name: add-seeded-vocabulary
description: >-
  Extends Provenencia product-seeded catalog vocabulary (origin=provenencia)
  via declarative registries and create-time Install. Use when adding or changing
  source types, source metadata fields, type→field suggestions, sourcevocab
  registry/Install, seeding Interpretation grades or name profiles later, or when
  the user mentions seeded vocabulary, dogfood seeds, or create-time seed.
---

# Add seeded vocabulary

Shipped Source taxonomy is **data** installed once at catalog create, not SQL
enums and not migration `INSERT`s. Authoritative key catalog (horizon intent):
[`docs/seeded-vocabulary.md`](../../../docs/seeded-vocabulary.md) §1.1.
Source schema: [`docs/source-layer-data-model.md`](../../../docs/source-layer-data-model.md).

## Current Source seed

```
core/database/sourcetypes/     # Upsert / Lookup(key, origin) / List / Delete
core/database/sourcefields/    # same + data_type text|date
core/database/sourcevocab/     # suggestions + registry.go + Install
```

1. Edit **`core/database/sourcevocab/registry.go`** — declarative lists:
   - `seedTypes` — `key`, `label`, `description`
   - `seedFields` — `key`, `label`, `data_type` (`text`|`date`), optional description
   - `seedSuggestions` — `(type_key, field_key, sort_order)`
2. Prefer a tiny starter set. New projects get whatever is in the registry at
   create time; existing catalogs are not backfilled on open.
3. All registry rows are **`origin = provenencia`**. Researcher/plugin rows use
   Upsert APIs with `user` / `plugin:<id>` — never put those in the registry.
4. **No seed `INSERT`s** in `migrations/*.sql`. DDL-only migrations for new tables.
5. Adding rows to the registry is enough for normal growth of the create-time
   starter. Do not reintroduce open-time heal.
6. Tests in `sourcevocab_test.go`: empty → trimmed counts; user twin left alone;
   deleted rows stay deleted without re-Install. Onboarding: open does not heal.
7. Run `CGO_ENABLED=1 go test ./core/database/sourcevocab/... ./core/onboarding/...`.

Uniqueness is **`UNIQUE (key, origin)`**. Lookup is always `(key, origin)`, never bare key. Domain FKs store vocabulary **`id`**, not key.

### Install semantics (pinned)

- `sourcevocab.Install` upserts registry types/fields and suggestion joins.
- Call **only** from `onboarding.createCatalog` (after `database.Create` +
  `users.EnsureRefs`).
- **Do not** call `Install` from `OpenCatalog` or on every open.
- **Do not** heal deleted `provenencia` rows or restored suggestion joins on open.
- Calling `Install` twice would refresh labels via Upsert — create path calls it once.
- Types/fields of any origin may be deleted when unused (`ErrInUse` while referenced).

## Where create vs open run

`database.Create` / `database.Open` stay **migrate-only** (tests, low-level).
Researcher-facing paths go through onboarding:

```
core/onboarding/ready.go
  createCatalog → database.Create + users.EnsureRefs + sourcevocab.Install
  OpenCatalog   → database.Open + users.EnsureRefs
```

Complete / Open / ProjectInfo / ListContributors must use **`createCatalog` /
`OpenCatalog`**, not raw `database.Create`/`Open`. Do **not** scatter
`sourcevocab.Install` at each use-case.

When adding another seed domain’s create-time install, call it from
**`createCatalog` only** (not open), unless that domain explicitly needs
open-time policy of its own.

## Future vocabulary domains (Interpretation, names, …)

Mirror Source — do **not** build a generic multi-domain seed framework:

1. Migration for definition tables (`origin`, `UNIQUE (key, origin)`). Follow `.cursor/skills/add-catalog-migration/SKILL.md`.
2. Nested query package(s) under `core/database/<domain>/`. Follow `.cursor/skills/add-catalog-query/SKILL.md`.
3. Package owning the seed: `registry` lists + `Install(c) error` (or domain-specific name).
4. Wire install into `createCatalog` in `ready.go` when create-time-only is correct for that domain.
5. Document intended keys in `docs/seeded-vocabulary.md`; implement only the dogfood slice needed now.

Join/suggestion tables have **no `origin`** column.

## Do not

- Seed via SQL migrations (unless a later explicit backfill policy says otherwise)
- Call `sourcevocab.Install` from FFI handlers, Swift, or `OpenCatalog`
- Put seed install inside `database.Open`/`Create` (import cycle; couples migrate to product policy)
- Treat `provenencia` as a `builtin` boolean — use `origin`
- Expand the full horizon catalog in one PR “just because” it is listed in the docs
- Reintroduce open-time Ensure/heal for Source vocabulary
