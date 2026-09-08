import SwiftUI

/// Mirrors `components/feedback/Dialog.jsx`: a modal panel with a display
/// title, optional subtitle, a body, and a right-aligned footer on the
/// sunken surface.
///
/// **Platform deviation.** The web component paints its own scrim
/// (`--surface-overlay` + 2px blur) and positions itself over the nearest
/// ancestor, because the browser has nothing better. macOS does: present
/// `PVDialog` from `.sheet`, which gives real modality, the system's own
/// dimming and focus containment, and Escape-to-close for free. So this
/// type renders only the panel — the card, border, header rule and footer
/// — and the call site owns presentation:
///
/// ```swift
/// .sheet(isPresented: $isConfirming) {
///     PVDialog(title: …, subtitle: …) { Text(…) } footer: { … }
/// }
/// ```
///
/// The web spec's `onClose` × close button is likewise dropped: a sheet is
/// dismissed by its own footer buttons and by Escape, so a second affordance
/// in the header would be redundant chrome on this platform.
struct PVDialog<Content: View, Footer: View>: View {
    private let title: Text
    private let subtitle: Text?
    /// Kept alongside `title` for the container's accessibility label, which
    /// takes a `Text` but is not the same element that renders it.
    private let accessibilityTitle: Text
    private let width: CGFloat
    private let content: Content
    private let footer: Footer

    /// `Dialog.jsx`'s `width` prop default.
    static var defaultWidth: CGFloat { 520 }

    init(
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource? = nil,
        width: CGFloat = PVDialog.defaultWidth,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            title: Text(title),
            subtitle: subtitle.map(Text.init),
            width: width,
            content: content,
            footer: footer
        )
    }

    /// For a title that interpolates data (a record's own label), which is
    /// not translatable UI copy — the caller formats it through `L10n` and
    /// hands over the finished `Text`.
    init(
        title: Text,
        subtitle: Text? = nil,
        width: CGFloat = PVDialog.defaultWidth,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        accessibilityTitle = title
        self.width = width
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: PVSpacing.space6) {
                content
            }
            .font(PVFont.body(size: PVTypeScale.bodySmall))
            .foregroundStyle(PVColor.textSecondary)
            .padding(PVSpacing.space8)
            .frame(maxWidth: .infinity, alignment: .leading)
            footerBar
        }
        .frame(width: width)
        .background(PVColor.surfaceCard)
        .overlay(
            RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous)
                .stroke(PVColor.borderDefault, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space2) {
            title
                .font(PVFont.display(size: PVTypeScale.h2))
                .foregroundStyle(PVColor.textDisplay)
            if let subtitle {
                subtitle
                    .font(PVFont.body(size: PVTypeScale.bodySmall))
                    .foregroundStyle(PVColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PVSpacing.space8)
        .padding(.top, PVSpacing.space7)
        .padding(.bottom, PVSpacing.space6)
        .overlay(alignment: .bottom) {
            PVDivider()
        }
    }

    private var footerBar: some View {
        HStack(spacing: PVSpacing.space5) {
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, PVSpacing.space8)
        .padding(.vertical, PVSpacing.space6)
        .background(PVColor.surfaceSunken)
        .overlay(alignment: .top) {
            PVDivider()
        }
    }
}

#Preview {
    PVDialog(
        title: "Delete Grandma's album code?",
        subtitle: "Deleting a field removes it from this project's vocabulary. Sources already saved keep their values."
    ) {
        Text("No source in this project uses grandmas-album-code, so nothing loses data. The key is released and could be minted again by a later field with the same label.")
            .fixedSize(horizontal: false, vertical: true)
    } footer: {
        PVButton("Keep field", variant: .ghost) {}
        PVButton("Delete field", variant: .danger, icon: .trash) {}
    }
    .padding(PVSpacing.space9)
    .background(PVColor.surfacePage)
}
