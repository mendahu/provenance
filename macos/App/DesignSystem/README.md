# Provenencia design system (macOS)

## What this is

Provenencia's brand is "modern but archival": warm parchment neutrals, serif
type throughout, hairline rules, and a palette of seven historical pigment
hues (iron gall, madder, verdigris, ochre, lapis, plum, copper) doing real
informational work — evidence grades, record types, lineage lines. See
`tokens/colors.css`'s comment block (referenced below) for the full
rationale; this file only covers how that system is expressed in Swift.

## Provenance

The design system was authored in Claude Design as project **"Genealogy app
onboarding flow"** (`b51790c9-7f65-4e91-a7ef-a900095c5870`), design-system
bundle `provenencia-design-system-0f6c1f29-8408-4735-b114-5ae4c4c18445`. That
project represents the system as CSS custom properties and a React
component library — that's how Claude Design renders an interactive browser
preview for review, not something that ships. `tokens/*.css` in that project
is the source of truth for every value in `Tokens/`; there's no live sync
between it and this folder, so **when a token changes on the design-system
side, re-transcribe it here by hand.**

The project also contains one mockup board, `Onboarding Flow.dc.html`,
showing the 8 window states of this app's actual onboarding flow. Per that
project's own sync log, it was built by reading the shipped onboarding
SwiftUI files. Those screens have been restyled to consume `PV*` tokens and
components directly.

## Token file map

| CSS file | Swift file | Holds |
|---|---|---|
| `tokens/colors.css` | `Tokens/PVColor.swift` | Palette ramps (`PVPalette`) + semantic aliases (`PVColor`), light/dark aware |
| `tokens/fonts.css` + `tokens/typography.css` | `Tokens/PVTypography.swift` | Font families, type scale, weights, tracking, line-heights, `PVFont` factories |
| `tokens/spacing.css` | `Tokens/PVSpacing.swift` | Space scale, gutters, measures, layout widths, control heights |
| `tokens/radii.css` | `Tokens/PVRadius.swift` | Corner radii |
| `tokens/elevation.css` | `Tokens/PVElevation.swift` | Shadows, focus ring, `.pvShadow`/`.pvInsetShadow`/`.pvFocusRing` modifiers |
| `tokens/motion.css` | `Tokens/PVMotion.swift` | Durations, easing curves, press-scale, lift-hover |

Every value in these files is transcribed from the CSS, not invented.
Reach for `PVColor`/`PVFont`/`PVSpacing`/`PVRadius`/`PVElevation`/`PVMotion`
at call sites — never a literal color, font, or number.

## The component pattern

`Components/Core/PVButton.swift` is the **canonical example** — read its
header comment before adding a new component. In short:

- A component lives at `Components/<Category>/PV<Name>.swift`, where
  `<Category>` mirrors the web design system's own `components/<category>/`
  folder (`core`, `forms`, `navigation`, `feedback`, `research`).
  `PVButton` is `components/core/Button.jsx` → `Components/Core/PVButton.swift`.
- The file's header comment names the `.jsx` it mirrors and calls out any
  deliberate deviation (a prop that isn't ported yet, a platform-specific
  approximation).
- The type only ever reaches for `PV*` tokens — never a literal color,
  font, or size.
