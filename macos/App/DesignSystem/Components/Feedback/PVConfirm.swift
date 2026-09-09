import SwiftUI

/// The macOS-native counterpart to `components/feedback/ConfirmDialog.jsx`,
/// ported from the design system's `swift/ProvenenciaConfirm.swift`.
///
/// **`ConfirmDialog` is deliberately not ported.** Its own `prompt.md` says so:
/// the web component draws a scrim, a backdrop blur, a corner radius and a
/// shadow only because a browser gives it none of them. On macOS all four
/// belong to the window:
///
/// - macOS does **not** dim the parent window behind a sheet — the parent's
///   controls just go inactive. A dark scrim is a web/iOS idiom and reads as
///   wrong here. The absent scrim is correct, not missing.
/// - The sheet window supplies its own corner radius, shadow and material.
///   Setting `.background` / `.cornerRadius` / `.shadow` on sheet content is
///   what produces the double-rounded, double-shadowed panel — so nothing in
///   this file sets any of them.
/// - Sheets are modal to their *window*, not the app, and slide from the
///   titlebar. That comes free from `.sheet`.
///
/// So there are two right answers, and both live here:
///
/// 1. ``SwiftUI/View/pvConfirm(isPresented:copy:tone:onConfirm:)`` — a system
///    alert. The default: Apple's own pattern, fully system-drawn, and it
///    inherits keyboard, VoiceOver and Reduce Motion behaviour for free.
///    Message copy is plain text only.
/// 2. ``SwiftUI/View/pvConfirmSheet(isPresented:copy:tone:isRunning:onConfirm:detail:)``
///    — a sheet, for when the consequence needs rich content (a mono-set key,
///    a list of affected records). Chrome still belongs to the window; this
///    only lays out content and the button row.

// MARK: - Copy model

/// The copy discipline from `ConfirmDialog.prompt.md`, as a value: the title is
/// a question naming the record ("Delete Photographer?", never "Are you
/// sure?"), the message says what is *and is not* lost, and confirm repeats the
/// verb ("Delete field", never "OK"). The cancel label names the safe outcome —
/// "Keep field" reads better than "Cancel" beside a destructive twin.
///
/// `title` and `message` are `String` because they name a record and are
/// formatted through `L10n` at the call site; the two button labels are fixed
/// UI copy.
struct PVConfirmCopy {
    let title: String
    let message: String
    let confirm: LocalizedStringResource
    let cancel: LocalizedStringResource

    init(
        title: String,
        message: String,
        confirm: LocalizedStringResource,
        cancel: LocalizedStringResource
    ) {
        self.title = title
        self.message = message
        self.confirm = confirm
        self.cancel = cancel
    }
}

enum PVConfirmTone {
    /// Actual loss. The system tints the button's title red.
    case danger
    /// Irreversible but non-destructive — merging two people, publishing a tree.
    case irreversible

    var buttonRole: ButtonRole? { self == .danger ? .destructive : nil }

    var accent: Color { self == .danger ? PVColor.danger : PVColor.accent }
}

// MARK: - System alert (preferred)

private struct PVConfirmAlert: ViewModifier {
    @Binding var isPresented: Bool
    let copy: PVConfirmCopy
    let tone: PVConfirmTone
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.alert(copy.title, isPresented: $isPresented) {
            // Order matters: AppKit lays alert buttons out trailing-first, and
            // cancel is made the DEFAULT so Return dismisses safely. A
            // destructive action must never be one reflexive Return away.
            Button(String(localized: copy.cancel), role: .cancel) { isPresented = false }
                .keyboardShortcut(.defaultAction)
            Button(String(localized: copy.confirm), role: tone.buttonRole) {
                isPresented = false
                onConfirm()
            }
        } message: {
            Text(copy.message)
        }
    }
}

extension View {
    /// Native confirmation alert. Escape and Return both cancel; the confirm
    /// button carries the destructive role so the system tints it.
    ///
    /// Prefer this over ``pvConfirmSheet(isPresented:copy:tone:isRunning:onConfirm:detail:)``
    /// unless the consequence genuinely needs formatted content.
    func pvConfirm(
        isPresented: Binding<Bool>,
        copy: PVConfirmCopy,
        tone: PVConfirmTone = .danger,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(PVConfirmAlert(isPresented: isPresented, copy: copy, tone: tone, onConfirm: onConfirm))
    }
}

// MARK: - Sheet, for rich consequence copy

