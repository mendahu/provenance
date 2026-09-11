import SwiftUI
import AppKit

/// Six-dot grip (2×3), matching the design-system `grip-vertical` affordance.
private struct PVReorderGrip: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .frame(width: 2.5, height: 2.5)
                    }
                }
            }
        }
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }
}

/// Drag handle glyph for reorderable rows (Metadata order, later lists).
///
/// Cursor only — do not attach a local `DragGesture` here; it steals the
/// `List` / `onMove` reorder gesture that actually changes order.
struct PVReorderHandle: View {
    var body: some View {
        PVReorderGrip()
            .foregroundStyle(PVColor.textFaint)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: L10n.DesignSystem.reorderHandle))
            .onHover { hovering in
                if hovering {
                    NSCursor.openHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
    }
}

private struct PVReorderRowHeightsKey: PreferenceKey {
    static let defaultValue: [AnyHashable: CGFloat] = [:]

    static func reduce(
        value: inout [AnyHashable: CGFloat],
        nextValue: () -> [AnyHashable: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { max($0, $1) })
    }
}

/// A plain vertical list whose rows can be reordered via drag.
///
/// Feature screens own the row chrome; this only supplies List + `onMove`
/// plumbing so Metadata (and later ordered collections) do not invent a
/// one-off drag stack. Prefer composing rows here over a monolithic
/// metadata editor component.
///
/// Heights are measured from the rows so multi-line values and narrow
/// windows grow the list instead of clipping with a guessed frame.
struct PVReorderableList<Item: Identifiable, Row: View>: View {
    private let items: [Item]
    private let onMove: (IndexSet, Int) -> Void
    private let row: (Item) -> Row

    @State private var rowHeights: [AnyHashable: CGFloat] = [:]

    init(
        items: [Item],
        onMove: @escaping (IndexSet, Int) -> Void,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.items = items
        self.onMove = onMove
        self.row = row
    }

    private var contentHeight: CGFloat {
        let sum = items.reduce(CGFloat(0)) { partial, item in
            partial + (rowHeights[AnyHashable(item.id)] ?? 44)
        }
        return max(sum, 1)
    }

    var body: some View {
        List {
            ForEach(items) { item in
                row(item)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .overlay {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PVReorderRowHeightsKey.self,
                                value: [AnyHashable(item.id): proxy.size.height]
                            )
                        }
                        .allowsHitTesting(false)
                    }
            }
            .onMove(perform: onMove)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .frame(height: contentHeight)
        .scrollDisabled(true)
        .onPreferenceChange(PVReorderRowHeightsKey.self) { values in
            let next = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (AnyHashable, CGFloat)? in
                let key = AnyHashable(item.id)
                guard let height = values[key] else { return nil }
                return (key, height)
            })
            if next != rowHeights {
                rowHeights = next
            }
        }
    }
}
