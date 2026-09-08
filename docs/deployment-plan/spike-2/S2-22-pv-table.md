# S2-22 — Implementation brief: `PVTable` (custom-chrome table)

**Spike step:** [S2-22 in README](README.md#s2-22--pr-pvtable--custom-chrome-table-with-keyboarda11y)  
**Kind:** PR (Swift / design system)  
**Depends on:** S2-15 (Source fields list exists to extract from)  
**Feeds:** S2-16+ vocabulary/catalog lists should prefer `PVTable`

This brief is the **source of truth for implementing the PR**. It encodes a deliberate product decision: keep custom Provenencia chrome (not SwiftUI `Table` / AppKit `NSTableView`), but reach **keyboard and accessibility parity** with a native macOS data table for single-selection browse lists.

---

## Product decision (do not reopen in the PR)

| Choice | Decision |
| --- | --- |
| Native `Table` / `List` | **No** — visual fidelity to the design system (micro-caps headers, selected accent bar, hover chrome, badge cells) wins over system table chrome. |
| Custom design-system component | **Yes** — name it **`PVTable`**, under `macos/App/DesignSystem/Components/Data/`. |
| Scope of this PR | Extract the Source fields hand-rolled list into `PVTable`, wire Source fields to it, add keyboard + a11y. Do **not** implement Source types / Sources / Files lists here (those come in later PRs and should *consume* `PVTable`). |
| Deployment target | macOS **14.0** — use `.focusable()`, `.onKeyPress`, `.focusEffectDisabled()`, `ScrollViewReader`. No AppKit `NSViewRepresentable` required. |

---

## Current code to extract (starting point)

Today’s Source fields “table” is assembled by hand in:

- [`macos/App/Features/SourceFields/SourceFieldsListPane.swift`](../../../macos/App/Features/SourceFields/SourceFieldsListPane.swift) — search bar, column header, `ScrollView` + `LazyVStack` of rows, footer
- [`macos/App/Features/SourceFields/SourceFieldsRow.swift`](../../../macos/App/Features/SourceFields/SourceFieldsRow.swift) — row layout + `SourceFieldsRowStyle` (hover/selected chrome)
- Shared badges already centralized in [`SourceFieldsBadges.swift`](../../../macos/App/Features/SourceFields/SourceFieldsBadges.swift) — reuse those as cell content; do not move vocabulary mapping into `PVTable`

Static column widths live on `SourceFieldsRow` (`keyColumnWidth`, etc.) and are duplicated in the list pane’s header. After extraction, **column definitions are the single source of truth** for widths.

---

## Deliverables checklist

### 1. Extract `PVTable`

Create:

```text
macos/App/DesignSystem/Components/Data/PVTable.swift
```

(Optional split if the file grows: `PVTableColumn.swift`, `PVTableTypeSelect.swift` — keep one module unless readability suffers.)

Suggested public shape (adapt as needed; keep it generic and composable):

```swift
struct PVTableColumn<Row: Identifiable> {
    let title: LocalizedStringResource
    let width: CGFloat?          // nil = flexible (fills remaining space)
    let sortable: Bool           // only one sortable column required for v1 (Label today)
    let cell: (Row) -> AnyView   // or a @ViewBuilder / result-builder if cleaner
}

struct PVTable<Row: Identifiable>: View {
    let rows: [Row]              // caller supplies already filtered/sorted rows
    let columns: [PVTableColumn<Row>]
    @Binding var selection: Row.ID?
    var sortAscending: Binding<Bool>?   // nil if no sortable columns
    var onToggleSort: (() -> Void)?     // or bind sort through the model
    var accessibilityLabel: LocalizedStringResource
    var rowAccessibilityIdentifier: ((Row) -> String)?
    // optional footer slot via @ViewBuilder
}
```

Requirements:

- Render **column header** with existing micro-caps style (uppercase, tracking, muted foreground).
- Render **rows** with shared hover / selected chrome (reuse the pattern from `SourceFieldsRowStyle` / `PVHoverEffect`).
- Selected row: leading **2pt accent bar** + `PVColor.surfaceSelected` background (match current Source fields look).
- Row separators: 1pt `PVColor.borderSubtle` (current look).
- Wire into Xcode project (`project.pbxproj`) like other DesignSystem files.
- Add `#Preview` with fake rows.
- Update [`macos/App/DesignSystem/README.md`](../../../macos/App/DesignSystem/README.md): add `PVTable` to the built-components table; document the tradeoff (custom chrome vs native `Table`) and the interaction contract below.

### 2. Migrate Source fields list pane

- Replace the hand-rolled header + `LazyVStack` + `SourceFieldsRow` layout in `SourceFieldsListPane` with `PVTable`.
- Keep the **search bar** and **result footer** in the list pane (they are feature chrome, not table chrome) — or expose a footer slot on `PVTable` if that is cleaner; either is fine.
- Column cells for Source fields:
  - Label → `Text(field.label)`
  - Key → mono `Text(field.key)`
  - Data type → `SourceFieldDataTypeBadge`
  - Origin → `SourceFieldOriginBadge`
- Preserve existing `.accessibilityIdentifier`s (`sourceFields.list`, `sourceFields.row.\(id)`, `sourceFields.sortByLabel`, etc.).
- Delete or shrink `SourceFieldsRow.swift` once layout lives in `PVTable` (row style may move into DesignSystem as private to `PVTable`).
- Visual regression: list should look like today’s Source fields table (no redesign).

### 3. Keyboard interaction (native-parity)

Implement on the table body (not per-cell):

| Action | Behavior |
| --- | --- |
| Focus | Table is `.focusable()`. Suppress system focus ring with `.focusEffectDisabled()`; if a focus affordance is needed, use design-system `pvFocusRing` on the container (same rule as `PVInput`: never swap view *structure* on focus). |
| ↑ / ↓ | Move selection through **visible** `rows` (already filtered/sorted by the model). Clamp at ends — **do not wrap**. |
| ⌥↑ / Home | Select first row. |
| ⌥↓ / End | Select last row. |
| Scroll into view | Wrap rows in `ScrollViewReader`; on selection change from keyboard (and mouse if easy), `scrollTo` the selected id so the row stays visible. |
| Type-to-select | Accumulate alphanumeric `.onKeyPress` characters into a buffer that resets after ~0.8s; jump to first row whose **primary text** (caller-supplied key path or closure, e.g. `\.label`) has that prefix (case-insensitive). |
| Tab order | Search field → sort header (if present) → table → detail pane. Verify with full keyboard access on. |

**Focused vs unfocused selection:** when the table is not focused, dim the selection highlight (native Mac tables do this). Prefer an existing muted/selected token, or add a single design-system color if needed (`surfaceSelectedInactive` or equivalent) — do not invent one-off hex colors.

Extract type-to-select buffering into a small **pure** helper (e.g. `PVTableTypeSelectMatcher` or `TypeSelectMatcher`) so it is unit-testable without UI.

### 4. Accessibility (VoiceOver)

| Requirement | Detail |
| --- | --- |
| Rows | `.accessibilityElement(children: .combine)` so one row reads as one element (“Author, author, text, Seeded”). |
| Selection | `.accessibilityAddTraits(.isSelected)` on the selected row. |
| Container | `.accessibilityElement(children: .contain)` + caller-supplied `accessibilityLabel` (e.g. Source fields → use existing L10n title). |
| Sort header | Announce ascending/descending via `.accessibilityValue` (new `L10n.DesignSystem` strings — follow [`.cursor/skills/add-localized-string`](../../../.cursor/skills/add-localized-string/SKILL.md)). Do not rely on the chevron alone (`PVIcon` is `accessibilityHidden`). |
| Honest limit | Custom views cannot claim AppKit’s table grid role (“table, row 3 of 12, column 2”). Combined-row / list-like semantics are **acceptable** for this single-selection browse list. Document that limit in the DesignSystem README. |

### 5. Tests

Under `macos/ProvenenciaTests/` (Swift Testing; follow [`.cursor/skills/add-swift-test`](../../../.cursor/skills/add-swift-test/SKILL.md)):

- `TypeSelectMatcher` / selection-movement helpers: prefix match, buffer timeout semantics if modeled as pure functions, move up/down/clamp, first/last.
- Existing `SourceFieldsModelTests` must keep passing (selection still goes through the model).
- No XCUITest required in this PR unless already easy; prefer unit tests of pure logic.

### 6. Localization

- Any new user-facing strings (sort ascending/descending accessibility values, optional table a11y labels if not reusing existing) via `L10n` + String Catalog — skill above.
- Do not hard-code English in views.

### 7. Out of scope for S2-22

- Rewriting Source types / Sources / Files lists (consume `PVTable` in those PRs).
- Multi-select, column resize, column reorder, drag-and-drop.
- Switching to SwiftUI `Table` / `NSTableView`.
- Changing Source fields data model, FFI, or badge vocabulary mapping.
- Broader DesignSystem cleanup items from the quality review (those are separate).

---

## Suggested implementation order (for the agent)

1. Extract `PVTable` + migrate Source fields visually (no new keyboard yet) — app still looks the same.
2. Arrow keys + `ScrollViewReader` + focus / selection dimming.
3. Type-to-select helper + wiring.
4. VoiceOver traits / combine / sort `accessibilityValue`.
5. Unit tests + DesignSystem README + L10n.
6. `xcodebuild test -project macos/Provenencia.xcodeproj -scheme Provenencia -destination 'platform=macOS'`.

---

## Suggested PR title

**Extract a design-system table with keyboard and VoiceOver parity**

---

## Acceptance criteria

- [ ] Source fields list uses `PVTable`; hand-rolled column-width duplication is gone.
- [ ] Visual look matches pre-refactor Source fields (custom chrome retained).
- [ ] Arrow keys move selection; selection scrolls into view; type-to-select jumps by label prefix.
- [ ] Selection highlight dims when the table is unfocused.
- [ ] VoiceOver reads each row as one element; selected trait present; sort state announced.
- [ ] Unit tests cover type-select / selection movement helpers.
- [ ] DesignSystem README documents `PVTable` and the native-`Table` tradeoff.
- [ ] `xcodebuild test` passes.
