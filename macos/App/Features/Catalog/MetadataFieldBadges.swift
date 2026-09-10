import SwiftUI

/// `CatalogMetadataField.dataType` namespace — mirrors
/// `core/database/sourcefields`'s `DataType…` constants (the FFI layer
/// carries these as plain strings, not an enum).
enum SourceFieldDataType {
    static let text = "text"
    static let date = "date"
}

/// The data-type → badge mapping in one place, shared by the Source fields
/// list and the suggested-fields list on a Source type. Same open-vocabulary
/// stance as `OriginBadge`: anything the client doesn't know renders as text.
struct SourceFieldDataTypeBadge: View {
    let dataType: String

    var body: some View {
        if dataType == SourceFieldDataType.date {
            PVBadge(L10n.SourceFields.dataTypeDate, tone: .info, icon: .calendar, subtle: true)
        } else {
            PVBadge(L10n.SourceFields.dataTypeText, tone: .neutral, icon: .textType, subtle: true)
        }
    }
}

extension SourceFieldDataType {
    /// Display label for a data-type value — shared by
    /// `SourceFieldDataTypeBadge` and the locked detail's plain-text
    /// rendering in `SourceFieldsDetailPane`.
    static func label(for dataType: String) -> LocalizedStringResource {
        dataType == date ? L10n.SourceFields.dataTypeDate : L10n.SourceFields.dataTypeText
    }
}

#Preview {
    VStack(alignment: .leading, spacing: PVSpacing.space5) {
        SourceFieldDataTypeBadge(dataType: SourceFieldDataType.text)
        SourceFieldDataTypeBadge(dataType: SourceFieldDataType.date)
    }
    .padding(PVSpacing.space9)
    .background(PVColor.surfacePage)
}
