import SwiftUI

/// Shared layout metrics for Source page section rows — replaces ad-hoc
/// `170` / `150` / `20 + space5 + …` paddings scattered through the page.
enum SourcePageLayout {
    /// Field-label column on metadata saved + suggestion rows.
    static let metadataLabelWidth: CGFloat = 170
    /// Matches `PVReorderHandle`'s frame width.
    static let reorderHandleWidth: CGFloat = 20
    /// Spacing between handle, label, and value on metadata rows.
    static let metadataColumnSpacing = PVSpacing.space5
    /// Leading inset so suggestion labels line up with saved-row labels
    /// (saved rows reserve a reorder-handle column).
    static var metadataSuggestionLabelInset: CGFloat { reorderHandleWidth }
    /// Leading inset for the structured-date sub-row under a saved value —
    /// clears the handle + label columns.
    static var metadataDateRowInset: CGFloat {
        reorderHandleWidth + metadataColumnSpacing + metadataLabelWidth + metadataColumnSpacing
    }
    /// Author / timestamp column on note rows and the composer byline.
    static let notesBylineWidth: CGFloat = 150
    /// Accordion chevron frame width in an artifact row.
    static let artifactChevronWidth: CGFloat = 18
    /// Thumbnail size in a collapsed artifact row.
    static let artifactRowThumbnailSize: CGFloat = 44
    /// Indent for expanded artifact detail under chevron + thumbnail.
    static var artifactDetailLeading: CGFloat {
        artifactChevronWidth + artifactRowThumbnailSize
    }
}

/// Title + optional meta + aside + actions + bottom rule. Hoisted from the
/// page monolith so every section file can share it (DS promotion is fix 11).
struct SourcePageSectionHeader<Aside: View, Actions: View>: View {
    let title: LocalizedStringResource
    var meta: String? = nil
    @ViewBuilder var aside: () -> Aside
    @ViewBuilder var actions: () -> Actions

    init(
        title: LocalizedStringResource,
        meta: String? = nil,
        @ViewBuilder aside: @escaping () -> Aside = { EmptyView() },
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.meta = meta
        self.aside = aside
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: PVSpacing.space5) {
            Text(title)
                .font(PVFont.display(size: PVTypeScale.h3, weight: PVFontWeight.semibold))
                .foregroundStyle(PVColor.textDisplay)
            if let meta {
                Text(meta)
                    .font(PVFont.mono(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
            }
            aside()
            Spacer(minLength: 0)
            actions()
        }
        .padding(.bottom, PVSpacing.space4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PVColor.borderDefault)
                .frame(height: 1)
        }
    }
}

/// Label column used by metadata saved / suggestion rows.
struct SourcePageMetadataLabel: View {
    let text: String
    /// When true, pads leading by the reorder-handle gutter so suggestion
    /// labels align with saved-row labels.
    var alignWithReorderHandle: Bool = false
    var topPadding: CGFloat = 0

    var body: some View {
        Text(text)
            .font(PVFont.body(size: PVTypeScale.caption))
            .foregroundStyle(PVColor.textMuted)
            .frame(width: SourcePageLayout.metadataLabelWidth, alignment: .leading)
            .padding(.leading, alignWithReorderHandle ? SourcePageLayout.metadataSuggestionLabelInset : 0)
            .padding(.top, topPadding)
    }
}
