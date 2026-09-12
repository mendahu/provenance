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
                PVEmptyState(
                    icon: .list,
                    title: L10n.Sources.metadataEmptyTitle,
                    message: String(localized: L10n.Sources.metadataEmptyMessage),
                    compact: true
                ) {
                    PVButton(L10n.Sources.addMetadata, variant: .primary, size: .sm, icon: .plus) {
                        model.metadata.openAdd()
                    }
                    .accessibilityIdentifier("sources.page.metadata.empty.add")
                }
                .accessibilityIdentifier("sources.page.metadata.empty")
            } else {
                if !model.metadata.saved.isEmpty {
                    PVReorderableList(
                        items: model.metadata.saved,
                        freezesHeight: model.metadata.editingFieldID != nil,
                        onMove: { source, destination in
                            Task { await model.metadata.moveSaved(from: source, to: destination) }
                        }
                    ) { entry in
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
                            SourcePageMetadataSuggestionRow(
                                entry: entry,
                                isSaving: model.metadata.savingFieldID == entry.field.id,
                                onSave: { value in
                                    model.metadata.drafts[entry.field.id] = value
                                    Task { await model.metadata.save(fieldID: entry.field.id) }
                                },
                                onDismiss: {
                                    Task { await model.metadata.dismissSuggestion(fieldID: entry.field.id) }
                                }
                            )
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
            .accessibilityIdentifier("sources.page.addMetadata.value")
            .onChange(of: model.metadata.addValue) { _, _ in
                if model.metadata.addValueError != nil {
                    model.metadata.addValueError = nil
                }
            }
            }
        }
    }

    /// Date dialog body: wording + structure (hosted by the page shell).
    /// Uses local drafts; parent supplies `canSave` / `saveAction` bindings so
    /// Confirm stays accurate without live-binding the page model.
    func dateEditorForm(
        canSave: Binding<Bool>,
        saveAction: Binding<(() async -> Void)?>
    ) -> some View {
        SourcePageDateEditorForm(
            model: model,
            canSave: canSave,
            saveAction: saveAction
        )
    }

    private func savedRow(_ entry: CatalogMetadataEntry) -> some View {
        let isDate = entry.field.dataType == CatalogFieldDataType.date
        return HStack(alignment: .top, spacing: SourcePageLayout.metadataColumnSpacing) {
            PVReorderHandle()
                .padding(.top, 6)
            SourcePageMetadataLabel(
                text: entry.field.label,
                dataType: entry.field.dataType,
                topPadding: 6
            )

            if isDate {
                dateValueCell(entry)
            } else {
                SourcePageMetadataTextEditor(
                    entry: entry,
                    isEditing: model.metadata.editingFieldID == entry.field.id,
                    isSaving: model.metadata.savingFieldID == entry.field.id,
                    onBeginEdit: { model.metadata.beginEdit(fieldID: entry.field.id) },
                    onSave: { value in
                        model.metadata.drafts[entry.field.id] = value
                        Task { await model.metadata.save(fieldID: entry.field.id) }
                    },
                    onCancel: { model.metadata.cancelEdit() }
                )
            }
        }
        .padding(.vertical, PVSpacing.space3)
        .padding(.horizontal, PVSpacing.space4)
    }

    private func dateValueCell(_ entry: CatalogMetadataEntry) -> some View {
        let fieldID = entry.field.id
        return HStack(alignment: .top, spacing: PVSpacing.space3) {
            Text(entry.valueText)
                .font(PVFont.mono(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sourcePageMetadataValueChrome()
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

            PVIconButton(
                .penLine,
                label: L10n.Sources.editMetadataDateValue,
                size: .sm
            ) {
                model.metadata.openDateEditor(fieldID: fieldID)
            }
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).editDate")
        }
    }
}

/// Suggestion quick-add row with a local draft.
private struct SourcePageMetadataSuggestionRow: View {
    let entry: CatalogMetadataEntry
    let isSaving: Bool
    let onSave: (String) -> Void
    let onDismiss: () -> Void

    @State private var draft = ""

