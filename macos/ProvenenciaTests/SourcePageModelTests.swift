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
        credibility: CatalogCredibilityAssessment? = nil,
        metadata: [CatalogMetadataEntry] = [],
        fields: [CatalogMetadataField] = []
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
        store.metadataBySource[sourceID] = metadata
        store.fieldsByProject[projectDir] = fields
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
            sessionDisplayName: "Jake Robins",
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

    @Test func saveTitleUpdatesCommittedTitle() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.beginEditTitle()
        model.titleDraft = "Revised title"
        await model.saveTitle()
        #expect(model.editingTitle == false)
        #expect(model.title == "Revised title")
        #expect(model.workspace?.source.title == "Revised title")
        #expect(store.sourcesByProject[projectDir]?.first?.title == "Revised title")
    }

    @Test func emptyTitleDraftSetsValidationError() async {
        let model = makeModel(store: makeStore())
        await model.load()
        model.beginEditTitle()
        model.titleDraft = "   "
        await model.saveTitle()
        #expect(model.titleError != nil)
        #expect(model.editingTitle == true)
        #expect(model.workspace?.source.title == "Family album")
    }

    @Test func selectCredibilityDraftDoesNotPersistUntilSave() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.selectCredibilityDraft(key: "high_trust")
        #expect(model.credibilityDirty)
        #expect(model.workspace?.credibility == nil)
        #expect(store.credibilityBySource[sourceID] == nil)
        await model.saveCredibility()
        #expect(model.workspace?.credibility?.gradeKey == "high_trust")
        #expect(store.credibilityBySource[sourceID]?.gradeKey == "high_trust")
        #expect(!model.credibilityDirty)
    }

    @Test func standardWithEmptyArgumentDoesNotWriteRow() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.selectCredibilityDraft(key: "standard")
        await model.saveCredibility()
        #expect(model.workspace?.credibility == nil)
        #expect(store.credibilityBySource[sourceID] == nil)
        #expect(!model.hasSavedCredibilityAssessment)
    }

    @Test func cancelCredibilityRestoresDraftFromSaved() async {
        let store = makeStore(credibility: CatalogCredibilityAssessment(
            id: "cred-1",
            sourceID: sourceID,
            gradeID: "g-high",
            gradeKey: "high_trust",
            gradeLabel: "High trust",
            argument: "Film"
        ))
        let model = makeModel(store: store)
        await model.load()
        #expect(model.hasSavedCredibilityAssessment)
        model.selectCredibilityDraft(key: "low_trust")
        model.credibilityArgumentDraft = "changed"
        #expect(model.credibilityDirty)
        model.cancelCredibility()
        #expect(model.credibilityDraftKey == "high_trust")
        #expect(model.credibilityArgumentDraft == "Film")
        #expect(!model.credibilityDirty)
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
        #expect(model.notes.first?.authorDisplayName == "Jake Robins")
        #expect(!(model.notes.first?.createdAt.isEmpty ?? true))
        await model.updateNote(id: noteID, body: "Updated look")
        #expect(model.notes.first?.body == "Updated look")
        #expect(model.notes.first?.authorDisplayName == "Jake Robins")

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

    @Test func thumbnailImageMissingRelPathReturnsNil() {
        #expect(ProjectFiles.thumbnailImage(projectDir: "/tmp/x.provenencia", relPath: "") == nil)
        #expect(
            ProjectFiles.thumbnailImage(
                projectDir: "/tmp/x.provenencia",
                relPath: "objects/no/such/file"
            ) == nil
        )
    }

    @Test func workspaceArtifactsCarryThumbnailRelPath() async {
        let store = makeStore(
            artifacts: [
                CatalogArtifact(
                    id: "a1", ref: "ART-AAAAA", sourceID: sourceID, fileID: "f1",
                    label: "Scan", description: "",
                    file: CatalogFileRef(
                        id: "f1", relPath: "objects/aa/bb/prim",
                        originalFilename: "scan.png", mediaType: "image/png", byteSize: 12
                    ),
                    thumbnailRelPath: "objects/aa/bb/thumb"
                ),
            ]
        )
        let model = makeModel(store: store)
        await model.load()
        #expect(model.artifacts.first?.thumbnailRelPath == "objects/aa/bb/thumb")
    }

    private func authorField() -> CatalogMetadataField {
        CatalogMetadataField(
            id: "f-author", key: "author", origin: "provenencia",
            label: "Author", dataType: "text", description: ""
        )
    }

    private func repositoryField() -> CatalogMetadataField {
        CatalogMetadataField(
            id: "f-repo", key: "repository", origin: "provenencia",
            label: "Repository", dataType: "text", description: ""
        )
    }

    @Test func loadMetadataSuggestionsAndValues() async {
        let author = authorField()
        let repo = repositoryField()
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: author, valueText: "", dateValueID: "",
                    hasValue: false, suggested: true, sortOrder: 0
                ),
                CatalogMetadataEntry(
                    field: repo, valueText: "NRO", dateValueID: "",
                    hasValue: true, suggested: true, sortOrder: 1
                ),
            ],
            fields: [author, repo]
        )
        let model = makeModel(store: store)
        await model.load()
        #expect(model.metadata.count == 2)
        #expect(model.savedMetadata.map(\.field.key) == ["repository"])
        #expect(model.suggestedMetadata.map(\.field.key) == ["author"])
    }

    @Test func saveMetadataValueFillsSuggestion() async {
        let author = authorField()
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: author, valueText: "", dateValueID: "",
                    hasValue: false, suggested: true, sortOrder: 0
                ),
            ],
            fields: [author]
        )
        let model = makeModel(store: store)
        await model.load()
        #expect(model.suggestedMetadata.count == 1)
        model.metadataDrafts[author.id] = "Mary Robins"
        await model.saveMetadataValue(fieldID: author.id)
        #expect(model.savedMetadata.map(\.valueText) == ["Mary Robins"])
        #expect(model.suggestedMetadata.isEmpty)
    }

    @Test func beginEditMetadataThenCancelRestoresDraft() async {
        let repo = repositoryField()
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: repo, valueText: "NRO", dateValueID: "",
                    hasValue: true, suggested: false, sortOrder: 0
                ),
            ],
            fields: [repo]
        )
        let model = makeModel(store: store)
        await model.load()
        model.beginEditMetadata(fieldID: repo.id)
        #expect(model.editingMetadataFieldID == repo.id)
        model.metadataDrafts[repo.id] = "Changed"
        model.cancelEditMetadata()
        #expect(model.editingMetadataFieldID == nil)
        #expect(model.metadataDrafts[repo.id] == "NRO")
    }

    @Test func saveMetadataValueExitsEditMode() async {
        let repo = repositoryField()
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: repo, valueText: "NRO", dateValueID: "",
                    hasValue: true, suggested: false, sortOrder: 0
                ),
            ],
            fields: [repo]
        )
        let model = makeModel(store: store)
        await model.load()
        model.beginEditMetadata(fieldID: repo.id)
        model.metadataDrafts[repo.id] = "Norfolk Record Office"
        await model.saveMetadataValue(fieldID: repo.id)
        #expect(model.editingMetadataFieldID == nil)
        #expect(model.savedMetadata.map(\.valueText) == ["Norfolk Record Office"])
    }

    @Test func dismissSuggestionRemovesEmptyRow() async {
        let author = authorField()
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: author, valueText: "", dateValueID: "",
                    hasValue: false, suggested: true, sortOrder: 0
                ),
            ],
            fields: [author]
        )
        let model = makeModel(store: store)
        await model.load()
        await model.dismissMetadataSuggestion(fieldID: author.id)
        #expect(model.metadata.isEmpty)
        #expect(model.suggestedMetadata.isEmpty)
    }

    @Test func reorderSavedMetadataLeavesSuggestions() async {
        let author = authorField()
        let repo = repositoryField()
        let issue = CatalogMetadataField(
            id: "f-issue", key: "issue", origin: "provenencia",
            label: "Issue", dataType: "text", description: ""
        )
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: author, valueText: "A", dateValueID: "",
                    hasValue: true, suggested: true, sortOrder: 0
                ),
                CatalogMetadataEntry(
                    field: issue, valueText: "", dateValueID: "",
                    hasValue: false, suggested: true, sortOrder: 1
                ),
                CatalogMetadataEntry(
                    field: repo, valueText: "B", dateValueID: "",
                    hasValue: true, suggested: true, sortOrder: 2
                ),
            ],
            fields: [author, repo, issue]
        )
        let model = makeModel(store: store)
        await model.load()
        await model.moveSavedMetadata(from: IndexSet(integer: 0), to: 2)
        #expect(model.savedMetadata.map(\.field.id) == [repo.id, author.id])
        #expect(model.suggestedMetadata.map(\.field.id) == [issue.id])
        #expect(model.metadata.map(\.field.id) == [repo.id, author.id, issue.id])
    }

    @Test func addMetadataFromDialog() async {
        let author = authorField()
        let store = makeStore(fields: [author])
        let model = makeModel(store: store)
        await model.load()
        model.openAddMetadata()
        model.addMetadataFieldID = author.id
        model.addMetadataValue = "Eliza"
        await model.createMetadataFromAdd()
        #expect(model.isAddingMetadata == false)
        #expect(model.metadata.contains { $0.field.id == author.id && $0.valueText == "Eliza" })
    }

    @Test func cancelArtifactFieldsRestoresDrafts() async throws {
        let store = makeStore(
            artifacts: [
                CatalogArtifact(
                    id: "a1", ref: "ART-AAAAA", sourceID: sourceID, fileID: "",
                    label: "Front", description: "Original", file: nil
                ),
            ]
        )
        let model = makeModel(store: store)
        await model.load()
        let artID = try #require(model.artifacts.first?.id)
        model.artifactLabels[artID] = "Changed"
        model.artifactDescriptions[artID] = "Changed desc"
        #expect(model.artifactFieldsDirty(artID))
        model.cancelArtifactFields(id: artID)
        #expect(!model.artifactFieldsDirty(artID))
        #expect(model.artifactLabels[artID] == "Front")
        #expect(model.artifactDescriptions[artID] == "Original")
    }

    @Test func saveDateEditorStructuresMetadata() async {
        let dateField = CatalogMetadataField(
            id: "f-date", key: "date_of_record", origin: "provenencia",
            label: "Date of record", dataType: "date", description: ""
        )
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: dateField, valueText: "about the year 1890", dateValueID: "",
                    hasValue: true, suggested: false, sortOrder: 0
                ),
            ],
            fields: [dateField]
        )
        let model = makeModel(store: store)
        await model.load()
        model.metadataDrafts[dateField.id] = "about the year 1890"
        model.openStructureDate(fieldID: dateField.id)
        model.dateEditorDraft.qualifier = "ABT"
        model.dateEditorDraft.startYear = 1890
        await model.saveDateEditor()
        #expect(model.isEditingDate == false)
        let entry = model.metadata.first { $0.field.id == dateField.id }
        #expect(entry?.dateValueID.isEmpty == false)
        #expect(entry?.dateSummary == "ABT 1890")
        #expect(model.dateDraftsByFieldID[dateField.id] != nil)
    }

    @Test func expandingArtifactCollapsesOther() async {
        let store = makeStore(
            artifacts: [
                CatalogArtifact(
                    id: "a1", ref: "ART-AAAAA", sourceID: sourceID, fileID: "",
                    label: "Front", description: "", file: nil
                ),
                CatalogArtifact(
                    id: "a2", ref: "ART-BBBBB", sourceID: sourceID, fileID: "",
                    label: "Back", description: "", file: nil
                ),
            ]
        )
        let model = makeModel(store: store)
        await model.load()
        model.toggleArtifactExpanded("a1")
        #expect(model.expandedArtifactIDs == ["a1"])
        model.toggleArtifactExpanded("a2")
        #expect(model.expandedArtifactIDs == ["a2"])
        model.toggleArtifactExpanded("a2")
        #expect(model.expandedArtifactIDs.isEmpty)
    }
}
