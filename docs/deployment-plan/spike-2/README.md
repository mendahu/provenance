# Spike 2 — Source layer catalog (schema, CRUD, ingest UI)

## Status

**Done.** Source-layer catalog validated end-to-end (schema → Go CRUD/ingest → FFI → macOS workspace UI). Finished steps: [`completed.md`](completed.md). How to dogfood: [`dogfood.md`](dogfood.md). Design briefs: [`design/archive/`](design/archive/).

Authoritative models:

- [`source-layer-data-model.md`](../../source-layer-data-model.md)
- [`artifact-file-storage.md`](../../artifact-file-storage.md) (pointer → Source layer)
- [`seeded-vocabulary.md`](../../seeded-vocabulary.md) §2
- [`audit-revision-history.md`](../../audit-revision-history.md)
- [`structured-date-model.md`](../../structured-date-model.md)
- [`catalog-refs.md`](../../catalog-refs.md)
- [`application-stack.md`](../../application-stack.md) (FFI granularity, `objects/` ingest)
- [`macos-client-patterns.md`](../../macos-client-patterns.md)

Claude Design handoffs live in [`design/`](design/) — self-contained requirement briefs, not the task list below. Design **S2-01…S2-04** / **S2-23** done ([`design/archive/`](design/archive/), [`completed.md`](completed.md)). **S2-20** / **S2-21** (project Files list) are **descoped** — see [Descoped](#descoped). Dogfood checklist: [`dogfood.md`](dogfood.md).

Spike 1 left an explicit gate: **the first researched mutation must write audit**, not decorative empty tables without a write path. This spike owns that gate.

---

## Goal

A signed-in researcher can, in a real `*.provenencia` project:

1. Work inside an **app workspace** (sidebar + content) instead of a one-screen onboarding home forever.
2. Create a Source (type, title, description, notes, descriptive metadata).
3. Extend the project’s Source types and metadata fields when the seeded set is not enough.
4. Add Artifacts under a Source (including fileless / physical-only placeholders).
5. Ingest a local file into content-addressed `objects/`, attach it as an Artifact’s primary File, and see enough UI to verify the model (list, detail, metadata, type extension).

That is enough to **validate** the Source-layer schema and storage rules before Interpretation work begins.

```text
Onboarding (Spike 1) → signed in
  → App workspace (sidebar + content)
       ├── Sources (list → separate Source page)
       │     ├── type + title + notes + metadata
       │     ├── extend types / fields (project-local)
       │     └── Artifacts
       │           ├── fileless placeholder
       │           └── ingest File → objects/{hh}/{hh}/{sha256} → Artifact.file_id
       ├── Source types / Source fields (vocabulary admin)
       └── Project / session (sign out, project label, contributor)
```

(Project-wide **Files** list was planned as S2-20/S2-21; descoped. File ingest and open still happen from the Source page.)

---

## In scope

- **App workspace chrome**: side navigation + content host. Spike 2 destinations: **Sources**, **Source types**, **Source fields** (no “coming soon” stubs for later layers). A **Files** sidebar placeholder from S2-14 may remain; building its list UI is not in scope.
- Audit write path (`audit_transactions` / `audit_changes`) used by every Source-layer mutation.
- Shared `date_values` table (schema + minimal Go helpers) so date-typed Source metadata can land without a second migration later.
- Full Source-layer table set from the Source doc: `source_types`, `sources`, `source_notes`, `source_metadata_fields`, `source_type_metadata_fields`, `source_metadata`, `artifacts`, `files`, `file_derivatives`.
- Small **seed** of types/fields (not the entire [`seeded-vocabulary.md`](../../seeded-vocabulary.md) horizon list). Create-time starter today: `birth_certificate` plus a few suggested fields; opens do not heal or expand the set.
- Go domain packages for CRUD + ingest; FFI use-cases (coarse verbs); SwiftUI Source catalog UI inside the workspace, consuming `GenealogyStore`.
- Claude Design boards for workspace chrome, Source fields, Source types, Sources list, and Source page (Source → Artifact → File).
- Refs: mint `SRC-…` / `ART-…` via `core/ref` on insert ([`catalog-refs.md`](../../catalog-refs.md)).

## Out of scope (later spikes)

- **Project Files list** (design S2-20 + Swift S2-21) — descoped; ingest/open stay on the Source page.
- Interpretation beyond Source credibility on the Source page (Citations, Observations, Nodes) and Conclusion — do not add sidebar placeholders for them in this spike.
- Claim confidence and Citation transcription certainty ([`research-judgment-model.md`](../../research-judgment-model.md)).
- Full GEDCOM / import adapters.
- Destructive primary File deletion; orphan GC of historically referenced Files.
- Rich audit UI / timeline browser (writes must exist; browsing history can wait).
- Open/create project flows beyond what Spike 1 already shipped (“continue as / that’s not me” polish is a separate spike unless it blocks dogfood).
- Windows client, sync, cloud accounts, notarization.
- Shipping the entire seeded vocabulary catalog on day one.

---

## Non-negotiable constraints (from docs)

1. **Audit atomicity** — domain write + audit revision in one SQLite transaction ([`audit-revision-history.md`](../../audit-revision-history.md) §5).
2. **No `created_at` / `updated_by` on Source tables** — attribution lives in audit.
3. **File bytes never travel over protobuf** — ingest use-case; read path returns relative `objects/…` path; Swift reads bytes ([`application-stack.md`](../../application-stack.md)).
4. **Content-addressed immutability** — `objects/{hh}/{hh}/{full hex}`; File bytes never change in place. Better/clearer scan = **new Artifact** (not pointer-swap under an existing `ART-…`; Citations locate into Artifacts).
5. **Derivatives belong to Files**, not Artifacts; generation need not audit.
6. **Swift stays thin** — Go owns schema, ingest, validation; models + `FakeStore` for tests.
7. **Seed small; grow from use** ([`seeded-vocabulary.md`](../../seeded-vocabulary.md) §1).

---

## Definition of done

Jake can, on his MacBook, without a server:

1. Finish Spike 1 onboarding and land in an **app workspace** with a sidebar (not the old single “you’re signed in” home as the permanent shell).
2. Use the sidebar to open Sources, Source types, and Source fields.
3. Create a Source of a seeded type, edit title/description, add a note, set text (and at least one date) metadata fields suggested for that type.
4. Add a custom Source type and/or metadata field (from their nav destinations) and use them on a Source.
5. Add a fileless Artifact and an Artifact with an ingested image/PDF; confirm `files` row + bytes under `objects/`.
6. Inspect `provenencia.sqlite`: Source-layer rows present; audit revisions recorded for creates/updates; `SRC-…` / `ART-…` refs present.
7. Relaunch: workspace returns; catalog still lists the Sources; File still opens from the relative path.

---

## Step numbering

Steps are **`S2-NN`** (Spike 2, two-digit sequence). Each step has a **kind**:

| Kind | Meaning |
| --- | --- |
| **Design** | Claude Design (and/or local UX writing). No product code required to “complete,” but outputs feed later PRs. |
| **PR** | Mergeable change on `main`; leave the app buildable. |
| **Doc** | Docs/rules/skills only when a decision must land before code. |

IDs stay stable even if order of *starting* work shifts; **Depends on** is the merge/start gate. When a step finishes, move its write-up to [`completed.md`](completed.md) and leave a short pointer here only if something still depends on reading it.

---

## Dependency sketch

None — Spike 2 is complete. All PR/Design steps (and descoped S2-20/S2-21) are recorded in [`completed.md`](completed.md) and [Descoped](#descoped).

---

## Open steps

_None._ Finished Design/PR write-ups live in [`completed.md`](completed.md). Descoped IDs stay listed under [Descoped](#descoped) so numbering stays stable.

---

## Descoped

IDs kept for history; do not implement in Spike 2.

### S2-20 — Design: Files list (project file browser) — **descoped**

**Claude Design brief (frozen):** [`design/S2-20-files-list.md`](design/S2-20-files-list.md)

| | |
| --- | --- |
| **Kind** | Design (Claude Design) |
| **Status** | Descoped — no Claude Design board; no Files list in this spike. |
| **Was going to** | Board for the **Files** destination (thumbnail, media type, original filename, link to Source). |
| **Why** | File ingest and open are already validated on the Source page; a project-wide Files browser is not needed to close Spike 2. |

---

### S2-21 — PR: Swift Files list (+ Source link) — **descoped**

| | |
| --- | --- |
| **Kind** | PR |
| **Status** | Descoped with S2-20. |
| **Was going to** | `ListFiles` FFI + Swift **Files** destination (list → jump to Source), reusing `PVList` / S2-26 thumbs. |
| **Why** | Same as S2-20 — Source-page ingest/open is enough for dogfood. |

---

## Suggested PR titles (why-focused)

| Step | Title sketch |
| --- | --- |
| S2-19 | Harden the Source catalog for first dogfood |

---

## Parallelism and team split

| Track | Steps |
| --- | --- |
| **Design (Claude Design)** | S2-01…S2-04 / S2-23 done; **S2-20** descoped |
| **Core schema / Go** | S2-05…S2-13 / **S2-24** / **S2-25** layout — done ([`completed.md`](completed.md)) |
| **FFI + Mac** | S2-14…S2-18 / S2-22 / S2-24 / **S2-25** / **S2-26** / **S2-19** — done; **S2-21** descoped |

Prefer **many small PRs**. Do not fold the workspace shell into feature destination PRs.

---

## Explicit non-goals checklist (keep PRs honest)

- [ ] No Citation / Observation / Node tables or RPCs (sidebar stubs only) — **except** Source credibility grades/assessments shipped with **S2-24** / UI in **S2-18**
- [ ] No Claim confidence UI
- [ ] No File bytes in protobuf
- [ ] No deletion of primary Files
- [ ] No full vocabulary dump from `seeded-vocabulary.md` (credibility grades seed is the three-point set only)
- [ ] No audit history browser required for done

---

## After Spike 2

Likely next spikes (not scheduled here):

1. Fill sidebar destinations beyond Sources / types / fields (Interpretation entry, Settings, optional project Files browser from descoped S2-20/S2-21) when those features exist.
2. Audit history UI / “what changed” for a Source.
3. Citation → Observation → Node (Interpretation) on top of Artifacts.
4. Project open/create UX polish beyond Spike 1 onboarding.
5. Richer date entry and more seeded types driven by real cataloging sessions.
