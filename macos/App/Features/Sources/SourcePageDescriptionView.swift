import SwiftUI

/// Description section: resting prose or explicit edit/save/cancel.
struct SourcePageDescriptionView: View {
    @Bindable var model: SourcePageModel

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            SourcePageSectionHeader(
                title: L10n.Sources.descriptionHeading,
                actions: {
                    if !model.identity.editingDescription {
                        PVButton(
                            L10n.Sources.editDescription,
                            variant: .ghost,
                            size: .sm,
                            icon: .penLine
                        ) {
                            model.identity.beginEditDescription()
                        }
                        .accessibilityIdentifier("sources.page.description.edit")
                    }
                }
            )

            if model.identity.editingDescription {
                VStack(alignment: .leading, spacing: PVSpacing.space4) {
                    TextField(
                        "",
                        text: $model.identity.descriptionDraft,
                        prompt: Text(L10n.Sources.descriptionPlaceholder),
                        axis: .vertical
                    )
                    .font(PVFont.body(size: PVTypeScale.body, weight: PVFontWeight.regular))
                    .foregroundStyle(PVColor.textPrimary)
                    .textFieldStyle(.plain)
                    .lineLimit(3...12)
                    .padding(.horizontal, PVSpacing.space5)
                    .padding(.vertical, PVSpacing.space4)
                    .background(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .fill(PVColor.surfaceCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .stroke(PVColor.borderDefault, lineWidth: 1)
                    )
                    .accessibilityIdentifier("sources.page.description")
                    .disabled(model.identity.isSaving)

                    if let descriptionError = model.identity.descriptionError {
                        Text(descriptionError)
                            .font(PVFont.body(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.danger)
                    }

                    HStack(spacing: PVSpacing.space4) {
                        PVButton(
                            L10n.Sources.saveDescription,
                            variant: .primary,
                            size: .sm,
                            loading: model.identity.isSaving
                        ) {
                            Task { await model.identity.saveDescription() }
                        }
                        .accessibilityIdentifier("sources.page.description.save")
                        PVButton(L10n.Sources.cancelEdit, variant: .ghost, size: .sm) {
                            model.identity.cancelEditDescription()
                        }
                        .disabled(model.identity.isSaving)
                        .accessibilityIdentifier("sources.page.description.cancel")
                    }
                }
            } else if !model.identity.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(model.identity.description)
                    .font(PVFont.body(size: PVTypeScale.body, weight: PVFontWeight.regular))
                    .foregroundStyle(PVColor.textSecondary)
                    .lineSpacing((PVLineHeight.normal - 1) * PVTypeScale.body)
                    .accessibilityIdentifier("sources.page.description")
            }
        }
    }
}
