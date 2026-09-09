import SwiftUI

extension View {
    /// Applies an `.accessibilityIdentifier` only when the call site supplied
    /// one — design-system components do not invent their own
    /// (`docs/macos-client-patterns.md` §5). Shared by `PVTable` and
    /// `PVComboBox`, both of which take an optional identifier (or prefix)
    /// from the feature that mounts them.
    func pvAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(PVOptionalAccessibilityIdentifier(identifier))
    }
}

private struct PVOptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    init(_ identifier: String?) {
        self.identifier = identifier
    }

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
