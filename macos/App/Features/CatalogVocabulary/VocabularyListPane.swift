import SwiftUI

/// The copy a `VocabularyListPane` renders — all of it owned by the feature's
/// L10n namespace, so the two destinations stay independently localizable.
struct VocabularyListStrings {
    let searchPlaceholder: LocalizedStringResource
    let clearSearch: LocalizedStringResource
    /// Accessibility label for the table itself.
    let tableLabel: LocalizedStringResource
    let emptyIcon: PVSymbol
    let emptyTitle: LocalizedStringResource
    let emptyBody: LocalizedStringResource
    let noMatchTitle: LocalizedStringResource
    let noMatchBody: (_ query: String) -> String
    let resultLine: (_ shown: Int, _ total: Int) -> String
}

/// The left pane both vocabulary destinations share: search above and a
/// result-count footer below a `PVTable` of the rows. The search bar and
/// footer are feature chrome, not table chrome (see `PVTable`'s contract);
/// this pane is where that chrome lives once. What stays with the feature is
/// exactly what differs: the columns, the sort model, and the strings.
struct VocabularyListPane<Row: CatalogVocabularyRow>: View {
    @Binding var query: String
    /// The unfiltered vocabulary size — decides empty-project vs no-match.
    let totalCount: Int
    /// Already filtered and sorted by the model.
    let rows: [Row]
    let isLoading: Bool
    let columns: [PVTableColumn<Row>]
    let selection: Binding<String?>
    let sort: PVTableSort
    let onSortChange: (String) -> Void
    let strings: VocabularyListStrings
    /// Prefixes every identifier this pane mints: `.clearSearch`, `.list`,
    /// `.row.<id>`, `.sortBy.<column>`.
    let identifierPrefix: String

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            table
            footer
        }
    }

    private var searchBar: some View {
        HStack(spacing: PVSpacing.space5) {
            PVInput(text: $query, prompt: strings.searchPlaceholder, icon: .search)
                .frame(maxWidth: 420)
                .accessibilityIdentifier("\(identifierPrefix).search")
            if !query.isEmpty {
                PVButton(strings.clearSearch, variant: .ghost, size: .sm) {
                    query = ""
                }
                .accessibilityIdentifier("\(identifierPrefix).clearSearch")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PVSpacing.gutterPage)
        .padding(.vertical, PVSpacing.space6)
        .background(PVColor.surfaceCard)
        .overlay(alignment: .bottom) {
            PVDivider()
        }
    }

    private var table: some View {
        PVTable(
            rows: rows,
            columns: columns,
            selection: selection,
            primaryText: \.label,
            sort: sort,
            onSortChange: onSortChange,
            label: strings.tableLabel,
            rowAccessibilityIdentifier: { "\(identifierPrefix).row.\($0.id)" },
            sortAccessibilityIdentifier: { "\(identifierPrefix).sortBy.\($0)" }
        ) {
            placeholder
        }
        .accessibilityIdentifier("\(identifierPrefix).list")
    }

    /// Loading / empty / no-match chrome, rendered inside the table body so
    /// the column header stays put — the same slot the web board uses.
    @ViewBuilder
    private var placeholder: some View {
        if isLoading && totalCount == 0 {
            ProgressView()
                .tint(PVColor.accent)
                .frame(maxWidth: .infinity)
                .padding(PVSpacing.space9)
        } else if totalCount == 0 {
            PVEmptyState(
                icon: strings.emptyIcon,
                title: strings.emptyTitle,
                message: String(localized: strings.emptyBody)
            )
            .padding(PVSpacing.space9)
        } else if rows.isEmpty {
            PVEmptyState(
                icon: .searchEmpty,
                title: strings.noMatchTitle,
                message: strings.noMatchBody(query),
                compact: true
            )
            .padding(PVSpacing.space9)
        }
    }

    private var footer: some View {
        HStack {
            Text(strings.resultLine(rows.count, totalCount))
                .font(PVFont.mono(size: PVTypeScale.micro))
                .foregroundStyle(PVColor.textMuted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PVSpacing.gutterPage)
        .padding(.vertical, PVSpacing.space3)
        .background(PVColor.surfaceCard)
        .overlay(alignment: .top) {
            PVDivider()
        }
    }
}
