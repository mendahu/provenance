import SwiftUI

/// Visual weight for `PVButton` / `PVButtonStyle`. `link` mirrors the web
/// spec's underlined, no-chrome variant (`Button.jsx`'s `variants.link`) —
/// added for `PVButton`'s use as an inline text action (e.g. "Reset search").
enum PVButtonVariant {
    case primary, secondary, ghost, link
}

/// Shared control size for buttons, inputs, and selects.
enum PVControlSize {
    case sm, md, lg

    var height: CGFloat {
        switch self {
        case .sm: return PVSpacing.controlHeightSmall
        case .md: return PVSpacing.controlHeightMedium
        case .lg: return PVSpacing.controlHeightLarge
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 10
        case .md: return 14
        case .lg: return 20
        }
    }

    var font: Font {
        self == .sm ? PVFont.body(size: PVTypeScale.caption) : PVFont.body(size: PVTypeScale.bodySmall)
    }

    var buttonFont: Font {
        switch self {
        case .sm: return PVFont.body(size: PVTypeScale.caption, weight: PVFontWeight.medium)
        case .md: return PVFont.body(size: PVTypeScale.bodySmall, weight: PVFontWeight.medium)
        case .lg: return PVFont.body(size: PVTypeScale.body, weight: PVFontWeight.medium)
        }
    }
}

/// Provenencia button chrome. Prefer `.buttonStyle(.pv(.primary))` on any `Button`;
/// `PVButton` remains a label convenience for `LocalizedStringResource` titles.
struct PVButtonStyle: ButtonStyle {
    var variant: PVButtonVariant = .secondary
    var size: PVControlSize = .md

    func makeBody(configuration: Configuration) -> some View {
        PVButtonBody(configuration: configuration, variant: variant, size: size)
    }
}

extension ButtonStyle where Self == PVButtonStyle {
    static func pv(_ variant: PVButtonVariant = .secondary, size: PVControlSize = .md) -> PVButtonStyle {
        PVButtonStyle(variant: variant, size: size)
    }
}

/// A styled push button. Always takes a `LocalizedStringResource` label.
///
/// `icon` prepends a leading glyph (`Button.jsx`'s `iconLeft`); `loading`
/// swaps it for a spinner and disables the button (`Button.jsx`'s
/// `loading`) — the web spec spins a `loader` glyph in place, but a native
/// `ProgressView` reads better as a real AppKit spinner than an animated
/// SF Symbol would.
struct PVButton: View {
    private let titleKey: LocalizedStringResource
    private let variant: PVButtonVariant
    private let size: PVControlSize
    private let icon: PVSymbol?
    private let loading: Bool
    private let action: () -> Void

    init(
        _ titleKey: LocalizedStringResource,
        variant: PVButtonVariant = .secondary,
        size: PVControlSize = .md,
        icon: PVSymbol? = nil,
        loading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.variant = variant
        self.size = size
        self.icon = icon
        self.loading = loading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: PVSpacing.space3) {
                if loading {
                    ProgressView()
                        .controlSize(.small)
                } else if let icon {
                    PVIcon(icon, size: size.iconGlyphSize)
                }
                Text(titleKey)
            }
        }
        .buttonStyle(.pv(variant, size: size))
        .disabled(loading)
    }
}

/// Duplicated (not shared) from `PVIconButton.swift`'s identically-named,
/// identically-valued `private` extension — both are file-scoped by
/// design (Swift's `private` on an extension member), so this can't just
/// reference that one.
private extension PVControlSize {
    var iconGlyphSize: CGFloat {
        switch self {
        case .sm: 13
        case .md: 15
        case .lg: 17
        }
    }
}

private struct PVButtonPalette {
    let background: Color
    let hoverBackground: Color?
    let foreground: Color
    let border: Color
    let hoverBorder: Color?

    static func palette(for variant: PVButtonVariant) -> PVButtonPalette {
        switch variant {
        case .primary:
            return PVButtonPalette(
                background: PVColor.accent, hoverBackground: PVColor.accentHover,
                foreground: PVColor.accentForeground,
                border: PVColor.accent, hoverBorder: PVColor.accentHover
            )
        case .secondary:
            return PVButtonPalette(
                background: PVColor.surfaceRaised, hoverBackground: PVColor.surfaceSunken,
                foreground: PVColor.textPrimary,
                border: PVColor.borderDefault, hoverBorder: PVColor.borderStrong
            )
        case .ghost:
            return PVButtonPalette(
                background: .clear, hoverBackground: PVColor.surfaceHover,
                foreground: PVColor.textSecondary,
                border: .clear, hoverBorder: nil
            )
        case .link:
            return PVButtonPalette(
                background: .clear, hoverBackground: nil,
                foreground: PVColor.textLink,
                border: .clear, hoverBorder: nil
            )
        }
    }
}

private struct PVButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let variant: PVButtonVariant
    let size: PVControlSize

    var body: some View {
        let palette = PVButtonPalette.palette(for: variant)

        // `link` drops the button chrome entirely (no padding, fixed
        // height, background, or border) in favor of underlined inline
        // text — `Button.jsx`'s `variants.link` (`padding: 0, height:
        // 'auto', textDecoration: 'underline'`).
        if variant == .link {
            PVHoverEffect(isPressed: configuration.isPressed, hoverAnimation: PVMotion.fastStandard) { showHover in
                configuration.label
                    .font(size.buttonFont)
                    .foregroundStyle(showHover ? PVColor.textLinkHover : palette.foreground)
                    .underline()
            }
        } else {
            PVHoverEffect(isPressed: configuration.isPressed, hoverAnimation: PVMotion.fastStandard) { showHover in
                configuration.label
                    .font(size.buttonFont)
                    .foregroundStyle(palette.foreground)
                    .padding(.horizontal, size.horizontalPadding)
                    .frame(height: size.height)
                    .background(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .fill(showHover ? (palette.hoverBackground ?? palette.background) : palette.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .stroke(showHover ? (palette.hoverBorder ?? palette.border) : palette.border, lineWidth: 1)
                    )
            }
        }
    }
}

#Preview {
    VStack(spacing: PVSpacing.space5) {
        PVButton("Continue", variant: .primary, size: .md) {}
        Button("Custom label") {}
            .buttonStyle(.pv(.secondary, size: .sm))
        PVButton("Back", variant: .ghost, size: .md) {}
        PVButton("Add field", variant: .primary, icon: .plus) {}
        PVButton("Saving", variant: .primary, loading: true) {}
        PVButton("Reset search", variant: .link) {}
    }
    .padding(PVSpacing.space9)
    .background(PVColor.surfacePage)
}