    var body: some View {
        let fieldID = entry.field.id
        return PVCard(border: .dashed, cornerRadius: PVRadius.sm) {
            HStack(spacing: SourcePageLayout.metadataColumnSpacing) {
                SourcePageMetadataLabel(text: entry.field.label, alignWithReorderHandle: true)
                PVInput(
                    text: $draft,
                    size: .sm,
                    mono: true,
                    prompt: L10n.Sources.metadataSuggestionPlaceholder
                )
                .onSubmit { onSave(draft) }
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

                PVButton(
                    L10n.Sources.saveMetadataSuggestion,
                    variant: .ghost,
                    size: .sm,
                    loading: isSaving
                ) {
                    onSave(draft)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).save")

                PVIconButton(.dismiss, label: L10n.Sources.dismissMetadataSuggestion, size: .sm) {
                    onDismiss()
                }
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).dismiss")
            }
            .padding(.vertical, PVSpacing.space4)
            .padding(.horizontal, PVSpacing.space5)
        }
    }
}

/// Date dialog: local wording + structure drafts.
private struct SourcePageDateEditorForm: View {
    @Bindable var model: SourcePageModel
    @Binding var canSave: Bool
    @Binding var saveAction: (() async -> Void)?

    @State private var wording = ""
    @State private var draft = DateValueDraft.empty()

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space7) {
            PVField(
                label: L10n.Sources.dateValueAsWritten,
                hint: L10n.Sources.dateValueAsWrittenHint,
                required: true
            ) {
                PVTextArea(
                    text: $wording,
                    lineLimit: 1...4,
                    typography: .mono,
                    activateOnAppear: true
                )
                .disabled(model.metadata.isSavingDate)
                .accessibilityIdentifier("sources.page.date.valueAsWritten")
            }
            DateValueEditorForm(draft: $draft, accessibilityIdentifierPrefix: "sources.page.date")
        }
        .onAppear(perform: seed)
        .onChange(of: wording) { _, _ in refreshConfirm() }
        .onChange(of: draft) { _, _ in refreshConfirm() }
        .onChange(of: model.metadata.isSavingDate) { _, _ in refreshConfirm() }
    }

    private func seed() {
        if let fieldID = model.metadata.dateEditorFieldID {
            wording = model.metadata.drafts[fieldID]
                ?? model.metadata.entries.first(where: { $0.field.id == fieldID })?.valueText
                ?? ""
        }
        draft = model.metadata.dateEditorDraft
        refreshConfirm()
    }

    private func refreshConfirm() {
        let wordingOK = !wording.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        canSave = wordingOK && draft.isValid && !model.metadata.isSavingDate
        saveAction = {
            await model.metadata.saveDateEditor(wording: wording, draft: draft)
        }
    }
}

/// Text metadata row editor with a **local** draft so keystrokes do not rewrite
/// `SourceMetadataSection.drafts` (and rebuild the reorderable `List`) on every
/// character — that was dropping TextField focus and feeling multi-second laggy.
private struct SourcePageMetadataTextEditor: View {
    let entry: CatalogMetadataEntry
    let isEditing: Bool
    let isSaving: Bool
    let onBeginEdit: () -> Void
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var draft = ""

    var body: some View {
        let fieldID = entry.field.id
        return PVInlineEdit(
            isEditing: isEditing,
            isSaving: isSaving,
            saveLabel: L10n.Sources.saveMetadataValue,
            cancelLabel: L10n.Sources.cancelEdit,
            editLabel: L10n.Sources.editMetadataValue,
            saveDisabled: draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            axis: .horizontal,
            actionsStyle: .iconStack,
            accessibilityIdentifierPrefix: "sources.page.metadata.\(fieldID)",
            onEdit: {
                draft = entry.valueText
                onBeginEdit()
            },
            onSave: { onSave(draft) },
            onCancel: {
                draft = entry.valueText
                onCancel()
            }
        ) {
            Text(entry.valueText)
                .font(PVFont.mono(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .sourcePageMetadataValueChrome()
                .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")
        } editor: {
            PVTextArea(
                text: $draft,
                lineLimit: 1...6,
                typography: .mono,
                activateOnAppear: true
            )
            .onSubmit { onSave(draft) }
            .disabled(isSaving)
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                draft = entry.valueText
            }
        }
    }
}
