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

    private func makeModel(
        store: any GenealogyStore = FakeStore(),
        projectDir: String = "/tmp/test.provenencia",
        defaults: UserDefaults? = nil
    ) -> WorkspaceModel {
        WorkspaceModel(projectDir: projectDir, store: store, defaults: defaults ?? makeDefaults())
    }

    @Test func defaultsToSourcesExpanded() {
        let model = makeModel()
        #expect(model.selectedSection == .sources)
        #expect(!model.isSidebarCollapsed)
    }

    @Test func toggleCollapsesAndPersists() {
        let defaults = makeDefaults()
        let model = makeModel(defaults: defaults)
        model.toggleSidebarCollapsed()
        #expect(model.isSidebarCollapsed)

        let reloaded = makeModel(defaults: defaults)
        #expect(reloaded.isSidebarCollapsed)
    }

    @Test func toggleTwiceReturnsToExpanded() {
        let model = makeModel()
        model.toggleSidebarCollapsed()
        model.toggleSidebarCollapsed()
        #expect(!model.isSidebarCollapsed)
    }

    @Test func selectingEachSectionUpdatesLabelAndPlaceholder() {
        let model = makeModel()
        for section in WorkspaceModel.Section.allCases {
            model.selectedSection = section
            #expect(model.selectedSection == section)
        }
    }

    @Test func refreshCountsPopulatesEveryDestination() async {
        let store = FakeStore()
        let projectDir = "/tmp/counts.provenencia"
        store.sourcesByProject[projectDir] = [
            CatalogSource(id: "1", ref: "SRC-1", sourceTypeID: "", title: "A", description: ""),
            CatalogSource(id: "2", ref: "SRC-2", sourceTypeID: "", title: "B", description: ""),
        ]
        store.sourceTypesByProject[projectDir] = [
            CatalogSourceType(id: "1", key: "photograph", origin: "provenencia", label: "Photograph", description: ""),
        ]
        store.fieldsByProject[projectDir] = [
            CatalogMetadataField(id: "1", key: "date_taken", origin: "provenencia", label: "Date taken", dataType: "date", description: ""),
            CatalogMetadataField(id: "2", key: "notes", origin: "provenencia", label: "Notes", dataType: "text", description: ""),
        ]
        store.fileCountByProject[projectDir] = 4

        let model = makeModel(store: store, projectDir: projectDir)
        await model.refreshCounts()

        #expect(model.counts[.sources] == 2)
        #expect(model.counts[.sourceTypes] == 1)
        #expect(model.counts[.sourceFields] == 2)
        #expect(model.counts[.files] == 4)
    }

    @Test func refreshCountsOnEmptyProjectYieldsZero() async {
        let model = makeModel()
        await model.refreshCounts()
        let sourcesCount = model.counts[.sources]
        let typesCount = model.counts[.sourceTypes]
        let fieldsCount = model.counts[.sourceFields]
        let filesCount = model.counts[.files]
        #expect(sourcesCount == 0)
        #expect(typesCount == 0)
        #expect(fieldsCount == 0)
        #expect(filesCount == 0)
    }
}
