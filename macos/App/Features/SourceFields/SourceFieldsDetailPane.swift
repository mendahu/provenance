import SwiftUI

/// The right pane of `SourceFieldsView`: the add-field form, a selected
/// field's detail (editable for `user` / `provenencia`, locked read-only for
/// `plugin:…`), or an empty prompt when nothing is selected — S2-02 §3.2/3.3.
struct SourceFieldsDetailPane: View {
    @Bindable var model: SourceFieldsModel

    var body: some View {
        ScrollView {
            content
        }
        .background(PVColor.surfaceCard)
        .accessibilityIdentifier("sourceFields.detail")
    }

    @ViewBuilder
    private var content: some View {
        if model.isAdding {
            panel(isLocked: false)
        } else if model.selectedField != nil {
            panel(isLocked: model.isSelectedFieldLocked)
        } else {
            PVEmptyState(
                icon: .tag,
                title: L10n.SourceFields.panelEmptyTitle,
                message: String(localized: L10n.SourceFields.panelEmptyBody),
                compact: true
            )
            .padding(PVSpacing.space9)
        }
    }

    private func panel(isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space7) {
            panelHeader
            if isLocked {
                lockedBody
            } else {
                form
            }
        }
        .padding(PVSpacing.space8)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Force a fresh subtree when switching add / view / edit so form
        // bindings are not reused across modes that no longer own a draft.
        .id(panelIdentity)
    }

    private var panelIdentity: String {
        switch model.mode {
        case .empty: "empty"
        case .adding: "adding"
        case .viewing(let id): "viewing-\(id)"
        case .editing(let id): "editing-\(id)"
        }
    }

    // MARK: Header (shared by add / locked / editable)

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            Text(model.isAdding ? L10n.SourceFields.detailEyebrowNewField : L10n.SourceFields.detailEyebrowField)
                .pvMicroCaps()
                .foregroundStyle(PVColor.textMuted)
            Text(panelTitle)
                .font(PVFont.display(size: PVTypeScale.h2))
                .foregroundStyle(PVColor.textDisplay)
            HStack(spacing: PVSpacing.space5) {
                originBadge
                Text(panelKey)
                    .font(PVFont.mono(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textSecondary)
                    .accessibilityIdentifier("sourceFields.detail.key")
            }
            Text(model.isAdding ? L10n.SourceFields.keyHintAdd : L10n.SourceFields.keyHintEdit)
                .font(PVFont.body(size: PVTypeScale.micro, italic: true))
                .foregroundStyle(PVColor.textMuted)
        }
    }

    private var panelTitle: String {
        if model.isAdding {
            let label = model.draft?.label.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return label.isEmpty ? String(localized: L10n.SourceFields.detailEyebrowNewField) : label
        }
        return model.selectedField?.label ?? ""
    }

    private var panelKey: String {
        if model.isAdding {
            let key = model.draftKey
            return key.isEmpty ? "—" : key
        }
        return model.selectedField?.key ?? ""
    }

    private var originBadge: some View {
        SourceFieldOriginBadge(
            origin: model.isAdding ? SourceFieldOrigin.user : (model.selectedField?.origin ?? SourceFieldOrigin.user)
        )
    }

    // MARK: Locked (plugin) detail

    @ViewBuilder
    private var lockedBody: some View {
        if let field = model.selectedField {
            VStack(alignment: .leading, spacing: PVSpacing.space7) {
                PVCallout(tone: .neutral, icon: .lock, message: lockedNote(for: field), compact: true)
                labeledSection(L10n.SourceFields.dataTypeSectionLabel) {
                    Text(SourceFieldDataType.label(for: field.dataType))
                        .font(PVFont.body(size: PVTypeScale.bodySmall))
                        .foregroundStyle(PVColor.textPrimary)
                }
                labeledSection(L10n.SourceFields.descriptionSectionLabel) {
                    Text(field.description.isEmpty ? String(localized: L10n.SourceFields.descriptionEmptyPlaceholder) : field.description)
                        .font(PVFont.body(size: PVTypeScale.bodySmall))
                        .foregroundStyle(PVColor.textSecondary)
                }
            }
            .padding(.top, PVSpacing.space7)
            .overlay(alignment: .top) {
                PVDivider()
            }
        }
    }

    private func lockedNote(for field: CatalogMetadataField) -> String {
        L10n.SourceFields.lockedNotePlugin(pluginID: SourceFieldOrigin.pluginID(from: field.origin))
    }

    private func labeledSection(_ label: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space2) {
            Text(label)
                .pvMicroCaps()
                .foregroundStyle(PVColor.textMuted)
            content()
        }
    }

    // MARK: Add / editable form

    private var dataTypeOptions: [PVSelectOption] {
        [
            PVSelectOption(value: SourceFieldDataType.text, label: String(localized: L10n.SourceFields.dataTypeText)),
            PVSelectOption(value: SourceFieldDataType.date, label: String(localized: L10n.SourceFields.dataTypeDate)),
        ]
    }

    /// `panel(isLocked: false)` is only reached in `.adding` / `.editing`,
    /// where `draft` is set, so the `Binding($model.draft)` unwrap always
    /// succeeds in practice.
    @ViewBuilder
    private var form: some View {
        if let draft = Binding($model.draft) {
            VStack(alignment: .leading, spacing: PVSpacing.space7) {
                PVField(label: L10n.SourceFields.formLabel, error: model.formError, required: true) {
                    PVInput(
                        text: draft.label,
                        prompt: model.isAdding ? L10n.SourceFields.formLabelPlaceholder : nil,
                        isInvalid: model.formError != nil
                    )
                }
                PVField(label: L10n.SourceFields.formDataType, hint: model.isAdding ? L10n.SourceFields.formDataTypeHint : L10n.SourceFields.formDataTypeImmutableHint) {
                    if model.isAdding {
                        PVSelect(selection: draft.dataType, options: dataTypeOptions)
                    } else {
                        Text(SourceFieldDataType.label(for: draft.wrappedValue.dataType))
                            .font(PVFont.body(size: PVTypeScale.body))
                            .foregroundStyle(PVColor.textPrimary)
                            .accessibilityIdentifier("sourceFields.form.dataType.readonly")
                    }
                }
                PVField(label: L10n.SourceFields.formDescription, hint: L10n.SourceFields.formDescriptionHint) {
                    PVInput(text: draft.description, prompt: model.isAdding ? L10n.SourceFields.formDescriptionPlaceholder : nil)
                }
                HStack(spacing: PVSpacing.space5) {
                    PVButton(primaryLabel, variant: .primary, loading: model.isSaving) {
                        Task { await model.submit() }
                    }
                    .disabled(!model.canSubmit)
                    .accessibilityIdentifier("sourceFields.form.submit")
                    PVButton(secondaryLabel, variant: .ghost) {
                        secondaryAction()
                    }
                    .disabled(model.isSaving || (!model.isAdding && !model.isDirty))
                    .accessibilityIdentifier("sourceFields.form.secondary")
                }
            }
            .padding(.top, PVSpacing.space7)
            .overlay(alignment: .top) {
                PVDivider()
            }
        }
    }

    private var primaryLabel: LocalizedStringResource {
        if model.isSaving { return L10n.SourceFields.saveSaving }
        return model.isAdding ? L10n.SourceFields.addField : L10n.SourceFields.saveChanges
    }

    private var secondaryLabel: LocalizedStringResource {
        model.isAdding ? L10n.SourceFields.cancel : L10n.SourceFields.revert
    }

    private func secondaryAction() {
        if model.isAdding {
            model.cancelAdd()
        } else {
            model.revertEdit()
        }
    }
}
