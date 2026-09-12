import SwiftUI

/// Homogeneous evidence browse list — mirrors the design system's
/// `components/data/List.jsx` (S2-04 / S2-17). **Not** `PVTable`: no column
/// headers, no spreadsheet chrome. Rows are thumb + primary + optional
/// secondary + trailing meta, and activating a row navigates (or otherwise
/// commits) rather than selecting in place for a side pane.
///
/// Contract:
/// - **The caller owns the data.** `rows` arrive already filtered and sorted;
///   search / filter / sort menus stay in feature chrome above the list.
/// - Empty and no-match states are feature-owned (`PVEmptyState`), not list
///   chrome — pass them as the list's sibling, not as row content.
///
/// Files (S2-21) remounts the same component with a different row mapping.

// MARK: - Pure helpers (unit-testable without UI)

enum PVListSelection {
    /// Clamped focus movement — never wraps, matching Finder / Mail lists.
    static func moveIndex(_ index: Int, delta: Int, count: Int) -> Int {
        guard count > 0 else { return -1 }
        if index < 0 { return delta > 0 ? 0 : count - 1 }
        return min(count - 1, max(0, index + delta))
    }
}

/// Type-to-focus buffering — same reset window as `PVTableTypeSelectMatcher`,
/// kept separate so list and table can diverge later without coupling tests.
struct PVListTypeaheadMatcher {
    static let resetInterval: TimeInterval = 0.8

    private var buffer = ""
    private var lastKeystroke = Date.distantPast

    init() {}

    mutating func append(_ character: Character, now: Date = Date()) -> String {
        buffer = now.timeIntervalSince(lastKeystroke) > Self.resetInterval
            ? String(character)
            : buffer + String(character)
        lastKeystroke = now
        return buffer
    }

    mutating func reset() {
        buffer = ""
        lastKeystroke = .distantPast
    }

    /// First index whose primary text starts with `prefix`, searching forward
    /// from `fromIndex` and wrapping so repeated keys cycle matches.
    static func index(in values: [String], prefix: String, fromIndex: Int = 0) -> Int {
        let query = prefix.lowercased()
        guard !query.isEmpty, !values.isEmpty else { return -1 }
        for offset in 0..<values.count {
            let idx = (max(0, fromIndex) + offset) % values.count
            if values[idx].lowercased().hasPrefix(query) { return idx }
        }
        return -1
    }
}

// MARK: - Density

enum PVListDensity {
    case comfortable
    case compact

    var verticalPadding: CGFloat {
        switch self {
        case .comfortable: PVSpacing.space5 + PVSpacing.spacePx // ~11
        case .compact: PVSpacing.space3 + PVSpacing.spacePx // ~7
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .comfortable: PVSpacing.space6
        case .compact: PVSpacing.space5
        }
    }
}

// MARK: - List

struct PVList<Row: Identifiable, ID: Hashable, Thumbnail: View>: View where Row.ID == ID {
    let rows: [Row]
    let label: LocalizedStringResource
    let primary: (Row) -> String
    let secondary: ((Row) -> String?)?
    let meta: ((Row) -> String?)?
    let thumbnail: ((Row) -> Thumbnail)?
    let showsChevron: Bool
    let density: PVListDensity
    let onActivate: (ID) -> Void
    let rowAccessibilityIdentifier: ((Row) -> String)?

