import AppKit
import CoreGraphics

/// Preferred window opening size, clamped to the main screen's usable
/// area so a large default still fits on smaller displays.
enum WindowSizing {
    /// Ideal first-open size: workspace default, or the visible frame if
    /// that default would hang off-screen. Hard resize floor remains
    /// `PVSpacing.widthWindowMin` / `heightWindowMin` on the content.
    static var fittedDefaultSize: CGSize {
        let preferred = CGSize(
            width: PVSpacing.widthWorkspaceDefault,
            height: PVSpacing.heightWorkspaceDefault
        )
        guard let visible = NSScreen.main?.visibleFrame.size else {
            return preferred
        }
        return CGSize(
            width: min(preferred.width, visible.width),
            height: min(preferred.height, visible.height)
        )
    }
}
