import SwiftUI

/// The left pane of `SourceFieldsView`: search (F-5) and a result-count
/// footer around a `PVTable` of the project's fields (F-1/F-2/F-4).
///
/// The search bar and footer stay here on purpose — they are feature chrome,
/// not table chrome (see `PVTable`'s contract). Everything between them —
/// column header, sort control, rows, selection, keyboard and VoiceOver
/// behaviour — belongs to `PVTable`.
struct SourceFieldsListPane: View {
    @Bindable var model: SourceFieldsModel

    /// Column widths live only here; `PVTable` shares them between the
    /// header and every row, so they are never restated.
    private static let keyColumnWidth: CGFloat = 160
    private static let dataTypeColumnWidth: CGFloat = 116

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            table
            footer
        }
    }

    private var searchBar: some View {
        HStack(spacing: PVSpacing.space5) {
            PVInput(text: $model.query, prompt: L10n.SourceFields.searchPlaceholder, icon: .search)
                .frame(maxWidth: 420)
            if !model.query.isEmpty {
                PVButton(L10n.SourceFields.clearSearch, variant: .ghost, size: .sm) {
                    model.query = ""
                }
                .accessibilityIdentifier("sourceFields.clearSearch")
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
            rows: model.visibleFields,
            columns: columns,
            selection: selection,
            primaryText: \.label,
            sort: PVTableSort(columnID: Self.labelColumnID, direction: model.sortAscending ? .ascending : .descending),
            onSortChange: { _ in model.toggleLabelSort() },
            label: L10n.Workspace.sourceFieldsTitle,
            rowAccessibilityIdentifier: { "sourceFields.row.\($0.id)" },
            sortAccessibilityIdentifier: { _ in "sourceFields.sortByLabel" }
        ) {
            placeholder
        }
        .accessibilityIdentifier("sourceFields.list")
    }

    private static let labelColumnID = "label"

    private var columns: [PVTableColumn<CatalogMetadataField>] {
        [
            PVTableColumn(id: Self.labelColumnID, title: L10n.SourceFields.columnLabel, sortable: true) { field in
                HStack(spacing: PVSpacing.space2) {
                    Text(field.label)
                        .font(PVFont.body(size: PVTypeScale.bodySmall))
                        .foregroundStyle(PVColor.textPrimary)
                        .lineLimit(1)
                    OriginPill(origin: field.origin)
                }
            },
            PVTableColumn(id: "key", title: L10n.SourceFields.columnKey, width: Self.keyColumnWidth) { field in
                Text(field.key)
                    .font(PVFont.mono(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            },
            PVTableColumn(id: "dataType", title: L10n.SourceFields.columnDataType, width: Self.dataTypeColumnWidth) { field in
                SourceFieldDataTypeBadge(dataType: field.dataType)
            },
        ]
    }

    /// Selection is the table's, but the model owns what it means: picking a
    /// row leaves the add form and decides view-vs-edit by origin. The add
    /// form deselects, so no row reads as selected while it is open.
    private var selection: Binding<String?> {
        Binding(
            get: { model.isAdding ? nil : model.selectedField?.id },
            set: { if let id = $0 { model.select(id) } }
        )
    }

    /// Loading / empty / no-match chrome, rendered inside the table body so
    /// the column header stays put — the same slot the web board uses.
    @ViewBuilder
    private var placeholder: some View {
        if model.isLoading && model.fields.isEmpty {
            ProgressView()
                .tint(PVColor.accent)
                .frame(maxWidth: .infinity)
                .padding(PVSpacing.space9)
        } else if model.fields.isEmpty {
            PVEmptyState(
                icon: .tag,
                title: L10n.SourceFields.emptyProjectTitle,
                message: String(localized: L10n.SourceFields.emptyProjectBody)
            )
            .padding(PVSpacing.space9)
        } else if model.visibleFields.isEmpty {
            PVEmptyState(
                icon: .searchEmpty,
                title: L10n.SourceFields.noMatchTitle,
                message: L10n.SourceFields.noMatchBody(query: model.query),
                compact: true
            )
            .padding(PVSpacing.space9)
        }
    }

    private var footer: some View {
        HStack {
            Text(L10n.SourceFields.resultLine(shown: model.visibleFields.count, total: model.fields.count))
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
