import SwiftUI

/// Credibility assessment: grade chips, argument, save/cancel.
struct SourcePageCredibilityView: View {
    @Bindable var model: SourcePageModel

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            PVSectionHeader(
                title: L10n.Sources.credibilityHeading,
                aside: {
                    Text(
                        model.credibility.hasSavedAssessment
                            ? L10n.Sources.credibilityHint
                            : L10n.Sources.credibilityHintUnset
                    )
                    .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                    .foregroundStyle(PVColor.textMuted)
                    .lineLimit(2)
                }
            )

            PVChipGroup(style: .loose, spacing: PVSpacing.space4) {
                ForEach(model.credibility.grades, id: \.id) { grade in
                    PVChip(
                        text: grade.label,
                        isSelected: model.credibility.draftKey == grade.key,
                        tone: tone(for: grade.key),
                        isDashed: isDashedUnset(grade),
                        action: { model.credibility.selectDraft(key: grade.key) }
                    )
                    .accessibilityIdentifier("sources.page.credibility.\(grade.key)")
                }
            }
            .accessibilityIdentifier("sources.page.credibility.grades")

            PVInput(
                text: $model.credibility.argumentDraft,
                size: .sm,
                prompt: L10n.Sources.credibilityArgumentPlaceholder
            )
            .accessibilityIdentifier("sources.page.credibility.argument")

            HStack(spacing: PVSpacing.space4) {
                PVInlineEditActions(
                    isSaving: model.credibility.isSaving,
                    saveLabel: L10n.Sources.saveAssessment,
                    cancelLabel: L10n.Sources.cancelEdit,
                    saveDisabled: !model.credibility.isDirty,
                    showsCancel: model.credibility.isDirty,
                    accessibilityIdentifierPrefix: "sources.page.credibility",
                    onSave: { Task { await model.credibility.save() } },
                    onCancel: { model.credibility.cancel() }
                )

                if !model.credibility.isDirty {
                    Text(
                        model.credibility.hasSavedAssessment
                            ? L10n.Sources.credibilitySavedStatus
                            : L10n.Sources.credibilityUnsavedStatus
                    )
                    .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                    .foregroundStyle(PVColor.textFaint)
                }
            }
        }
    }

    /// Domain mapping: catalog credibility keys → generic chip tones.
    /// Not evidence-grade colors (proven/probable/…).
    private func tone(for key: String) -> PVChip.Tone {
        switch key {
        case "low_trust": return .danger
        case "high_trust": return .success
        default: return .accent
        }
    }

    private func isDashedUnset(_ grade: CatalogCredibilityGrade) -> Bool {
        grade.key == "standard"
            && !model.credibility.hasSavedAssessment
            && model.credibility.draftKey == "standard"
    }
}
