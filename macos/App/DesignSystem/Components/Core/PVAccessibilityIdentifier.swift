import SwiftUI

extension View {
    /// Applies an `.accessibilityIdentifier` only when the call site supplied
    /// one — design-system components do not invent their own
    /// (`docs/macos-client-patterns.md` §5). Shared by `PVTable` and
    /// `PVComboBox`, both of which take an optional identifier (or prefix)
    /// from the feature that mounts them.
    ///
    /// An empty identifier is what every view has anyway, so `nil` maps to
    /// `""` rather than branching — a conditional here would flip the view's
    /// structural identity whenever an identifier appears or disappears.
    func pvAccessibilityIdentifier(_ identifier: String?) -> some View {
        accessibilityIdentifier(identifier ?? "")
    }
}
