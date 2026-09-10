import SwiftUI

/// The post-onboarding application shell: one leading sidebar plus one
/// content host (W-1). Replaces `OnboardingHomeView` as the permanent
/// chrome once a project is open (`OnboardingModel.phase == .home`) — see
/// `docs/deployment-plan/spike-2/design/S2-01-workspace-chrome.md`.
///
/// `projectDir` and `userID` are non-optional: `OnboardingView` only
/// mounts this from `.home(projectDir:userID:)`, which is set solely via
/// `OnboardingModel.enterHome`.
struct WorkspaceView: View {
    var model: OnboardingModel
    let projectDir: String
    let userID: String
    @State private var workspace: WorkspaceModel
    @State private var catalogCounts: CatalogCounts
    @Environment(SignOutCoordinator.self) private var signOutCoordinator

    init(model: OnboardingModel, projectDir: String, userID: String) {
        self.model = model
        self.projectDir = projectDir
        self.userID = userID
        _workspace = State(initialValue: WorkspaceModel())
        _catalogCounts = State(initialValue: CatalogCounts(projectDir: projectDir, store: model.store))
    }

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceSidebar(session: model.session, workspace: workspace, catalogCounts: catalogCounts)
            WorkspaceContent(
                section: workspace.selectedSection,
                project: model.project,
                projectDir: projectDir,
                userID: userID,
                store: model.store,
                catalogCounts: catalogCounts
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(catalogCounts)
        .task {
            await catalogCounts.refreshAll()
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
    let model = WorkspaceView.previewModel()
    let projectDir = model.activeProjectDir ?? ""
    WorkspaceView(
        model: model,
        projectDir: projectDir,
        userID: PreviewFixture.identity.userID
    )
    .environment(SignOutCoordinator())
    .frame(width: PVSpacing.widthWorkspaceMin, height: PVSpacing.heightWorkspaceMin)
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
        model.phase = .home(projectDir: projectDir, userID: PreviewFixture.identity.userID)
        return model
    }
}
#endif
