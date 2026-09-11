import Foundation
import Testing
@testable import Provenencia

@Suite
@MainActor
struct SourcePageModelTests {
    private let projectDir = "/tmp/source-page.provenencia"
    private let userID = "00000000-0000-7000-8000-000000000001"
    private let sourceID = "src-1"

    private func photoType() -> CatalogSourceType {
        CatalogSourceType(
            id: "t1", key: "photograph", origin: "provenencia", label: "Photograph",
            description: ""
        )
    }

    private func seededGrades() -> [CatalogCredibilityGrade] {
        [
            CatalogCredibilityGrade(id: "g-low", key: "low_trust", origin: "provenencia", label: "Low trust", sortOrder: 1),
            CatalogCredibilityGrade(id: "g-std", key: "standard", origin: "provenencia", label: "Standard", sortOrder: 2),
            CatalogCredibilityGrade(id: "g-high", key: "high_trust", origin: "provenencia", label: "High trust", sortOrder: 3),
        ]
    }

    private func makeStore(
        source: CatalogSource? = nil,
        notes: [CatalogSourceNote] = [],
        artifacts: [CatalogArtifact] = [],
        credibility: CatalogCredibilityAssessment? = nil
    ) -> FakeStore {
        let store = FakeStore()
        let src = source ?? CatalogSource(
            id: sourceID, ref: "SRC-AAAAA", sourceTypeID: "t1",
            title: "Family album", description: "Held by Mary"
        )
        store.sourcesByProject[projectDir] = [src]
        store.sourceTypesByProject[projectDir] = [photoType()]
        store.notesBySource[sourceID] = notes
        store.artifactsBySource[sourceID] = artifacts
        store.credibilityGradesByProject[projectDir] = seededGrades()
        if let credibility {
            store.credibilityBySource[sourceID] = credibility
        }
        return store
    }

    private func makeModel(store: FakeStore) -> SourcePageModel {
        SourcePageModel(
            sourceID: sourceID,
            projectDir: projectDir,
            userID: userID,
            store: store
        )
    }

    @Test func loadPopulatesWorkspaceAndDefaultsCredibilityToStandard() async {
        let model = makeModel(store: makeStore())
        await model.load()
        #expect(model.workspace?.source.ref == "SRC-AAAAA")
        #expect(model.title == "Family album")
        #expect(model.credibilityKey == "standard")
        #expect(model.workspace?.credibility == nil)
        #expect(model.grades.count == 3)
    }

    @Test func saveIdentityUpdatesTitleAndType() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.title = "Revised title"
        model.description = "New desc"
        await model.saveIdentity()
        #expect(model.workspace?.source.title == "Revised title")
        #expect(store.sourcesByProject[projectDir]?.first?.title == "Revised title")
    }

    @Test func emptyTitleSetsValidationError() async {
        let model = makeModel(store: makeStore())
        await model.load()
        model.title = "   "
        await model.saveIdentity()
        #expect(model.titleError != nil)
        #expect(model.workspace?.source.title == "Family album")
    }

    @Test func selectingHighTrustPersistsAssessment() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        await model.selectCredibility(key: "high_trust")
        #expect(model.workspace?.credibility?.gradeKey == "high_trust")
        #expect(store.credibilityBySource[sourceID]?.gradeKey == "high_trust")
    }

    @Test func standardWithEmptyArgumentDoesNotWriteRow() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        await model.selectCredibility(key: "standard")
        #expect(model.workspace?.credibility == nil)
        #expect(store.credibilityBySource[sourceID] == nil)
    }

    @Test func notesCRUD() async throws {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.noteDraft = "First look"
        await model.addNote()
        #expect(model.notes.count == 1)
        #expect(model.noteDraft.isEmpty)

        let noteID = try #require(model.notes.first?.id)
        await model.updateNote(id: noteID, body: "Updated look")
        #expect(model.notes.first?.body == "Updated look")

        await model.deleteNote(id: noteID)
        #expect(model.notes.isEmpty)
    }

    @Test func createFilelessArtifact() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.openAddArtifact()
        model.artifactDraft.label = "Physical copy"
        model.artifactDraft.description = "At the archive"
        await model.createArtifact()
        #expect(model.artifacts.count == 1)
        #expect(model.artifacts.first?.label == "Physical copy")
        #expect(model.artifacts.first?.fileID.isEmpty == true)
        #expect(model.isAddingArtifact == false)
    }

    @Test func createArtifactRequiresLabel() async {
        let model = makeModel(store: makeStore())
        await model.load()
        model.openAddArtifact()
        model.artifactDraft.label = "  "
        await model.createArtifact()
        #expect(model.artifactLabelError != nil)
        #expect(model.artifacts.isEmpty)
    }

    @Test func ingestThenRejectSecondAttach() async throws {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.openAddArtifact()
        model.artifactDraft.label = "Scan"
        await model.createArtifact()
        let artID = try #require(model.artifacts.first?.id)

        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan-\(UUID().uuidString).bin").path
        try Data("bytes".utf8).write(to: URL(fileURLWithPath: path))

        let first = try await store.ingestArtifactFile(
            projectDir: projectDir, userID: userID, artifactID: artID, path: path
        )
        #expect(!first.artifact.fileID.isEmpty)

        // Refresh model artifact state from store.
        await model.load()
        #expect(model.artifacts.first?.fileID.isEmpty == false)

        do {
            _ = try await store.ingestArtifactFile(
                projectDir: projectDir, userID: userID, artifactID: artID, path: path
            )
            Issue.record("expected second ingest to fail")
        } catch let error as CoreInvokeError {
            guard case .coded(_, let code, _, _) = error else {
                Issue.record("unexpected CoreInvokeError")
                return
            }
            #expect(code == "artifacts.file_already_attached")
        }
    }

    @Test func objectURLJoinsRelPath() {
        let url = ProjectFiles.objectURL(
            projectDir: "/tmp/proj.provenencia",
            relPath: "objects/ab/cd/abcd"
        )
        #expect(url.path == "/tmp/proj.provenencia/objects/ab/cd/abcd")
    }
}
