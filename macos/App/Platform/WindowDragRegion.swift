@preconcurrency import AppKit
import SwiftUI

/// Transparent AppKit overlay that turns mouse-downs into window moves.
///
/// With `.windowStyle(.hiddenTitleBar)`, AppKit still only treats roughly
/// the system title-bar strip as a drag region. Our workspace header is
/// taller (`WorkspaceChrome.headerHeight`), so clicks in the lower part
/// of that visual row would otherwise do nothing. `WindowDragGesture` is
/// macOS 15+; this is the macOS 14-compatible escape hatch.
///
/// Intended for chrome that has no interactive controls of its own —
/// sit it as an overlay on the full header row so the hit box matches
/// what the user sees. Traffic lights stay clickable because they live
/// in the window's chrome layer above the content view.
private struct WindowDragRegion: NSViewRepresentable {
    @MainActor
    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    @MainActor
    func updateNSView(_: NSView, context: Context) {}

    @MainActor
    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func accessibilityIsIgnored() -> Bool { true }
    }
}

extension View {
    /// Makes the view's full bounds a window-drag surface (see
    /// `WindowDragRegion`). Attach to header chrome whose visual height
    /// exceeds the system title-bar drag strip.
    func pvWindowDragRegion() -> some View {
        overlay {
            WindowDragRegion()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }
}
