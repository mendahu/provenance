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
