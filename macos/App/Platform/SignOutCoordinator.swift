import Observation

/// Bridges the workspace's open session to the macOS app menu's **Sign
/// Out** command. `ProvenenciaApp.commands` builds the app's menu bar at
/// the `Scene` level, outside the view hierarchy that owns
/// `OnboardingModel`, so it can't call `model.signOut()` directly — the
/// active `WorkspaceView` publishes its sign-out action here instead.
///
/// Sign Out lives in the app menu only (W-11): window chrome must never
/// duplicate it as a button or link.
///
/// Deliberately shaped for one open session in one window — a single
/// `action`/`isAvailable` pair, owned once by `ProvenenciaApp` — matching
/// the app's current `.windowResizability(.contentSize)` single-window
/// scope. If a future spike adds multiple project windows, this needs to
/// become per-window state rather than one shared coordinator.
@MainActor
@Observable
final class SignOutCoordinator {
    /// Whether a session is open, i.e. whether the menu item should be enabled.
    var isAvailable = false
    var action: () -> Void = {}

    func signOut() {
        action()
    }
}
