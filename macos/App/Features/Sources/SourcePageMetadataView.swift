import SwiftUI

/// Metadata board: saved reorderable rows, type suggestions, and the Add dialog form.
struct SourcePageMetadataView: View {
    @Bindable var model: SourcePageModel

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVSectionHeader(
                title: L10n.Sources.metadataHeading,
                meta: model.metadata.saved.isEmpty
                    ? nil
                    : L10n.Sources.metadataFieldCount(model.metadata.saved.count),
                actions: {
                    PVButton(L10n.Sources.addMetadata, variant: .primary, size: .sm, icon: .plus) {
                        model.metadata.openAdd()
                    }
                    .accessibilityIdentifier("sources.page.addMetadata")
                }
            )

            Text(L10n.Sources.metadataIntro)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textMuted)
                .frame(maxWidth: PVSpacing.measureProse, alignment: .leading)

            if model.metadata.saved.isEmpty, model.metadata.suggested.isEmpty {
                Text(L10n.Sources.metadataEmptyMessage)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
                    .accessibilityIdentifier("sources.page.metadata.empty")
            } else {
                if !model.metadata.saved.isEmpty {
                    PVReorderableList(items: model.metadata.saved, onMove: { source, destination in
                        Task { await model.metadata.moveSaved(from: source, to: destination) }
                    }) { entry in
                        savedRow(entry)
                    }
                    .accessibilityIdentifier("sources.page.metadata.list")
                }

                if !model.metadata.suggested.isEmpty {
                    VStack(alignment: .leading, spacing: PVSpacing.space4) {
                        Text(L10n.Sources.metadataSuggestionsHeading)
                            .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                            .tracking(PVTypeScale.micro * PVTracking.caps)
                            .textCase(.uppercase)
                            .foregroundStyle(PVColor.textFaint)
                            .padding(.top, model.metadata.saved.isEmpty ? 0 : PVSpacing.space7)

                        ForEach(model.metadata.suggested) { entry in
                            suggestionRow(entry)
                        }
                    }
                    .accessibilityIdentifier("sources.page.metadata.suggestions")
                }
            }
        }
    }

    /// Field + value form for the Add Metadata dialog (hosted by the page shell).
    var addForm: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVField(
                label: L10n.Sources.metadataField,
                hint: L10n.Sources.metadataFieldHint,
                error: model.metadata.addFieldError,
                required: true
            ) {
                PVComboBox(
                    selection: $model.metadata.addFieldID,
                    options: model.metadata.fieldComboOptions,
                    placeholder: L10n.Sources.metadataField,
                    emptyLabel: L10n.Sources.typeNoMatch,
                    isInvalid: model.metadata.addFieldError != nil,
                    label: L10n.Sources.metadataField,
                    accessibilityIdentifierPrefix: "sources.page.addMetadata.field"
                )
                .onChange(of: model.metadata.addFieldID) { _, newValue in
                    if !newValue.isEmpty { model.metadata.addFieldError = nil }
                }
            }
            PVField(
                label: L10n.Sources.metadataValue,
                hint: L10n.Sources.metadataValueHint,
                error: model.metadata.addValueError,
                required: true
            ) {
                PVInput(
                    text: $model.metadata.addValue,
                    isInvalid: model.metadata.addValueError != nil
                )
                .onChange(of: model.metadata.addValue) { _, _ in
                    model.metadata.addValueError = nil
                }
            }
        }
    }

    private func savedRow(_ entry: CatalogMetadataEntry) -> some View {
        let fieldID = entry.field.id
        let isDate = entry.field.dataType == CatalogFieldDataType.date
        let structured = model.metadata.isStructured(entry)
        let editing = model.metadata.editingFieldID == fieldID
        return VStack(alignment: .leading, spacing: PVSpacing.space2) {
            HStack(alignment: .top, spacing: SourcePageLayout.metadataColumnSpacing) {
                PVReorderHandle()
                    .padding(.top, 6)
                SourcePageMetadataLabel(text: entry.field.label, topPadding: 6)

                PVInlineEdit(
                    isEditing: editing,
                    isSaving: model.metadata.savingFieldID == fieldID,
                    saveLabel: L10n.Sources.saveAction,
                    cancelLabel: L10n.Sources.cancelEdit,
                    editLabel: L10n.Sources.editMetadataValue,
                    saveDisabled: (model.metadata.drafts[fieldID] ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty,
                    axis: .horizontal,
                    accessibilityIdentifierPrefix: "sources.page.metadata.\(fieldID)",
                    onEdit: { model.metadata.beginEdit(fieldID: fieldID) },
                    onSave: { Task { await model.metadata.save(fieldID: fieldID) } },
                    onCancel: { model.metadata.cancelEdit() }
                ) {
                    Text(entry.valueText)
                        .font(PVFont.mono(size: PVTypeScale.caption))
                        .foregroundStyle(PVColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                        .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")
                } editor: {
                    PVTextArea(
                        text: Binding(
                            get: { model.metadata.drafts[fieldID] ?? entry.valueText },
                            set: { model.metadata.drafts[fieldID] = $0 }
                        ),
                        lineLimit: 1...6,
                        typography: .mono
                    )
                    .onSubmit { Task { await model.metadata.save(fieldID: fieldID) } }
                    .disabled(model.metadata.savingFieldID == fieldID)
                    .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")
                }

                CatalogFieldDataTypeBadge(dataType: entry.field.dataType)
                    .padding(.top, 4)
            }

            if isDate {
                HStack(spacing: PVSpacing.space4) {
                    Text(L10n.Sources.metadataStructuredLabel)
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.textFaint)

                    if structured {
                        Text(entry.dateSummary)
                            .font(PVFont.mono(size: PVTypeScale.micro))
                            .foregroundStyle(PVColor.accentSoftForeground)
                            .padding(.horizontal, PVSpacing.space3)
                            .frame(height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(PVColor.accentSoft)
                            )
                    } else {
                        Text(L10n.Sources.metadataNotStructured)
                            .font(PVFont.body(size: PVTypeScale.micro, italic: true))
                            .foregroundStyle(PVColor.textMuted)
                    }

                    Button {
                        if structured {
                            model.metadata.openEditDate(fieldID: fieldID)
                        } else {
                            model.metadata.openStructureDate(fieldID: fieldID)
                        }
                    } label: {
                        Text(structured ? L10n.Sources.editDate : L10n.Sources.structureDate)
                            .font(PVFont.body(size: PVTypeScale.micro))
                            .foregroundStyle(structured ? PVColor.textPrimary : PVColor.textLink)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(
                                        PVColor.borderDefault,
                                        style: StrokeStyle(
                                            lineWidth: 1,
                                            dash: structured ? [] : [4, 3]
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        structured
                            ? "sources.page.metadata.\(fieldID).editDate"
                            : "sources.page.metadata.\(fieldID).structureDate"
                    )
                }
                .padding(.leading, SourcePageLayout.metadataDateRowInset)
            }
        }
        .padding(.vertical, PVSpacing.space3)
        .padding(.horizontal, PVSpacing.space4)
    }

    private func suggestionRow(_ entry: CatalogMetadataEntry) -> some View {
        let fieldID = entry.field.id
        return PVCard(border: .dashed, cornerRadius: PVRadius.sm) {
            HStack(spacing: SourcePageLayout.metadataColumnSpacing) {
                SourcePageMetadataLabel(text: entry.field.label, alignWithReorderHandle: true)
                PVInput(
                    text: Binding(
                        get: { model.metadata.drafts[fieldID] ?? "" },
                        set: { model.metadata.drafts[fieldID] = $0 }
                    ),
                    size: .sm,
                    mono: true,
                    prompt: L10n.Sources.metadataSuggestionPlaceholder
                )
                .onSubmit { Task { await model.metadata.save(fieldID: fieldID) } }
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

                PVButton(
                    L10n.Sources.saveMetadataSuggestion,
                    variant: .ghost,
                    size: .sm,
                    loading: model.metadata.savingFieldID == fieldID
                ) {
                    Task { await model.metadata.save(fieldID: fieldID) }
                }
                .disabled(
                    (model.metadata.drafts[fieldID] ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).save")

                PVIconButton(.dismiss, label: L10n.Sources.dismissMetadataSuggestion, size: .sm) {
                    Task { await model.metadata.dismissSuggestion(fieldID: fieldID) }
                }
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).dismiss")
            }
            .padding(.vertical, PVSpacing.space4)
            .padding(.horizontal, PVSpacing.space5)
        }
    }
}
