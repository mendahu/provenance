import SwiftUI

/// The left pane of `SourceFieldsView`: search (F-5), a sortable Label
/// column header (F-4), the field rows (F-1/F-2), and a result-count
/// footer.
struct SourceFieldsListPane: View {
    @Bindable var model: SourceFieldsModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            columnHeader
            list
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

    private var columnHeader: some View {
        HStack(spacing: PVSpacing.space6) {
            sortableLabelColumn
                .frame(maxWidth: .infinity, alignment: .leading)
            columnHeaderText(L10n.SourceFields.columnKey)
                .frame(width: SourceFieldsRow.keyColumnWidth, alignment: .leading)
            columnHeaderText(L10n.SourceFields.columnDataType)
                .frame(width: SourceFieldsRow.dataTypeColumnWidth, alignment: .leading)
            columnHeaderText(L10n.SourceFields.columnOrigin)
                .frame(width: SourceFieldsRow.originColumnWidth, alignment: .leading)
        }
        .padding(.horizontal, PVSpacing.gutterPage)
        .padding(.vertical, PVSpacing.space3)
        .background(PVColor.surfaceSunken)
        .overlay(alignment: .bottom) {
            PVDivider(color: PVColor.borderDefault)
        }
    }

    private func columnHeaderText(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .pvMicroCaps()
            .foregroundStyle(PVColor.textMuted)
    }

    private var sortableLabelColumn: some View {
        Button {
            model.toggleLabelSort()
        } label: {
            HStack(spacing: PVSpacing.space3) {
                columnHeaderText(L10n.SourceFields.columnLabel)
                PVIcon(model.sortAscending ? .sortAscending : .chevronDown, size: 11)
                    .foregroundStyle(PVColor.accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sourceFields.sortByLabel")
    }

    @ViewBuilder
    private var list: some View {
        if model.isLoading && model.fields.isEmpty {
            ProgressView()
                .tint(PVColor.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.fields.isEmpty {
            ScrollView {
                PVEmptyState(
                    icon: .tag,
                    title: L10n.SourceFields.emptyProjectTitle,
                    message: String(localized: L10n.SourceFields.emptyProjectBody)
                )
                .padding(PVSpacing.space9)
            }
        } else if model.visibleFields.isEmpty {
            ScrollView {
                PVEmptyState(
                    icon: .searchEmpty,
                    title: L10n.SourceFields.noMatchTitle,
                    message: L10n.SourceFields.noMatchBody(query: model.query),
                    compact: true
                )
                .padding(PVSpacing.space9)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.visibleFields, id: \.id) { field in
                        SourceFieldsRow(
                            field: field,
                            isSelected: !model.isAdding && model.selectedField?.id == field.id,
                            select: { model.select(field.id) }
                        )
                        PVDivider()
                    }
                }
            }
            .accessibilityIdentifier("sourceFields.list")
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
