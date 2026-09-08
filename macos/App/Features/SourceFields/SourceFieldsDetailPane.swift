import SwiftUI

/// The right pane of `SourceFieldsView`: the add-field form, a selected
/// field's detail (locked read-only for `provenencia`/`plugin:…`, editable
/// for `user`), or an empty prompt when nothing is selected — S2-02 §3.2/3.3.
struct SourceFieldsDetailPane: View {
    let model: SourceFieldsModel

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
    }

    // MARK: Header (shared by add / locked / editable)

    private var panelHeader: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            Text(model.isAdding ? L10n.SourceFields.detailEyebrowNewField : L10n.SourceFields.detailEyebrowField)
                .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                .tracking(PVTypeScale.micro * PVTracking.caps)
                .textCase(.uppercase)
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

    @ViewBuilder
    private var originBadge: some View {
        let origin = model.isAdding ? SourceFieldOrigin.user : (model.selectedField?.origin ?? SourceFieldOrigin.user)
        switch origin {
        case SourceFieldOrigin.provenencia:
            PVBadge(L10n.SourceFields.originSeeded, tone: .accent)
        case SourceFieldOrigin.user:
            PVBadge(L10n.SourceFields.originUser, tone: .warning)
        default:
            PVBadge(text: origin, tone: .info)
        }
    }

    // MARK: Locked (provenencia / plugin) detail

    @ViewBuilder
    private var lockedBody: some View {
        if let field = model.selectedField {
            VStack(alignment: .leading, spacing: PVSpacing.space7) {
                PVCallout(tone: .neutral, icon: .lock, message: lockedNote(for: field), compact: true)
                labeledSection(L10n.SourceFields.dataTypeSectionLabel) {
                    Text(field.dataType == SourceFieldDataType.date ? L10n.SourceFields.dataTypeDate : L10n.SourceFields.dataTypeText)
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
                Rectangle().fill(PVColor.borderSubtle).frame(height: 1)
            }
        }
    }

    private func lockedNote(for field: CatalogMetadataField) -> String {
        if field.origin == SourceFieldOrigin.provenencia {
            return String(localized: L10n.SourceFields.lockedNoteSeeded)
        }
        let pluginID = field.origin.hasPrefix("plugin:") ? String(field.origin.dropFirst("plugin:".count)) : field.origin
        return L10n.SourceFields.lockedNotePlugin(pluginID: pluginID)
    }

    private func labeledSection(_ label: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space2) {
            Text(label)
                .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                .tracking(PVTypeScale.micro * PVTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(PVColor.textMuted)
            content()
        }
    }

    // MARK: Add / editable form

    private var labelBinding: Binding<String> {
        Binding(get: { model.draft?.label ?? "" }, set: { model.draft?.label = $0 })
    }

    private var dataTypeBinding: Binding<String> {
        Binding(get: { model.draft?.dataType ?? SourceFieldDataType.text }, set: { model.draft?.dataType = $0 })
    }

    private var descriptionBinding: Binding<String> {
        Binding(get: { model.draft?.description ?? "" }, set: { model.draft?.description = $0 })
    }

    private var dataTypeOptions: [PVSelectOption] {
        [
            PVSelectOption(value: SourceFieldDataType.text, label: String(localized: L10n.SourceFields.dataTypeText)),
            PVSelectOption(value: SourceFieldDataType.date, label: String(localized: L10n.SourceFields.dataTypeDate)),
        ]
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space7) {
            PVField(label: L10n.SourceFields.formLabel, error: formError, required: true) {
                PVInput(
                    text: labelBinding,
                    prompt: model.isAdding ? L10n.SourceFields.formLabelPlaceholder : nil,
                    isInvalid: formError != nil
                )
            }
            PVField(label: L10n.SourceFields.formDataType, hint: L10n.SourceFields.formDataTypeHint) {
                PVSelect(selection: dataTypeBinding, options: dataTypeOptions)
            }
            PVField(label: L10n.SourceFields.formDescription, hint: L10n.SourceFields.formDescriptionHint) {
                PVInput(text: descriptionBinding, prompt: model.isAdding ? L10n.SourceFields.formDescriptionPlaceholder : nil)
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
            Rectangle().fill(PVColor.borderSubtle).frame(height: 1)
        }
    }

    private var formError: String? {
        model.formError
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