- User-facing text is a `LocalizedStringResource`, never a raw `String`
  (`docs/macos-client-patterns.md` §6); a select/list of *data* (a project
  name, a person's name) stays a plain `String` — it isn't translatable UI
  copy.
- `.accessibilityIdentifier` is left to the call site
  (`docs/macos-client-patterns.md` §5) — components don't invent their own.
- Hover/pressed/focus state lives in a private backing `View` or
  `ButtonStyle`, not on the public type (see `PVButtonBody` in
  `PVButton.swift`).
- Each component file ends with a `#Preview` using static sample data (no
  live `GenealogyStore` needed).

To add another component: pick its category folder (create it if this is the
first component in that category), copy `PVButton.swift`'s shape, and read
its exact CSS/JS spec out of the source design-system project first — don't
guess at colors/spacing/sizes.

**Check `swift/` in the source project before porting anything.** That
project ships a Swift reference implementation (`ProvenenciaTokens.swift`,
`ProvenenciaCore.swift`, …) alongside the CSS/JSX, and its own `SKILL.md`
says to use those APIs "rather than translating CSS by hand." Several
components here were re-derived from the CSS instead, and at least one of
them lost a detail the Swift reference had already got right — see below.

## Interaction state

**Never branch view structure on focus, hover, pressed, or selected.**
Those states change *values* — color, opacity, offset — on a view that is
**always present**:

```swift
// WRONG — swaps view identity when focus flips
if isFocused { content.pvFocusRing(…) } else { content.pvInsetShadow(…) }

// RIGHT — one view, always applied; only the opacity changes
content
    .pvInsetShadow(cornerRadius: PVRadius.sm, visible: !isFocused)
    .pvFocusRing(isFocused, cornerRadius: PVRadius.sm)
```

An `if/else` in a `ViewBuilder` compiles to `_ConditionalContent` — two
different view types — so SwiftUI rebuilds that subtree whenever the
condition flips. Around a text field that tears down the underlying
`NSTextField` *at the instant focus arrives*, destroying the first
responder it just gained: the field won't accept a click, or takes exactly
one keystroke and then every key beeps. Nothing catches this — the code
reads correctly, there are no UI tests, and `#Preview` doesn't exercise
focus. `PVInput` shipped with this bug for exactly that reason.

The same applies to `.animation(_:value:)` keyed on an interaction flag:
scope it to the decorative shape, never to a wrapper containing the
control. `pvFocusRing(_:cornerRadius:)` and `pvInsetShadow(cornerRadius:
visible:)` both take the state as a parameter so the call site never needs
a branch — that mirrors the design system's own `pvFocusRing(_:radius:)`.

This generalizes: the web kit's CSS is full of ternaries like
`boxShadow: focus ? 'var(--ring-focus)' : 'var(--shadow-inset)'`. In CSS
that's a *property value* swap and costs nothing. Port it as a value swap,
not as a conditional view. `Select`, `Checkbox`, and `Switch` all have the
same shape waiting in their specs.

## What's built vs. not yet

The components the **Onboarding Flow** board actually uses, plus `Toast`
(added when onboarding needed a way to surface errors that wasn't an inline
red `Text`), plus `Badge`/`EmptyState`/`Callout` (added for the S2-02
**Source fields** board — see `Features/SourceFields/`):

| Component | File | 
|---|---|
| Button | `Components/Core/PVButton.swift` (icon-left, loading spinner, and a chrome-less `link` variant added for S2-02) |
| Icon | `Components/Core/PVIcon.swift` |
| Field | `Components/Forms/PVField.swift` |
| Input | `Components/Forms/PVInput.swift` |
| Select | `Components/Forms/PVSelect.swift` |
| Toast | `Components/Feedback/PVToast.swift` |
| LogoMark | `Components/Core/PVLogoMark.swift` |
| SidebarNav | `Components/Navigation/PVSidebarNav.swift` (added for the S2-01 workspace chrome; ports that board's revised `collapsed`-capable `SidebarNav.jsx`) |
| IconButton | `Components/Core/PVIconButton.swift` (added for the workspace sidebar's collapse toggle, which needed real hover feedback; `label` is required per `IconButton.jsx` and doubles as the `.help` tooltip, and `tone: .danger` tints a destructive action) |
| Badge | `Components/Core/PVBadge.swift` (added for S2-02's data-type/origin badges; a glyph-only variant carries the S2-22 seeded pill) |
| Divider | `Components/Core/PVDivider.swift` (1pt hairline; horizontal/vertical) |
| EmptyState | `Components/Feedback/PVEmptyState.swift` (added for S2-02's empty/no-match states; the web spec's `action` slot isn't ported — see the file's header comment) |
| Callout | `Components/Feedback/PVCallout.swift` (added for S2-02's "this field is locked" note; only the subset S2-02 needs is ported — see the file's header comment) |
| Table | `Components/Data/PVTable.swift` (added for S2-22, extracted from the Source fields list; see "The table tradeoff" below) |
| Dialog | `Components/Feedback/PVDialog.swift` (added for S2-22's delete confirmation; renders the panel only — presentation is a macOS `.sheet` at the call site, see the file's header comment) |

The other 13 design-system components have **no files yet** — add them on
demand, following the pattern above, when a screen needs one:

| Component | Category | Purpose |
|---|---|---|
| Card | Core | Bordered content container with optional header/footer |
| Tag | Core | Removable/interactive pill with a color dot |
| Tooltip | Core | Hover label — on macOS this is usually SwiftUI's own `.help()`, which is what `PVIconButton` uses; port the web hover card only if a call site needs richer content |
| Checkbox | Forms | Checkbox control |
| Radio | Forms | Radio control |
| Switch | Forms | Toggle switch |
| Breadcrumbs | Navigation | Path trail |
| Tabs | Navigation | Tab strip |
| EvidenceBadge | Research | The 5-grade confidence marker (proven/probable/possible/disputed/undocumented) |
| FactRow | Research | One asserted fact: type glyph, date, value, place, grade, conflict note |
| PersonChip | Research | A person with life dates and a lineage-colored rule |
| SourceCitation | Research | Citation + repository + scan thumbnail + grade, as one unit |

## The table tradeoff

`PVTable` is custom chrome on purpose. SwiftUI `Table` and AppKit
`NSTableView` bring their own header, row and selection styling, and none of
it can be pushed all the way to the design system's look: micro-caps headers,
a 2pt accent bar on the selected row, hairline `borderSubtle` rules, badge
cells, the warm hover tint. Visual fidelity won; the cost is that keyboard
and screen-reader parity had to be built by hand.

**Interaction contract** (mirrors `components/data/Table.prompt.md`):

| Input | Behavior |
|---|---|
| ↑ / ↓ | Move selection through the visible rows. Clamps at both ends — does **not** wrap. |
| ⌥↑ / Home | Select the first row. |
| ⌥↓ / End | Select the last row. |
| Page up / Page down | Move ten rows, clamped. |
| a–z, 0–9 | Type-to-select on `primaryText`. The buffer resets after 800ms; a single keystroke advances to the *next* match, so repeated presses cycle. |
| Escape | Clears the type-select buffer. |

The row list is one focus stop, so tab order reads: search field → sort
headers → table → detail pane. Selection always scrolls into view via
`ScrollViewReader`. Like a native table, the highlight dims when the table
does not have focus — `surfaceSelected` + accent bar when focused,
`surfaceSelectedInactive` + `borderStrong` when not. Focus shows
`pvFocusRing` on the container; the view structure never changes on focus
(same rule as `PVInput`).

The caller owns the data: `rows` arrive already filtered and sorted, and the
table reports sort/filter intent through `onSortChange` /
`PVTableColumnFilter.onChange`. Column definitions are the single source of
truth for width — never restate a width at the call site. Search bars and
result footers are feature chrome and stay in the pane.

**Honest accessibility limit.** A custom view cannot claim AppKit's table
grid role, so VoiceOver will not announce "table, row 3 of 12, column 2".
Rows are `.accessibilityElement(children: .combine)` instead, so each reads
as a single element ("Author, author, text") with `.isSelected` on the
selected one, and sortable headers announce their direction via
`.accessibilityValue` because `PVIcon` is `accessibilityHidden`. That
list-like semantic is accepted for single-selection browse lists; do not
reach for `PVTable` where cell-level navigation matters.

`PVTableSelection.moveIndex` and `PVTableTypeSelectMatcher` are pure and
sit outside the view so selection movement and prefix matching are unit
tested without mounting UI (`ProvenenciaTests/PVTableTests.swift`).

Not implemented, deliberately — same scope line as the web component:
multi-select, column resize/reorder, drag-and-drop, inline editing.

## Fonts

Real font files are bundled (not a system-font placeholder) at
`macos/App/Resources/Fonts/`, downloaded from `fonts.gstatic.com` (the same
files Google Fonts serves the web version — SIL Open Font License):

- **Newsreader** (display/headings): weights 300/400/500/600/700, regular only
- **Spectral** (body/UI): weights 300/400/500/600/700 regular, plus 400/600
  italic (italic is a real content convention — hedged statements, place
  lines — not decorative)
- **IBM Plex Mono** (anything cited exactly — dates, ids, folio refs,
  counts): weights 400/500/600

They're registered at process launch via `PVFontRegistration
.registerBundledFontsIfNeeded()` (call this once, early — e.g. from
`ProvenenciaApp.init`), which uses `CTFontManagerRegisterFontsForURL` to
register each `.ttf` under the process scope. This was used instead of the
`ATSApplicationFontsPath` Info.plist key because the project's Info.plist is
auto-generated (`GENERATE_INFOPLIST_FILE = YES`) from `INFOPLIST_KEY_*`
build settings, and per-file registration avoids relying on that key's
exact folder-name semantics.

`PVFont.display/body/mono(size:weight:)` resolve a weight by family name +
numeric weight against whatever's registered (via `NSFontDescriptor`, not a
hardcoded PostScript name — robust to Google Fonts renaming internal
PostScript names between versions), falling back to the closest system
serif/monospace face if a bundled font is ever unavailable.

To add a new weight or style later: download it from
`fonts.googleapis.com/css2?family=...` (see this project's own
`tokens/fonts.css` for the exact family query), drop the `.ttf` into
`Resources/Fonts/`, and add it to the Xcode project's Resources phase (see
"Xcode project registration" below) — no code changes needed since
`PVFont` resolves by family + weight, not by filename.

## Brand assets

The logo mark (a seal roundel enclosing a stylized "P," drawn in the `iron`
palette) lives in two places:

- **`Assets.xcassets/LogoMark.imageset`** — the in-app mark, used via
  `PVLogoMark`. Two SVGs: `logo-mark.svg` (light, `iron-700`/`iron-300`) and
  `logo-mark-dark.svg` (dark, `iron-300`/`iron-100` — the same light↔dark
  relationship `PVColor.accent` uses), registered as light/dark `appearances`
  in `Contents.json` exactly like `AccentColor.colorset`. Never reference
  `Image("LogoMark")` directly — go through `PVLogoMark` so new placements
  stay consistent.
- **`Assets.xcassets/AppIcon.appiconset`** — the real macOS app icon, the
  classic 10-slot format (16/32/128/256/512pt, each @1x/@2x). Generated (not
  hand-exported) from the *same* `logo-mark.svg`, composed onto a
  warm-parchment background (`PVPalette.paper50`) at ~80% fill via
  `scripts/generate-app-icon.sh` (requires `rsvg-convert`, `brew install
  librsvg`). Rerun that script and commit the resulting PNGs if the mark or
  brand color ever changes — don't hand-edit the PNGs.

## Platform deviations

Two are deliberate, matching what the source design system's own readme
documents as the intended macOS port:

- **Control heights**: `PVSpacing.controlHeightSmall/Medium/Large` are
  22/28/36pt (AppKit-native metrics), not the web `--control-h-sm/md/lg`
  pixel values (28/34/42).
- **Icons**: `PVIcon` wraps SF Symbols, not the web's Lucide set — Lucide is
  itself a web-only substitution (no icon set was supplied to the original
  brief), so this is a second substitution, not a compromise.

## Xcode project registration

`macos/Provenencia.xcodeproj/project.pbxproj` is a classic manually-authored
Xcode project (not Xcode 16 synchronized groups), so a new file on disk is
invisible to the build until it's added as a `PBXFileReference` +
`PBXBuildFile` (and, for source files, a `Sources` build phase entry). Use
Xcode itself (File → Add Files…) or the `xcodeproj` Ruby gem — do not hand
edit `project.pbxproj`'s GUIDs.
