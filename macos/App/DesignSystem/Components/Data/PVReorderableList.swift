import SwiftUI

/// Drag handle glyph for reorderable rows (Metadata order, later lists).
struct PVReorderHandle: View {
    var body: some View {
        PVIcon(.reorder, size: 12)
            .foregroundStyle(PVColor.textFaint)
            .accessibilityLabel(String(localized: L10n.DesignSystem.reorderHandle))
    }
}

/// A plain vertical list whose rows can be reordered via drag.
///
/// Feature screens own the row chrome; this only supplies List + `onMove`
/// plumbing so Metadata (and later ordered collections) do not invent a
/// one-off drag stack. Prefer composing rows here over a monolithic
/// metadata editor component.
struct PVReorderableList<Item: Identifiable, Row: View>: View {
    private let items: [Item]
    private let onMove: (IndexSet, Int) -> Void
    private let row: (Item) -> Row

    init(
        items: [Item],
        onMove: @escaping (IndexSet, Int) -> Void,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.items = items
        self.onMove = onMove
        self.row = row
    }

    var body: some View {
        List {
            ForEach(items) { item in
                row(item)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .onMove(perform: onMove)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
    }
}
