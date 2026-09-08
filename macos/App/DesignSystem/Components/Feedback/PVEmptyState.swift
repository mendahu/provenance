import SwiftUI

/// A "nothing here yet" placeholder — mirrors `components/feedback/EmptyState.jsx`
/// (dashed border, faint icon, display-font title, muted prose body).
/// `message` is a plain `String` (like `PVToast`'s) since callers often
/// interpolate dynamic content (e.g. a search query) into it; pass
/// `String(localized: …)` for fixed copy. The web spec's `action` slot
/// isn't ported — no call site needs it yet (the primary CTA already lives
/// in the surrounding toolbar); add it here, following `PVButton`'s
/// pattern, if a future screen needs an empty state with its own button.
struct PVEmptyState: View {
    private let icon: PVSymbol
    private let title: LocalizedStringResource?
    private let message: String?
    private let compact: Bool

    init(
        icon: PVSymbol,
        title: LocalizedStringResource? = nil,
        message: String? = nil,
        compact: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.compact = compact
    }

    var body: some View {
        VStack(spacing: PVSpacing.space5) {
            PVIcon(icon, size: compact ? 20 : 26)
                .foregroundStyle(PVColor.textFaint)
            if let title {
                Text(title)
                    .font(PVFont.display(size: PVTypeScale.h3))
                    .foregroundStyle(PVColor.textDisplay)
            }
            if let message {
                Text(message)
                    .font(PVFont.body(size: PVTypeScale.bodySmall))
                    .foregroundStyle(PVColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: PVSpacing.measureNarrow)
            }
        }
        .padding(.vertical, compact ? PVSpacing.space9 : PVSpacing.space12)
        .padding(.horizontal, compact ? PVSpacing.space8 : PVSpacing.space9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous)
                .fill(PVColor.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous)
                .strokeBorder(PVColor.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous))
    }
}

#Preview {
    VStack(spacing: PVSpacing.space9) {
        PVEmptyState(
            icon: .tag,
            title: "No source fields yet",
            message: "This project has no metadata vocabulary. Add the fields your records actually carry."
        )
        PVEmptyState(icon: .searchEmpty, title: "No field selected", compact: true)
    }
    .padding(PVSpacing.space9)
    .background(PVColor.surfacePage)
}
