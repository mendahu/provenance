import SwiftUI

/// The post-onboarding application shell: one leading sidebar plus one
/// content host (W-1). Replaces `OnboardingHomeView` as the permanent
/// chrome once a project is open (`OnboardingModel.phase == .home`) — see
/// `docs/deployment-plan/spike-2/design/S2-01-workspace-chrome.md`.
struct WorkspaceView: View {
    var model: OnboardingModel
    @State private var workspace: WorkspaceModel
    @Environment(SignOutCoordinator.self) private var signOutCoordinator

    init(model: OnboardingModel) {
        self.model = model
        // `model.activeProjectDir` is always set by the time `.home` is
        // reached (see `OnboardingModel.load()`/`applyOpened(_:)`) — the
        // empty-string fallback only guards a state that shouldn't occur.
        _workspace = State(initialValue: WorkspaceModel(projectDir: model.activeProjectDir ?? "", store: model.store))
    }

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceSidebar(session: model.session, workspace: workspace)
            WorkspaceContent(section: workspace.selectedSection, project: model.project)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await workspace.refreshCounts()
        }
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
        let store = FakeStore(identity: PreviewFixture.identity)
        let projectDir = store.lastResult.projectDir
        store.sourcesByProject[projectDir] = (1 ... 12).map {
            CatalogSource(id: "\($0)", ref: "SRC-FAKE\($0)", sourceTypeID: "", title: "Source \($0)", description: "")
        }
        store.sourceTypesByProject[projectDir] = [
            CatalogSourceType(id: "1", key: "photograph", origin: "provenencia", label: "Photograph", description: ""),
            CatalogSourceType(id: "2", key: "book", origin: "provenencia", label: "Book", description: ""),
        ]
        store.fieldsByProject[projectDir] = [
            CatalogMetadataField(id: "1", key: "date_taken", origin: "provenencia", label: "Date taken", dataType: "date", description: ""),
        ]
        store.fileCountByProject[projectDir] = 8

        let model = OnboardingModel(store: store, folders: .previewEmpty())
        model.session = PreviewFixture.identity
        model.project = PreviewFixture.project
        model.activeProjectDir = projectDir
        model.phase = .home
        return model
    }
}
#endif
