import SwiftUI

@main
struct ProvenenciaApp: App {
    // Owned here (not inside the view hierarchy) because `.commands` builds
    // the app menu at the Scene level, outside the views that hold
    // `OnboardingModel` — see `SignOutCoordinator`.
    @State private var signOutCoordinator = SignOutCoordinator()

    init() {
        PVFontRegistration.registerBundledFontsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .environment(signOutCoordinator)
                // `.hiddenTitleBar` alone still reserves the title bar's
                // height as a top safe area, leaving a blank strip above
                // our content instead of letting the stoplights float over
                // it — ignore that inset so our own header row is the one
                // row the stoplights sit in front of (S2-01 Frame 7).
                .ignoresSafeArea(.container, edges: .top)
                .pvAlignsTrafficLights()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(L10n.Onboarding.signOut) {
                    signOutCoordinator.signOut()
                }
                .disabled(!signOutCoordinator.isAvailable)
            }
        }
    }
}
