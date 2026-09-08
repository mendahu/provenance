import SwiftUI

/// Hover/selected chrome for `SourceFieldsRow`, following `PVButtonBody`'s
/// pattern (state lives in a private `ButtonStyle` body, not the row type).
private struct SourceFieldsRowStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        PVHoverEffect(isPressed: configuration.isPressed, hoverAnimation: PVMotion.fastStandard) { showHover in
            configuration.label
                .background(isSelected ? PVColor.surfaceSelected : (showHover ? PVColor.surfaceHover : Color.clear))
                .overlay(alignment: .leading) {
                    Rectangle().fill(isSelected ? PVColor.accent : .clear).frame(width: 2)
                }
        }
    }
}

/// One row in the Source fields list: label, key, data-type badge, origin
/// badge — S2-02 F-2/F-3 plus a permanent key column (not optional in this
/// implementation, unlike the S2-02 board's `showKeyColumn` toggle).
struct SourceFieldsRow: View {
    let field: CatalogMetadataField
    let isSelected: Bool
    let select: () -> Void

    static let keyColumnWidth: CGFloat = 160
    static let dataTypeColumnWidth: CGFloat = 100
    static let originColumnWidth: CGFloat = 140

    var body: some View {
        Button(action: select) {
            HStack(spacing: PVSpacing.space6) {
                Text(field.label)
                    .font(PVFont.body(size: PVTypeScale.bodySmall))
                    .foregroundStyle(PVColor.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(field.key)
                    .font(PVFont.mono(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: Self.keyColumnWidth, alignment: .leading)
                SourceFieldDataTypeBadge(dataType: field.dataType)
                    .frame(width: Self.dataTypeColumnWidth, alignment: .leading)
                SourceFieldOriginBadge(origin: field.origin)
                    .frame(width: Self.originColumnWidth, alignment: .leading)
            }
            .padding(.horizontal, PVSpacing.gutterPage)
            .padding(.vertical, PVSpacing.space4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(SourceFieldsRowStyle(isSelected: isSelected))
        .accessibilityIdentifier("sourceFields.row.\(field.id)")
    }
}

#Preview {
    VStack(spacing: 0) {
        SourceFieldsRow(
            field: CatalogMetadataField(id: "1", key: "author", origin: "provenencia", label: "Author", dataType: "text", description: ""),
            isSelected: false, select: {}
        )
        SourceFieldsRow(
            field: CatalogMetadataField(id: "2", key: "grandmas-album-code", origin: "user", label: "Grandma's album code", dataType: "text", description: ""),
            isSelected: true, select: {}
        )
    }
    .background(PVColor.surfaceCard)
}
