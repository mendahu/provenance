import SwiftUI

/// The origin → badge mapping in one place, shared by `SourceFieldsRow`
/// and `SourceFieldsDetailPane`. Origin is an open, backend-owned
/// vocabulary (`core/database/sourcefields`); the client only styles the
/// two values it knows and passes anything else (a `plugin:…` id) through
/// as raw text.
struct SourceFieldOriginBadge: View {
    let origin: String

    var body: some View {
        switch origin {
        case SourceFieldOrigin.provenencia:
            PVBadge(L10n.SourceFields.originSeeded, tone: .accent)
        case SourceFieldOrigin.user:
            PVBadge(L10n.SourceFields.originUser, tone: .warning)
        default:
            PVBadge(text: origin, tone: .info)
        }
    }
}

/// The pill that marks a Provenencia-seeded field inline after its label in
/// the list. Only `provenencia` rows carry one — `user` and `plugin:…` rows
/// show nothing, so the column reads as an exception marker rather than a
/// third origin column. The full origin vocabulary still renders as
/// `SourceFieldOriginBadge` in the detail pane.
struct SourceFieldSeededPill: View {
    let origin: String

    var body: some View {
        if origin == SourceFieldOrigin.provenencia {
            PVBadge(icon: .shieldCheck, label: L10n.SourceFields.seededPill, tone: .accent, subtle: true)
        }
    }
}

/// The data-type → badge mapping in one place. Same open-vocabulary
/// stance as `SourceFieldOriginBadge`: anything the client doesn't know
/// renders as the `text` badge.
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
        SourceFieldOriginBadge(origin: SourceFieldOrigin.provenencia)
        SourceFieldOriginBadge(origin: SourceFieldOrigin.user)
        SourceFieldOriginBadge(origin: "plugin:findagrave")
        SourceFieldDataTypeBadge(dataType: SourceFieldDataType.text)
        SourceFieldDataTypeBadge(dataType: SourceFieldDataType.date)
        SourceFieldSeededPill(origin: SourceFieldOrigin.provenencia)
    }
    .padding(PVSpacing.space9)
    .background(PVColor.surfacePage)
}
