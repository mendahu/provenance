import SwiftUI

/// The post-onboarding application shell: one leading sidebar plus one
/// content host (W-1). Replaces `OnboardingHomeView` as the permanent
/// chrome once a project is open (`OnboardingModel.phase == .home`) — see
/// `docs/deployment-plan/spike-2/design/S2-01-workspace-chrome.md`.
struct WorkspaceView: View {
    var model: OnboardingModel
    @State private var workspace = WorkspaceModel()
    @Environment(SignOutCoordinator.self) private var signOutCoordinator

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceSidebar(session: model.session, workspace: workspace)
            WorkspaceContent(section: workspace.selectedSection, project: model.project)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            signOutCoordinator.isAvailable = true
            signOutCoordinator.action = { [model] in
                Task { await model.signOut() }
            }
        }
        .onDisappear {
            signOutCoordinator.isAvailable = false
        }
        .accessibilityIdentifier("workspace")
    }
}

#if DEBUG
#Preview("Expanded, Sources") {
    WorkspaceView(model: WorkspaceView.previewModel())
        .environment(SignOutCoordinator())
        .frame(width: 1200, height: 780)
}

extension WorkspaceView {
    static func previewModel() -> OnboardingModel {
        let model = OnboardingModel(store: FakeStore(identity: PreviewFixture.identity), folders: .previewEmpty())
        model.session = PreviewFixture.identity
        model.project = PreviewFixture.project
        model.phase = .home
        return model
    }
}
#endif
