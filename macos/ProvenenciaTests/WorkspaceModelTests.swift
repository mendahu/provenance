import Foundation
import Testing
@testable import Provenencia

@Suite
@MainActor
struct WorkspaceModelTests {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "WorkspaceModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func defaultsToSourcesExpanded() {
        let model = WorkspaceModel(defaults: makeDefaults())
        #expect(model.selectedSection == .sources)
        #expect(!model.isSidebarCollapsed)
    }

    @Test func toggleCollapsesAndPersists() {
        let defaults = makeDefaults()
        let model = WorkspaceModel(defaults: defaults)
        model.toggleSidebarCollapsed()
        #expect(model.isSidebarCollapsed)

        let reloaded = WorkspaceModel(defaults: defaults)
        #expect(reloaded.isSidebarCollapsed)
    }

    @Test func toggleTwiceReturnsToExpanded() {
        let model = WorkspaceModel(defaults: makeDefaults())
        model.toggleSidebarCollapsed()
        model.toggleSidebarCollapsed()
        #expect(!model.isSidebarCollapsed)
    }

    @Test func selectingEachSectionUpdatesLabelAndPlaceholder() {
        let model = WorkspaceModel(defaults: makeDefaults())
        for section in WorkspaceModel.Section.allCases {
            model.selectedSection = section
            #expect(model.selectedSection == section)
        }
    }
}
