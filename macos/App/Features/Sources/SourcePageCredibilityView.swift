import SwiftUI

/// Credibility assessment: grade chips, argument, save/cancel.
struct SourcePageCredibilityView: View {
    @Bindable var model: SourcePageModel

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            SourcePageSectionHeader(
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

            HStack(spacing: PVSpacing.space4) {
                ForEach(model.credibility.grades, id: \.id) { grade in
                    credibilityChip(grade)
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
                PVButton(
                    L10n.Sources.saveAssessment,
                    variant: .primary,
                    size: .sm,
                    loading: model.credibility.isSaving
                ) {
                    Task { await model.credibility.save() }
                }
                .disabled(!model.credibility.isDirty && !model.credibility.isSaving)
                .accessibilityIdentifier("sources.page.credibility.save")

                if model.credibility.isDirty {
                    PVButton(L10n.Sources.cancelEdit, variant: .ghost, size: .sm) {
                        model.credibility.cancel()
                    }
                    .disabled(model.credibility.isSaving)
                    .accessibilityIdentifier("sources.page.credibility.cancel")
                } else {
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

    private func credibilityChip(_ grade: CatalogCredibilityGrade) -> some View {
        let selected = model.credibility.draftKey == grade.key
        let dashedUnset = grade.key == "standard"
            && !model.credibility.hasSavedAssessment
            && model.credibility.draftKey == "standard"
        let colors = credibilityColors(for: grade.key)
        return Button {
            model.credibility.selectDraft(key: grade.key)
        } label: {
            Text(grade.label)
                .font(PVFont.body(
                    size: PVTypeScale.caption,
                    weight: selected ? PVFontWeight.semibold : PVFontWeight.regular
                ))
                .foregroundStyle(selected ? colors.fg : PVColor.textSecondary)
                .padding(.horizontal, PVSpacing.space5)
                .padding(.vertical, PVSpacing.space3)
                .background(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .fill(selected ? colors.bg : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .strokeBorder(
                            selected ? colors.fg : PVColor.borderDefault,
                            style: StrokeStyle(lineWidth: 1, dash: dashedUnset ? [4, 3] : [])
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sources.page.credibility.\(grade.key)")
    }

    private func credibilityColors(for key: String) -> (bg: Color, fg: Color) {
        switch key {
        case "low_trust":
            return (PVColor.dangerSoft, PVColor.danger)
        case "high_trust":
            return (PVColor.successSoft, PVColor.success)
        default:
            return (PVColor.accentSoft, PVColor.accent)
        }
    }
}
