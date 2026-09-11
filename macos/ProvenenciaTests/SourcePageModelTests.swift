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
        #expect(model.identity.title == "Family album")
        #expect(model.credibility.savedKey == "standard")
        #expect(model.workspace?.credibility == nil)
        #expect(model.credibility.grades.count == 3)
    }

    @Test func saveTitleUpdatesCommittedTitle() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.identity.beginEditTitle()
        model.identity.titleDraft = "Revised title"
        await model.identity.saveTitle()
        #expect(model.identity.editingTitle == false)
        #expect(model.identity.title == "Revised title")
        #expect(model.workspace?.source.title == "Revised title")
        #expect(store.sourcesByProject[projectDir]?.first?.title == "Revised title")
    }

    @Test func emptyTitleDraftSetsValidationError() async {
        let model = makeModel(store: makeStore())
        await model.load()
        model.identity.beginEditTitle()
        model.identity.titleDraft = "   "
        await model.identity.saveTitle()
        #expect(model.identity.titleError != nil)
        #expect(model.identity.editingTitle == true)
        #expect(model.workspace?.source.title == "Family album")
    }

    @Test func selectCredibilityDraftDoesNotPersistUntilSave() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.credibility.selectDraft(key: "high_trust")
        #expect(model.credibility.isDirty)
        #expect(model.workspace?.credibility == nil)
        #expect(store.credibilityBySource[sourceID] == nil)
        await model.credibility.save()
        #expect(model.workspace?.credibility?.gradeKey == "high_trust")
        #expect(store.credibilityBySource[sourceID]?.gradeKey == "high_trust")
        #expect(!model.credibility.isDirty)
    }

    @Test func standardWithEmptyArgumentDoesNotWriteRow() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.credibility.selectDraft(key: "standard")
        await model.credibility.save()
        #expect(model.workspace?.credibility == nil)
        #expect(store.credibilityBySource[sourceID] == nil)
        #expect(!model.credibility.hasSavedAssessment)
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
        #expect(model.credibility.hasSavedAssessment)
        model.credibility.selectDraft(key: "low_trust")
        model.credibility.argumentDraft = "changed"
        #expect(model.credibility.isDirty)
        model.credibility.cancel()
        #expect(model.credibility.draftKey == "high_trust")
        #expect(model.credibility.argumentDraft == "Film")
        #expect(!model.credibility.isDirty)
    }

    @Test func notesCRUD() async throws {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.notes.draft = "First look"
        await model.notes.add()
        #expect(model.notes.items.count == 1)
        #expect(model.notes.draft.isEmpty)

        let noteID = try #require(model.notes.items.first?.id)
        #expect(model.notes.items.first?.authorDisplayName == "Jake Robins")
        #expect(!(model.notes.items.first?.createdAt.isEmpty ?? true))

        model.notes.beginEdit(id: noteID)
        #expect(model.notes.editingNoteID == noteID)
        #expect(model.notes.bodyDraft == "First look")
        model.notes.bodyDraft = "Updated look"
        await model.notes.saveEdit()
        #expect(model.notes.editingNoteID == nil)
        #expect(model.notes.items.first?.body == "Updated look")
        #expect(model.notes.items.first?.authorDisplayName == "Jake Robins")

        await model.notes.delete(id: noteID)
        #expect(model.notes.items.isEmpty)
    }

    @Test func cancelNoteEditRestoresCommittedBody() async throws {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.notes.draft = "Original"
        await model.notes.add()
        let noteID = try #require(model.notes.items.first?.id)

        model.notes.beginEdit(id: noteID)
        model.notes.bodyDraft = "Changed"
        model.notes.cancelEdit()
        #expect(model.notes.editingNoteID == nil)
        #expect(model.notes.items.first?.body == "Original")
    }

    @Test func emptyNoteBodyDraftSetsValidationError() async throws {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.notes.draft = "Keep me"
        await model.notes.add()
        let noteID = try #require(model.notes.items.first?.id)

        model.notes.beginEdit(id: noteID)
        model.notes.bodyDraft = "   "
        await model.notes.saveEdit()
        #expect(model.notes.bodyError != nil)
        #expect(model.notes.editingNoteID == noteID)
        #expect(model.notes.items.first?.body == "Keep me")
    }

    @Test func createFilelessArtifact() async {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.artifacts.openAdd()
        model.artifacts.draft.label = "Physical copy"
        model.artifacts.draft.description = "At the archive"
        await model.artifacts.create()
        #expect(model.artifacts.items.count == 1)
        #expect(model.artifacts.items.first?.label == "Physical copy")
        #expect(model.artifacts.items.first?.fileID.isEmpty == true)
        #expect(model.artifacts.isAdding == false)
    }

    @Test func createArtifactRequiresLabel() async {
        let model = makeModel(store: makeStore())
        await model.load()
        model.artifacts.openAdd()
        model.artifacts.draft.label = "  "
        await model.artifacts.create()
        #expect(model.artifacts.draftLabelError != nil)
        #expect(model.artifacts.items.isEmpty)
    }

    @Test func ingestThenRejectSecondAttach() async throws {
        let store = makeStore()
        let model = makeModel(store: store)
        await model.load()
        model.artifacts.openAdd()
        model.artifacts.draft.label = "Scan"
        await model.artifacts.create()
        let artID = try #require(model.artifacts.items.first?.id)

        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan-\(UUID().uuidString).bin").path
        try Data("bytes".utf8).write(to: URL(fileURLWithPath: path))

        let first = try await store.ingestArtifactFile(
            projectDir: projectDir, userID: userID, artifactID: artID, path: path
        )
        #expect(!first.artifact.fileID.isEmpty)

        // Refresh model artifact state from store.
        await model.load()
        #expect(model.artifacts.items.first?.fileID.isEmpty == false)

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
        #expect(model.artifacts.items.first?.thumbnailRelPath == "objects/aa/bb/thumb")
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
        #expect(model.metadata.entries.count == 2)
        #expect(model.metadata.saved.map(\.field.key) == ["repository"])
        #expect(model.metadata.suggested.map(\.field.key) == ["author"])
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
        #expect(model.metadata.suggested.count == 1)
        model.metadata.drafts[author.id] = "Mary Robins"
        await model.metadata.save(fieldID: author.id)
        #expect(model.metadata.saved.map(\.valueText) == ["Mary Robins"])
        #expect(model.metadata.suggested.isEmpty)
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
        model.metadata.beginEdit(fieldID: repo.id)
        #expect(model.metadata.editingFieldID == repo.id)
        model.metadata.drafts[repo.id] = "Changed"
        model.metadata.cancelEdit()
        #expect(model.metadata.editingFieldID == nil)
        #expect(model.metadata.drafts[repo.id] == "NRO")
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
        model.metadata.beginEdit(fieldID: repo.id)
        model.metadata.drafts[repo.id] = "Norfolk Record Office"
        await model.metadata.save(fieldID: repo.id)
        #expect(model.metadata.editingFieldID == nil)
        #expect(model.metadata.saved.map(\.valueText) == ["Norfolk Record Office"])
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
        await model.metadata.dismissSuggestion(fieldID: author.id)
        #expect(model.metadata.entries.isEmpty)
        #expect(model.metadata.suggested.isEmpty)
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
        await model.metadata.moveSaved(from: IndexSet(integer: 0), to: 2)
        #expect(model.metadata.saved.map(\.field.id) == [repo.id, author.id])
        #expect(model.metadata.suggested.map(\.field.id) == [issue.id])
        #expect(model.metadata.entries.map(\.field.id) == [repo.id, author.id, issue.id])
    }

    @Test func addMetadataFromDialog() async {
        let author = authorField()
        let store = makeStore(fields: [author])
        let model = makeModel(store: store)
        await model.load()
        model.metadata.openAdd()
        model.metadata.addFieldID = author.id
        model.metadata.addValue = "Eliza"
        await model.metadata.createFromAdd()
        #expect(model.metadata.isAdding == false)
        #expect(model.metadata.entries.contains { $0.field.id == author.id && $0.valueText == "Eliza" })
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
        let artID = try #require(model.artifacts.items.first?.id)
        model.artifacts.labels[artID] = "Changed"
        model.artifacts.descriptions[artID] = "Changed desc"
        #expect(model.artifacts.fieldsDirty(artID))
        model.artifacts.cancelFields(id: artID)
        #expect(!model.artifacts.fieldsDirty(artID))
        #expect(model.artifacts.labels[artID] == "Front")
        #expect(model.artifacts.descriptions[artID] == "Original")
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
        model.metadata.drafts[dateField.id] = "about the year 1890"
        model.metadata.openStructureDate(fieldID: dateField.id)
        model.metadata.dateEditorDraft.qualifier = "ABT"
        model.metadata.dateEditorDraft.startYear = 1890
        await model.metadata.saveDateEditor()
        #expect(model.metadata.isEditingDate == false)
        let entry = model.metadata.entries.first { $0.field.id == dateField.id }
        #expect(entry?.dateValueID.isEmpty == false)
        #expect(entry?.dateSummary == "ABT 1890")
        #expect(entry?.date?.qualifier == "ABT")
        #expect(entry?.date?.startYear == 1890)
    }

    @Test func reopenDateEditorRebuildsDraftFromCatalog() async {
        let dateField = CatalogMetadataField(
            id: "f-date", key: "date_of_record", origin: "provenencia",
            label: "Date of record", dataType: "date", description: ""
        )
        let store = makeStore(
            metadata: [
                CatalogMetadataEntry(
                    field: dateField, valueText: "spring 1890", dateValueID: "",
                    hasValue: true, suggested: false, sortOrder: 0
                ),
            ],
            fields: [dateField]
        )
        let model = makeModel(store: store)
        await model.load()
        model.metadata.drafts[dateField.id] = "spring 1890"
        model.metadata.openStructureDate(fieldID: dateField.id)
        model.metadata.dateEditorDraft.setKind("range")
        model.metadata.dateEditorDraft.startYear = 1890
        model.metadata.dateEditorDraft.startMonth = 3
        model.metadata.dateEditorDraft.endYear = 1890
        model.metadata.dateEditorDraft.endMonth = 6
        await model.metadata.saveDateEditor()
        #expect(model.metadata.isEditingDate == false)

        // A fresh model on the same store (new session — no in-memory cache)
        // must rebuild the saved draft from the workspace entry.
        let reopened = makeModel(store: store)
        await reopened.load()
        reopened.metadata.openEditDate(fieldID: dateField.id)
        #expect(reopened.metadata.dateEditorDraft.kind == "range")
        #expect(reopened.metadata.dateEditorDraft.startYear == 1890)
        #expect(reopened.metadata.dateEditorDraft.startMonth == 3)
        #expect(reopened.metadata.dateEditorDraft.endYear == 1890)
        #expect(reopened.metadata.dateEditorDraft.endMonth == 6)
        #expect(reopened.metadata.dateEditorDraft.summary == "BET Mar 1890 AND Jun 1890")
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
        model.artifacts.toggleExpanded("a1")
        #expect(model.artifacts.expandedIDs == ["a1"])
        model.artifacts.toggleExpanded("a2")
        #expect(model.artifacts.expandedIDs == ["a2"])
        model.artifacts.toggleExpanded("a2")
        #expect(model.artifacts.expandedIDs.isEmpty)
    }
}
