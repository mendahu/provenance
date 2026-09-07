import SwiftUI

/// Shared interaction chrome for `ButtonStyle` bodies: hover tracking,
/// disabled opacity, reduce-motion-aware press scale, and the animations
/// tying them together — plus, critically, the `contentShape(Rectangle())`
/// that makes hover and click agree on the same hit-testing surface.
///
/// `PVButtonBody`, `PVIconButtonBody`, and `PVSidebarNavRowBody`
/// (`PVSidebarNav.swift`) each used to re-derive this independently; one
/// of them (the sidebar row) briefly drifted from the others and needed
/// two different `contentShape`s for two different pointer interactions
/// before landing here. Centralizing it means a future button-style body
/// gets correct, consistent hover/click/press behavior by construction,
/// not by remembering every piece.
///
/// The caller supplies only what actually varies between components: the
/// content itself, built from an already-combined `isHovering &&
/// isEnabled` flag (so callers never have to re-check `isEnabled`
/// themselves for hover purposes).
struct PVHoverEffect<Content: View>: View {
    let isPressed: Bool
    /// Defaults to the fast, snappy timing new call sites should use.
    /// `PVButtonBody` passes `PVMotion.fastStandard` to keep its existing,
    /// already-shipped feel unchanged by this refactor.
    var hoverAnimation: Animation = PVMotion.instantStandard
    @ViewBuilder var content: (_ showHover: Bool) -> Content

    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content(isHovering && isEnabled)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(isPressed && !reduceMotion ? PVMotion.pressScale : 1)
            .pvAnimation(hoverAnimation, value: isHovering)
            .pvAnimation(PVMotion.instantStandard, value: isPressed)
            .onHover { isHovering = $0 }
    }
}
