import SwiftUI

/// Provenencia icon-only button chrome (toolbar/chrome actions — the
/// sidebar's collapse toggle is the first call site). Follows
/// `PVButton.swift`'s pattern: hover/pressed state lives in a private
/// backing view (`PVIconButtonBody`), not on the public type.
struct PVIconButton: View {
    private let icon: PVSymbol
    private let size: PVControlSize
    private let action: () -> Void

    init(_ icon: PVSymbol, size: PVControlSize = .md, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            PVIcon(icon, size: size.iconGlyphSize)
        }
        .buttonStyle(PVIconButtonStyle(size: size))
    }
}

private struct PVIconButtonStyle: ButtonStyle {
    var size: PVControlSize = .md

    func makeBody(configuration: Configuration) -> some View {
        PVIconButtonBody(configuration: configuration, size: size)
    }
}

private struct PVIconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let size: PVControlSize

    var body: some View {
        PVHoverEffect(isPressed: configuration.isPressed) { showHover in
            configuration.label
                .foregroundStyle(PVColor.textSecondary)
                .frame(width: size.height, height: size.height)
                .background(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .fill(showHover ? PVColor.surfaceHover : .clear)
                )
        }
    }
}

#Preview {
    HStack(spacing: PVSpacing.space5) {
        PVIconButton(.sidebarToggle) {}
        PVIconButton(.dismiss, size: .sm) {}
        PVIconButton(.account, size: .lg) {}
    }
    .padding(PVSpacing.space9)
    .background(PVColor.surfacePage)
}