    @State private var focusedID: ID?
    @State private var matcher = PVListTypeaheadMatcher()
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        rows: [Row],
        label: LocalizedStringResource,
        primary: @escaping (Row) -> String,
        secondary: ((Row) -> String?)? = nil,
        meta: ((Row) -> String?)? = nil,
        @ViewBuilder thumbnail: @escaping (Row) -> Thumbnail,
        showsChevron: Bool = true,
        density: PVListDensity = .comfortable,
        onActivate: @escaping (ID) -> Void,
        rowAccessibilityIdentifier: ((Row) -> String)? = nil
    ) {
        self.rows = rows
        self.label = label
        self.primary = primary
        self.secondary = secondary
        self.meta = meta
        self.thumbnail = thumbnail
        self.showsChevron = showsChevron
        self.density = density
        self.onActivate = onActivate
        self.rowAccessibilityIdentifier = rowAccessibilityIdentifier
    }

    private var focusedIndex: Int {
        guard let focusedID else { return -1 }
        return rows.firstIndex { $0.id == focusedID } ?? -1
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        rowView(row).id(row.id)
                    }
                }
            }
            .onChange(of: focusedID) { _, new in
                guard let new else { return }
                withAnimation(reduceMotion ? nil : PVMotion.fastStandard) { proxy.scrollTo(new) }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(action: handleKey)
        .pvFocusRing(isFocused, cornerRadius: PVRadius.none)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }

    private func rowView(_ row: Row) -> some View {
        let isRowFocused = row.id == focusedID
        return PVHoverEffect(isPressed: false, hoverAnimation: PVMotion.fastStandard) { showHover in
            HStack(spacing: PVSpacing.space5) {
                if let thumbnail {
                    thumbnail(row)
                }
                VStack(alignment: .leading, spacing: PVSpacing.space1) {
                    Text(primary(row))
                        .font(PVFont.body(size: PVTypeScale.bodySmall, weight: PVFontWeight.medium))
                        .foregroundStyle(PVColor.textPrimary)
                        .lineLimit(1)
                    if let secondary, let sub = secondary(row), !sub.isEmpty {
                        Text(sub)
                            .font(PVFont.body(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let meta, let trail = meta(row), !trail.isEmpty {
                    Text(trail)
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.textMuted)
                        .lineLimit(1)
                }
                if showsChevron {
                    PVIcon(.chevronForward, size: 12)
                        .foregroundStyle(PVColor.textFaint)
                }
            }
            .padding(.horizontal, density.horizontalPadding)
            .padding(.vertical, density.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(rowBackground(isRowFocused: isRowFocused, showHover: showHover))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(isRowFocused && isFocused ? PVColor.accent : .clear)
                    .frame(width: 2)
            }
            .overlay(alignment: .bottom) {
                PVDivider()
            }
        }
        .onTapGesture {
            focusedID = row.id
            onActivate(row.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(rowAccessibilityIdentifier?(row) ?? "")
    }

    private func rowBackground(isRowFocused: Bool, showHover: Bool) -> Color {
        if isRowFocused {
            return isFocused ? PVColor.surfaceSelected : PVColor.surfaceSelectedInactive
        }
        return showHover ? PVColor.surfaceHover : .clear
    }

    private func focus(at index: Int) {
        guard rows.indices.contains(index) else { return }
        focusedID = rows[index].id
    }

    private func activateFocused() {
        let index = focusedIndex >= 0 ? focusedIndex : 0
        guard rows.indices.contains(index) else { return }
        let id = rows[index].id
        focusedID = id
        onActivate(id)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard !rows.isEmpty else { return .ignored }
        let index = focusedIndex

        switch press.key {
        case .upArrow, .downArrow:
            let isDown = press.key == .downArrow
            if press.modifiers.contains(.option) {
                focus(at: isDown ? rows.count - 1 : 0)
            } else {
                focus(at: PVListSelection.moveIndex(index, delta: isDown ? 1 : -1, count: rows.count))
            }
            return .handled
        case .home:
            focus(at: 0)
            return .handled
        case .end:
            focus(at: rows.count - 1)
            return .handled
        case .pageDown, .pageUp:
            focus(at: PVListSelection.moveIndex(index, delta: press.key == .pageDown ? 10 : -10, count: rows.count))
            return .handled
        case .return, .space:
            activateFocused()
            return .handled
        case .escape:
            matcher.reset()
            return .handled
        default:
            guard press.characters.count == 1,
                  let character = press.characters.first,
                  character.isLetter || character.isNumber,
                  !press.modifiers.contains(.command),
                  !press.modifiers.contains(.control)
            else { return .ignored }

            let buffer = matcher.append(character)
            let from = buffer.count == 1 ? index + 1 : max(0, index)
            let hit = PVListTypeaheadMatcher.index(
                in: rows.map(primary),
                prefix: buffer,
                fromIndex: from
            )
            if hit >= 0 { focus(at: hit) }
            return .handled
        }
    }
}

extension PVList where Thumbnail == EmptyView {
    init(
        rows: [Row],
        label: LocalizedStringResource,
        primary: @escaping (Row) -> String,
        secondary: ((Row) -> String?)? = nil,
        meta: ((Row) -> String?)? = nil,
        showsChevron: Bool = true,
        density: PVListDensity = .comfortable,
        onActivate: @escaping (ID) -> Void,
        rowAccessibilityIdentifier: ((Row) -> String)? = nil
    ) {
        self.rows = rows
        self.label = label
        self.primary = primary
        self.secondary = secondary
        self.meta = meta
        self.thumbnail = nil
        self.showsChevron = showsChevron
        self.density = density
        self.onActivate = onActivate
        self.rowAccessibilityIdentifier = rowAccessibilityIdentifier
    }
}

#Preview {
    struct PreviewRow: Identifiable {
        let id: String
        let title: String
        let type: String
        let ref: String
        let hasThumb: Bool
    }

    let rows = [
        PreviewRow(id: "1", title: "Alderwick family photograph", type: "Photograph", ref: "SRC-0412", hasThumb: true),
        PreviewRow(id: "2", title: "Death certificate — Thomas Alderwick", type: "Civil certificate", ref: "SRC-0301", hasThumb: false),
    ]

    return PVList(
        rows: rows,
        label: "Sources",
        primary: { $0.title },
        secondary: { $0.type },
        meta: { $0.ref },
        thumbnail: { row in
            PVThumbnail(row.hasThumb ? PVThumbnail.Content(icon: .photo) : .empty)
        },
        onActivate: { _ in }
    )
    .frame(width: 640, height: 220)
    .padding(PVSpacing.space9)
    .background(PVColor.surfacePage)
}
