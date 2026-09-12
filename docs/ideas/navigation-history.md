# Navigation history (back / forward)

**Status:** idea only — not roadmapped.

## Problem

The workspace is becoming a small web of places: sidebar destinations (Sources, Source types, Source fields, Files, …), list → **separate Source page**, master–detail selection inside vocabulary, later Node/entity pages, and cross-links (Files → Source, omnibar → anywhere).

Today, leaving a place is mostly one-way. Open a Source, jump to Files, open another Source — there is no **Back** that restores the previous view the way a browser would. Researchers who follow links (or future omnibar hits) will get stranded without a trail.

## Idea

Browser-like **Back** and **Forward** controls in the workspace chrome that move through a **session history** of views the user has visited in the open project.

```text
… → Sources list → Source SRC-… → Files → Source SRC-… → …
         ← Back                         Forward →
```

Not undo for edits. Not document-scroll history. **Navigation** history: which screen / selection was showing.

### What counts as a history entry

A stack entry should be enough to **restore** a view, roughly:

| Piece | Example |
| --- | --- |
| Sidebar destination | Sources, Source fields, Files, … |
| Deep location | Sources list vs Source page `id`/`ref`; selected field/type id; selected File id; later Node/entity id |
| Optional UI ephemera | Search query in that list? Scroll offset? — probably **omit** at first |

Push (or replace) when the user **commits** a navigation: sidebar click, list row → Source page, Files → Source link, omnibar hit, in-page back to Sources list, etc.

**Do not** push on every keystroke in a search field, every focus change, or every dirty form edit.

### Stack behavior (browser-shaped)

- **Back** — move to the previous entry; enable Forward.
- **Forward** — only after Back (or after jumping into an older entry); cleared when the user navigates somewhere **new** from the middle of the stack (standard browser truncate).
- **Same-entry coalescing** — selecting the same Source twice in a row should not spam the stack; replace or no-op if the restored location would be identical.
- **Cross-destination** — history is global to the workspace window, not per sidebar item (otherwise Back cannot leave Sources).

### Chrome

- Back / Forward buttons in the content header (or adjacent to a future omnibar), disabled when the stack cannot move that way.
- Keyboard: `⌘[` / `⌘]` or `⌘←` / `⌘→` — follow macOS document/browser conventions where they do not fight text editing.
- Optional later: long-press or menu of recent entries (title + kind), like browser tab history.

### Interaction with in-page Back

S2-23’s Source page already needs a **back to Sources list** affordance. That local control should:

- Perform the same navigation as toolbar **Back** when the previous history entry *is* the Sources list, **or**
- Always mean “up to parent list” (hierarchical), while toolbar Back means “previous history entry” (which might be Files).

Prefer documenting both: **Up** (parent) vs **Back** (history). Many Mac apps blur them; browsers do not. Provenencia will feel clearer if Source-page chevron = up to list, and toolbar = session history — especially once omnibar and cross-links exist.

## Implementation sketch

1. **Location model** — a small enum/struct: `WorkspaceLocation` (destination + optional entity id / page kind). Single source of truth for “what is on screen.”
2. **History store** — array + index on `WorkspaceModel` (session-only; do not persist across launch unless we later want “reopen where I was”).
3. **Navigate API** — `go(to:)`, `goBack()`, `goForward()`; all sidebar/deep links call `go(to:)` so the stack stays honest.
4. **Restore** — applying a location sets sidebar selection and feature-model selection/page; feature models must accept “select this id” from outside (already partly true for vocabulary).
5. **Deleted entities** — if Back would open a Source that was deleted, drop/skip that entry or show a calm empty state and prune the stack.

No FFI required for v0 — history is pure client navigation state. Omnibar and Files→Source links become history-aware automatically once they use `go(to:)`.

## Why it fits Provenencia

Evidence work is link-shaped: Source ↔ File ↔ (later) Citation ↔ Person. Without history, every cross-link is a trap. Back/Forward is the cheap complement to omnibar search: search jumps you in; history gets you out.

## Open questions

- Does switching sidebar destinations always push, or only when the destination’s deep selection changes?
- Master–detail (types/fields): does changing the selected row push an entry each time, or only destination-level until we care?
- Multiple windows later: one history per window (yes).
- Show current title in the toolbar between Back/Forward (browser style) or keep destination headers as they are?
- Persist history across relaunch? Default **no** for this note.
- Conflict with SwiftUI `NavigationStack` path vs a hand-rolled stack over sidebar + custom Source page — pick one coordinator early.

## Explicitly out of scope for this note

- Edit undo/redo, audit “revert,” or time-travel through catalog versions
- Browser-style tab strip / multiple concurrent location stacks per window
- Concrete toolbar layout in Claude Design
- Cross-project history

## Related docs

- [`omnibar-search.md`](omnibar-search.md) (jumps that should push history)
- [`macos-client-patterns.md`](../macos-client-patterns.md)
- [`S2-01-workspace-chrome.md`](../deployment-plan/spike-2/design/archive/S2-01-workspace-chrome.md)
- [`S2-04-sources-list.md`](../deployment-plan/spike-2/design/archive/S2-04-sources-list.md) / [`S2-23-source-detail.md`](../deployment-plan/spike-2/design/archive/S2-23-source-detail.md) (list ↔ Source page; local back vs history)
- [`S2-20-files-list.md`](../deployment-plan/spike-2/design/S2-20-files-list.md) (Source deep link — brief descoped with S2-21; still useful as a Files→Source jump sketch)
