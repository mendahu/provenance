import AppKit
import SwiftUI

/// Repositions the window's standard traffic-light buttons so their
/// vertical center matches `WorkspaceChrome`'s header text baseline —
/// the reverse of the usual "leave system chrome alone, align your own
/// content to it" approach, done because the header row's own text
/// (logo, "Provenencia", "Sources", project identity) all already line
/// up with each other; only the system-placed lights sit off that line.
///
/// AppKit has no SwiftUI-level API for this: it resets each button's
/// frame on every live resize (and window-state changes), so `align(_:)`
/// re-applies on every `NSWindow.didResizeNotification`, not just once.
///
/// This is the one place in the app touching AppKit's current private
/// view hierarchy (`button.superview`, `isFlipped`) rather than a stable
/// public API. `align(_:)` is written to fail safe — if a future macOS
/// release ever changes that shape, the `guard` just skips the button
/// silently and it stays at its system default position, rather than
/// crashing. That also means such a regression wouldn't be *visible*
/// anywhere except the stoplights quietly drifting out of alignment
/// again — worth a manual check after a macOS SDK bump.
enum TrafficLights {
    /// Added to the stoplights' native x position to give them (and,
    /// matched by `WorkspaceSidebar`'s own leading inset, the logo/title
    /// beside them) more room from the window's left edge than the
    /// system default. Lives here, not `WorkspaceChrome`, since this is
    /// the only place that reads it.
    static let horizontalPadding: CGFloat = 8

    /// Distance from the window's top edge to the desired vertical
    /// center of the three buttons — the same line `WorkspaceChrome`
    /// already aligns header text to.
    static let verticalCenterFromTop = WorkspaceChrome.headerHeight / 2 + WorkspaceChrome.verticalNudge

    /// Each button's native x-origin, captured the first time `align(_:)`
    /// sees it — `frame.origin.x` can no longer be trusted as "the system
    /// default" on later calls, since by then we've already shifted it by
    /// `horizontalPadding` ourselves.
    @MainActor
    private static var nativeOriginX: [ObjectIdentifier: [NSWindow.ButtonType: CGFloat]] = [:]

    /// Pure geometry: where a button's `frame.origin.y` must land (in its
    /// superview's own coordinate space, which may or may not be flipped)
    /// so the button's vertical center sits at `targetCenterFromTop`
    /// points below the window's top edge. Pulled out of `align(_:)` so
    /// it's testable without a real `NSWindow`.
    static func verticalOrigin(
        isFlipped: Bool,
        superviewHeight: CGFloat,
        buttonHeight: CGFloat,
        targetCenterFromTop: CGFloat = TrafficLights.verticalCenterFromTop
    ) -> CGFloat {
        isFlipped
            ? targetCenterFromTop - buttonHeight / 2
            : superviewHeight - targetCenterFromTop - buttonHeight / 2
    }

    @MainActor
    static func align(_ window: NSWindow) {
        let windowKey = ObjectIdentifier(window)
        var cache = nativeOriginX[windowKey] ?? [:]
        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(type), let superview = button.superview else {
                continue
            }
            let nativeX = cache[type] ?? button.frame.origin.x
            cache[type] = nativeX

            var frame = button.frame
            frame.origin.x = nativeX + horizontalPadding
            frame.origin.y = verticalOrigin(
                isFlipped: superview.isFlipped,
                superviewHeight: superview.bounds.height,
                buttonHeight: frame.height
            )
            button.frame = frame
        }
        nativeOriginX[windowKey] = cache
    }
}

/// Bridges to the hosting `NSWindow` (this app has no `NSWindowDelegate`
/// or app delegate to hook otherwise) to call `TrafficLights.align` once
/// the view lands in a window, and again on every resize.
private struct TrafficLightAligner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        AligningView()
    }

    func updateNSView(_: NSView, context: Context) {}

    private final class AligningView: NSView {
        private var resizeObserver: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
                self.resizeObserver = nil
            }
            guard let window else { return }
            TrafficLights.align(window)
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { _ in
                TrafficLights.align(window)
            }
        }

        deinit {
            if let resizeObserver {
                NotificationCenter.default.removeObserver(resizeObserver)
            }
        }
    }
}

extension View {
    /// Aligns the hosting window's traffic lights to `WorkspaceChrome`'s
    /// header baseline. Attach once, near the root of the window's
    /// content — the effect is window-wide, not tied to whichever phase
    /// is on screen.
    func pvAlignsTrafficLights() -> some View {
        background(TrafficLightAligner())
    }
}
