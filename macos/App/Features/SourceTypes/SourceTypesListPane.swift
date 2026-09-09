import SwiftUI

/// The left pane of `SourceTypesView`: search (T-4) and a result-count
/// footer around a `PVTable` of the project's types (T-1/T-2/T-3).
///
/// The search bar and footer stay here on purpose — they are feature chrome,
/// not table chrome (see `PVTable`'s contract). Everything between them —
/// column header, sort control, rows, selection, keyboard and VoiceOver
/// behaviour — belongs to `PVTable`.
struct SourceTypesListPane: View {
    @Bindable var model: SourceTypesModel

    /// Column widths live only here; `PVTable` shares them between the
    /// header and every row, so they are never restated.
    private static let keyColumnWidth: CGFloat = 160
    private static let fieldsColumnWidth: CGFloat = 132

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            table
            footer
        }
    }

    private var searchBar: some View {
        HStack(spacing: PVSpacing.space5) {
            PVInput(text: $model.query, prompt: L10n.SourceTypes.searchPlaceholder, icon: .search)
                .frame(maxWidth: 420)
            if !model.query.isEmpty {
                PVButton(L10n.SourceTypes.clearSearch, variant: .ghost, size: .sm) {
                    model.query = ""
                }
                .accessibilityIdentifier("sourceTypes.clearSearch")
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

    // MARK: Table

    private var table: some View {
        PVTable(
            rows: model.visibleTypes,
            columns: columns,
            selection: selection,
            primaryText: \.label,
            sort: PVTableSort(
                columnID: model.sortColumn.rawValue,
                direction: model.sortAscending ? .ascending : .descending
            ),
            onSortChange: { model.sortBy($0) },
            label: L10n.Workspace.sourceTypesTitle,
            rowAccessibilityIdentifier: { "sourceTypes.row.\($0.id)" },
            sortAccessibilityIdentifier: { "sourceTypes.sortBy.\($0)" }
        ) {
            placeholder
        }
        .accessibilityIdentifier("sourceTypes.list")
    }

    private var columns: [PVTableColumn<CatalogSourceType>] {
        [
            PVTableColumn(
                id: SourceTypesModel.SortColumn.label.rawValue,
                title: L10n.SourceTypes.columnLabel,
                sortable: true
            ) { type in
                HStack(spacing: PVSpacing.space2) {
                    Text(type.label)
                        .font(PVFont.body(size: PVTypeScale.bodySmall))
                        .foregroundStyle(PVColor.textPrimary)
                        .lineLimit(1)
                    OriginPill(origin: type.origin)
                }
            },
            PVTableColumn(
                id: SourceTypesModel.SortColumn.key.rawValue,
                title: L10n.SourceTypes.columnKey,
                width: Self.keyColumnWidth,
                sortable: true
            ) { type in
                Text(type.key)
                    .font(PVFont.mono(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            PVTableColumn(
                id: SourceTypesModel.SortColumn.fields.rawValue,
                title: L10n.SourceTypes.columnFields,
                width: Self.fieldsColumnWidth,
                sortable: true
            ) { type in
                Text(
                    type.suggestedFieldCount > 0
                        ? "\(type.suggestedFieldCount)"
                        : String(localized: L10n.SourceTypes.fieldCountNone)
                )
                .font(PVFont.mono(size: PVTypeScale.micro))
                .foregroundStyle(type.suggestedFieldCount > 0 ? PVColor.textSecondary : PVColor.textFaint)
            },
        ]
    }

    /// Selection is the table's, but the model owns what it means: picking a
    /// row leaves the add form, decides view-vs-edit by origin, and starts
    /// the suggestions read. The add form deselects, so no row reads as
    /// selected while it is open.
    private var selection: Binding<String?> {
        Binding(
            get: { model.isAdding ? nil : model.selectedType?.id },
            set: { if let id = $0 { model.select(id) } }
        )
    }

    /// Loading / empty / no-match chrome, rendered inside the table body so
    /// the column header stays put — the same slot the web board uses.
    @ViewBuilder
    private var placeholder: some View {
        if model.isLoading && model.types.isEmpty {
            ProgressView()
                .tint(PVColor.accent)
                .frame(maxWidth: .infinity)
                .padding(PVSpacing.space9)
        } else if model.types.isEmpty {
            PVEmptyState(
                icon: .library,
                title: L10n.SourceTypes.emptyProjectTitle,
                message: String(localized: L10n.SourceTypes.emptyProjectBody)
            )
            .padding(PVSpacing.space9)
        } else if model.visibleTypes.isEmpty {
            PVEmptyState(
                icon: .searchEmpty,
                title: L10n.SourceTypes.noMatchTitle,
                message: L10n.SourceTypes.noMatchBody(query: model.query),
                compact: true
            )
            .padding(PVSpacing.space9)
        }
    }

    private var footer: some View {
        HStack {
            Text(L10n.SourceTypes.resultLine(shown: model.visibleTypes.count, total: model.types.count))
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
