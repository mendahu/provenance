import SwiftUI

/// Shared chrome for single-line inputs (focus ring, inset rest shadow).
///
/// **Every layer here is structurally identical whether or not the field
/// is focused** — only colors and opacities change. That is not a style
/// preference, it's load-bearing: an earlier version switched between
/// `pvFocusRing` and `pvInsetShadow` with an `if/else` (two different view
/// types, so `_ConditionalContent`) and wrapped the whole thing in
/// `.animation(_:value: isFocused)`. Both are keyed on focus, so the
/// instant the field became first responder SwiftUI structurally replaced
/// the subtree — including the embedded `NSTextField` — and focus was
/// destroyed by the very act of acquiring it. Symptom: click does nothing
/// (or accepts exactly one keystroke), then the field is inert and typing
/// beeps. Isolated with a battery of diagnostic fields; a chrome with the
/// same padding/background/border but no focus-keyed branch or animation
/// worked fine.
///
/// So: no `if/else` in this chain, and no animation modifier wrapping the
/// field. The border/ring transitions are animated on the decorative
/// shapes themselves, which don't contain the field.
struct PVInputChrome: ViewModifier {
    var size: PVControlSize = .md
    var mono: Bool = false
    var isFocused: Bool = false
    var isInvalid: Bool = false
    /// Reserves room on the left for `PVInput`'s icon overlay.
    var leadingIconInset: Bool = false

    func body(content: Content) -> some View {
        content
            .font(mono ? PVFont.mono(size: size == .sm ? PVTypeScale.caption : PVTypeScale.bodySmall) : size.font)
            .foregroundStyle(PVColor.textPrimary)
            .padding(.leading, leadingIconInset ? 10 + 14 + 7 : 10)
            .padding(.trailing, 10)
            .frame(height: size.height)
            .background(
                RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                    .fill(PVColor.surfaceRaised)
            )
            .overlay(border)
            .pvInsetShadow(cornerRadius: PVRadius.sm, visible: !isFocused)
            .pvFocusRing(isFocused, cornerRadius: PVRadius.sm)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
            .allowsHitTesting(false)
            .pvAnimation(PVMotion.fastStandard, value: isFocused)
            .pvAnimation(PVMotion.fastStandard, value: isInvalid)
    }

    private var borderColor: Color {
        if isInvalid { return PVColor.danger }
        return isFocused ? PVColor.borderFocus : PVColor.borderDefault
    }
}

/// Convenience field with optional leading icon, read-only rendering, and
/// owned focus state.
struct PVInput: View {
    @Binding private var text: String
    private let size: PVControlSize
    private let mono: Bool
    private let isReadOnly: Bool
    private let prompt: LocalizedStringResource?
    private let icon: PVSymbol?
    private let isInvalid: Bool

    init(
        text: Binding<String>,
        size: PVControlSize = .md,
        mono: Bool = false,
        isReadOnly: Bool = false,
        prompt: LocalizedStringResource? = nil,
        icon: PVSymbol? = nil,
        isInvalid: Bool = false
    ) {
        self._text = text
        self.size = size
        self.mono = mono
        self.isReadOnly = isReadOnly
        self.prompt = prompt
        self.icon = icon
        self.isInvalid = isInvalid
    }

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isReadOnly {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(PVInputChrome(size: size, mono: mono, isFocused: false, isInvalid: isInvalid, leadingIconInset: icon != nil))
            } else if let prompt {
                TextField("", text: $text, prompt: Text(prompt))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .modifier(PVInputChrome(size: size, mono: mono, isFocused: isFocused, isInvalid: isInvalid, leadingIconInset: icon != nil))
            } else {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .modifier(PVInputChrome(size: size, mono: mono, isFocused: isFocused, isInvalid: isInvalid, leadingIconInset: icon != nil))
            }
        }
        .overlay(alignment: .leading) {
            if let icon {
                PVIcon(icon, size: 14)
                    .foregroundStyle(PVColor.textFaint)
                    .padding(.leading, 10)
                    .allowsHitTesting(false)
            }
        }
    }
}

#Preview {
    VStack(spacing: PVSpacing.space5) {
        PVInput(text: .constant(""), prompt: "Search fields")
        PVInput(text: .constant(""), prompt: "Search fields", icon: .search)
        PVInput(text: .constant("USR-A1B2C"), mono: true)
        PVInput(text: .constant("Jane Smith"), isReadOnly: true)
        PVInput(text: .constant(""), prompt: "Required", isInvalid: true)
    }
    .padding(PVSpacing.space9)
    .frame(width: 320)
    .background(PVColor.surfacePage)
}
