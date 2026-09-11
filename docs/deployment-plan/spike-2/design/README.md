# Spike 2 — Claude Design briefs

Hand open briefs to Claude Design **one at a time**. Each is self-contained: product context, numbered requirements, screen inventory, out-of-scope, and acceptance checks.

Finished briefs live in [`archive/`](archive/). Sprint task list: [`../README.md`](../README.md); completed steps: [`../completed.md`](../completed.md).

## Open

| Step | Brief | Feeds implementation |
| --- | --- | --- |
| S2-20 | [`S2-20-files-list.md`](S2-20-files-list.md) | PR S2-21 |

## Completed

| Step | Brief | Fed |
| --- | --- | --- |
| S2-01 | [`archive/S2-01-workspace-chrome.md`](archive/S2-01-workspace-chrome.md) | PR S2-14 |
| S2-02 | [`archive/S2-02-source-fields.md`](archive/S2-02-source-fields.md) | PR S2-15 |
| S2-03 | [`archive/S2-03-source-types.md`](archive/S2-03-source-types.md) | PR S2-16 |
| S2-04 | [`archive/S2-04-sources-list.md`](archive/S2-04-sources-list.md) | PR S2-17 |
| S2-23 | [`archive/S2-23-source-detail.md`](archive/S2-23-source-detail.md) | PRs S2-24 → S2-18 → S2-25 / S2-26 |

## How to use

1. Open the existing Provenencia Claude Design project / design-system bundle used for onboarding (see `macos/App/DesignSystem/README.md` in the repo).
2. Paste **one** open brief as the prompt for a new board or flow.
3. Keep visual language aligned with onboarding (parchment neutrals, serif display, Spectral body, iron-gall accent) — do not invent a second brand.
4. Prefer existing design-system components (`Button`, `Field`, `Input`, `Select`, `Toast`, `Icon`, `LogoMark`). Add `SidebarNav` / `Card` / etc. only when the board needs them.
5. When the board is reviewable and its PR has shipped, move the brief into [`archive/`](archive/) and the step write-up into [`../completed.md`](../completed.md).

## Shared product facts (all briefs)

- Offline-first macOS genealogy app; no cloud account for this spike.
- After first-run onboarding, the user is “signed in” to a local `*.provenencia` project folder.
- Evidence lives in the **Source** layer; people/events/conclusions are later layers — do not design Interpretation chrome as active product UI in Spike 2 (Source credibility on the Source page is the intentional exception).
- Short human ids (`SRC-…`, `ART-…`, `USR-…`) are shown in mono; UUIDs are not primary UI.
- Vocabulary rows use `origin` (`provenencia` / `user` / `plugin:…`) — surface origin in admin UIs; do not invent a separate “builtin” flag.
- An Artifact has **zero or one** primary File; multiple scans are multiple Artifacts. Derivatives belong to Files.
- Workspace sidebar destinations for Spike 2: **Sources**, **Source types**, **Source fields**, **Files**.
- **Sources** uses a **separate Source page** (not master–detail like types/fields): list is S2-04; Source → Artifact → File is S2-23.
- **Sources list** is **list-style** (thumbnail rows), **not** `PVTable`. Vocabulary (fields/types) keeps the table.