/// Sheet body for a confirmation whose consequence needs more than a string.
///
/// Draws **no** background, corner radius, shadow or scrim — the sheet window
/// owns all four. Margins follow AppKit alert metrics rather than the web
/// component's token padding, which is tuned for an in-page panel.
struct PVConfirmSheetContent<Detail: View>: View {
    let copy: PVConfirmCopy
    let tone: PVConfirmTone
    let isRunning: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let detail: () -> Detail

    @FocusState private var cancelFocused: Bool

    /// Alert-family width. A sheet should not size itself to the parent window.
    private let width: CGFloat = 420

    init(
        copy: PVConfirmCopy,
        tone: PVConfirmTone = .danger,
        isRunning: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.copy = copy
        self.tone = tone
        self.isRunning = isRunning
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            // Alerts are centred; a sheet carrying body copy reads better
            // leading-aligned.
            Text(copy.title)
                .font(PVFont.display(size: PVTypeScale.h3))
                .foregroundStyle(PVColor.textDisplay)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.message)
                .font(PVFont.body(size: PVTypeScale.bodySmall))
                .foregroundStyle(PVColor.textSecondary)
                .lineSpacing((PVLineHeight.relaxed - 1) * PVTypeScale.bodySmall)
                .fixedSize(horizontal: false, vertical: true)

            detail()

            HStack(spacing: PVSpacing.space5) {
                Spacer(minLength: PVSpacing.space8)
                Button(String(localized: copy.cancel)) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isRunning)
                    .focused($cancelFocused)
                Button(String(localized: copy.confirm), role: tone.buttonRole) { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .tint(tone.accent)
                    .disabled(isRunning)
                    .overlay(alignment: .trailing) {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                                .offset(x: 22)
                        }
                    }
            }
            .controlSize(.large)
            .padding(.top, PVSpacing.space3)
        }
        .padding(PVSpacing.space7)
        .frame(width: width, alignment: .leading)
        // Focus starts on cancel, matching the web component and AppKit's own
        // destructive alerts — Return must not complete a destructive action.
        .onAppear { cancelFocused = true }
    }
}

extension View {
    /// Sheet-based confirmation for rich consequence copy. `detail` renders
    /// under the message — a mono-set key, an affected-record list.
    ///
    /// **Deviation from `swift/ProvenenciaConfirm.swift`:** the reference
    /// clears `isPresented` before invoking `onConfirm`, which would close the
    /// sheet the instant a confirm starts — leaving its own `isRunning` spinner
    /// and any failure with nowhere to show. Dismissal is left to the caller's
    /// binding instead, so an async action can stay on screen while it runs and
    /// report an error in `detail` if it fails.
    func pvConfirmSheet<Detail: View>(
        isPresented: Binding<Bool>,
        copy: PVConfirmCopy,
        tone: PVConfirmTone = .danger,
        isRunning: Bool = false,
        onConfirm: @escaping () -> Void,
        @ViewBuilder detail: @escaping () -> Detail
    ) -> some View {
        sheet(isPresented: isPresented) {
            PVConfirmSheetContent(
                copy: copy,
                tone: tone,
                isRunning: isRunning,
                onConfirm: onConfirm,
                onCancel: { isPresented.wrappedValue = false },
                detail: detail
            )
        }
    }
}

/// A released/affected identifier shown under a confirmation's message — the
/// `<code>` slot in `ConfirmDialog`'s own example, and the reason a delete
/// confirmation earns a sheet rather than a plain alert.
struct PVConfirmKeyChip: View {
    let label: LocalizedStringResource
    let value: String

    var body: some View {
        HStack(spacing: PVSpacing.space3) {
            Text(label)
                .pvMicroCaps()
                .foregroundStyle(PVColor.textMuted)
            Text(value)
                .font(PVFont.mono(size: PVTypeScale.micro))
                .foregroundStyle(PVColor.textPrimary)
                .padding(.horizontal, PVSpacing.space3)
                .padding(.vertical, PVSpacing.space1)
                .background(
                    PVColor.surfaceSunken,
                    in: RoundedRectangle(cornerRadius: PVRadius.xs, style: .continuous)
                )
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Confirm — sheet with released key") {
    PVConfirmSheetContent(
        copy: PVConfirmCopy(
            title: "Delete Photographer?",
            message: "No source in this project carries a value for this field, so nothing is lost. The key is released and can be minted again by a later field with the same label.",
            confirm: "Delete field",
            cancel: "Keep field"
        ),
        onConfirm: {},
        onCancel: {}
    ) {
        PVConfirmKeyChip(label: "Key released", value: "photographer")
    }
    .background(PVColor.surfaceCard)
}
