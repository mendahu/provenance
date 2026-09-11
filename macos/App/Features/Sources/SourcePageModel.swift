import Foundation
import Observation

/// State for the individual Source page (S2-18): load workspace, edit identity,
/// credibility, Notes, and Artifacts (accordion + first-attach ingest).
@MainActor
@Observable
final class SourcePageModel {
    struct ArtifactDraft: Equatable {
        var label = ""
        var description = ""
        var filePath: String?
        var fileName: String?
    }

    private(set) var workspace: CatalogSourceWorkspace?
    private(set) var grades: [CatalogCredibilityGrade] = []
    private(set) var types: [CatalogSourceType] = []
    private(set) var isLoading = false
    var loadError: Error?

    var title = ""
    var description = ""
    var sourceTypeID = ""
    var titleError: String?
    private(set) var isSavingIdentity = false

    /// Displayed grade key; defaults to `standard` when no assessment row.
    var credibilityKey = "standard"
    var credibilityArgument = ""
    private(set) var isSavingCredibility = false

    var noteDraft = ""
    private(set) var isSavingNote = false

    var expandedArtifactIDs: Set<String> = []
    /// Local edit buffers for expanded artifact identity fields, keyed by id.
    var artifactLabels: [String: String] = [:]
    var artifactDescriptions: [String: String] = [:]

    var isAddingArtifact = false
    var artifactDraft = ArtifactDraft()
    var artifactLabelError: String?
    private(set) var isSavingArtifact = false
    /// Artifact id currently saving label/description from the accordion.
    private(set) var savingArtifactID: String?
    /// Per-artifact validation for expanded edit fields.
    var artifactFieldErrors: [String: String] = [:]

    /// Working copy of workspace metadata (reorderable).
    var metadata: [CatalogMetadataEntry] = []
    /// Edit buffers keyed by field id.
    var metadataDrafts: [String: String] = [:]
    private(set) var savingMetadataFieldID: String?
    var isAddingMetadata = false
    var addMetadataFieldID = ""
    var addMetadataValue = ""
    var addMetadataFieldError: String?
    var addMetadataValueError: String?
    private(set) var isSavingMetadataAdd = false
    private(set) var vocabularyFields: [CatalogMetadataField] = []

    var toast: VocabularyToast?
    var pageError: String?

    private let sourceID: String
    private let projectDir: String
    private let userID: String
    /// Session contributor name for the note composer byline.
    let sessionDisplayName: String
    private let store: any GenealogyStore
    private let onSourceUpdated: ((CatalogSource) -> Void)?

    init(
        sourceID: String,
        projectDir: String,
        userID: String,
        sessionDisplayName: String = "",
        store: any GenealogyStore,
        onSourceUpdated: ((CatalogSource) -> Void)? = nil
    ) {
        self.sourceID = sourceID
        self.projectDir = projectDir
        self.userID = userID
        self.sessionDisplayName = sessionDisplayName
        self.store = store
        self.onSourceUpdated = onSourceUpdated
    }

    var source: CatalogSource? { workspace?.source }

    var artifacts: [CatalogArtifact] { workspace?.artifacts ?? [] }

    var notes: [CatalogSourceNote] { workspace?.notes ?? [] }

    /// Project folder for resolving `objects/…` thumbnail paths.
    var pageProjectDir: String { projectDir }

    var typeComboOptions: [PVComboBoxOption] {
        types.map { PVComboBoxOption(value: $0.id, label: $0.label, subtext: $0.key) }
    }

    var typeLabel: String {
        types.first { $0.id == sourceTypeID }?.label ?? ""
    }

    /// Grade shown in the chips (assessment or Standard display default).
    var displayedCredibilityGrade: CatalogCredibilityGrade? {
        grades.first { $0.key == credibilityKey }
            ?? grades.first { $0.key == "standard" }
            ?? grades.first
    }

    var canSubmitArtifact: Bool {
        !isSavingArtifact
            && !artifactDraft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Saved values only — drag-reorderable in the Metadata section.
    var savedMetadata: [CatalogMetadataEntry] {
        metadata.filter(\.hasValue)
    }

    /// Type suggestions without a value — separate from the reorderable list.
    var suggestedMetadata: [CatalogMetadataEntry] {
        metadata.filter { !$0.hasValue && $0.suggested }
    }

    var metadataFieldComboOptions: [PVComboBoxOption] {
        let used = Set(metadata.map(\.field.id))
        return vocabularyFields
            .filter { !used.contains($0.id) }
            .map { PVComboBoxOption(value: $0.id, label: $0.label, subtext: $0.key) }
    }

    var canSubmitMetadataAdd: Bool {
        !isSavingMetadataAdd
            && !addMetadataFieldID.isEmpty
            && !addMetadataValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Load

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            // Catalog RPCs take an exclusive open; do not fan out concurrently
            // (catalog.already_open). See docs/ideas/catalog-access-serialization.md.
            let workspace = try await store.getSourceWorkspace(
                projectDir: projectDir,
                sourceID: sourceID
            )
            grades = try await store.listSourceCredibilityGrades(projectDir: projectDir)
            types = try await store.listSourceTypes(projectDir: projectDir)
            vocabularyFields = try await store.listMetadataFields(projectDir: projectDir)
            applyWorkspace(workspace)
        } catch {
            loadError = error
        }
    }

    private func applyWorkspace(_ workspace: CatalogSourceWorkspace) {
        self.workspace = workspace
        title = workspace.source.title
        description = workspace.source.description
        sourceTypeID = workspace.source.sourceTypeID
        applyMetadata(workspace.metadata)
        if let cred = workspace.credibility {
            credibilityKey = cred.gradeKey
            credibilityArgument = cred.argument
        } else {
            credibilityKey = "standard"
            credibilityArgument = ""
        }
        for art in workspace.artifacts {
            if artifactLabels[art.id] == nil {
                artifactLabels[art.id] = art.label
            }
            if artifactDescriptions[art.id] == nil {
                artifactDescriptions[art.id] = art.description
            }
        }
    }

    private func applyMetadata(_ entries: [CatalogMetadataEntry]) {
        metadata = entries
        for e in entries {
            if metadataDrafts[e.field.id] == nil || e.hasValue {
                metadataDrafts[e.field.id] = e.valueText
            }
        }
        let ids = Set(entries.map(\.field.id))
        metadataDrafts = metadataDrafts.filter { ids.contains($0.key) }
        if var ws = workspace {
            ws.metadata = entries
            workspace = ws
        }
    }

    private func refreshWorkspace() async {
        do {
            let workspace = try await store.getSourceWorkspace(projectDir: projectDir, sourceID: sourceID)
            applyWorkspace(workspace)
            onSourceUpdated?(workspace.source)
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Identity

    func saveIdentity() async {
        guard !isSavingIdentity else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            titleError = String(localized: L10n.Sources.pageTitleRequired)
            return
        }
        guard let current = workspace?.source else { return }
        if trimmed == current.title,
           description.trimmingCharacters(in: .whitespacesAndNewlines) == current.description,
           sourceTypeID == current.sourceTypeID
        {
            return
        }
        isSavingIdentity = true
        defer { isSavingIdentity = false }
        do {
            let updated = try await store.updateSource(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                sourceTypeID: sourceTypeID,
                title: trimmed,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            titleError = nil
            if var ws = workspace {
                ws.source = updated
                workspace = ws
            }
            onSourceUpdated?(updated)
        } catch {
            titleError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Credibility

    func selectCredibility(key: String) async {
        credibilityKey = key
        await commitCredibility()
    }

    func saveCredibilityArgument() async {
        await commitCredibility()
    }

    private func commitCredibility() async {
        guard !isSavingCredibility else { return }
        guard let grade = displayedCredibilityGrade ?? grades.first(where: { $0.key == credibilityKey }) else {
            return
        }
        // Missing row + Standard + empty argument: keep display-only (no write).
        if workspace?.credibility == nil,
           grade.key == "standard",
           credibilityArgument.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return
        }
        isSavingCredibility = true
        defer { isSavingCredibility = false }
        do {
            let assessment = try await store.upsertSourceCredibilityAssessment(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                gradeID: grade.id,
                argument: credibilityArgument.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if var ws = workspace {
                ws.credibility = assessment
                workspace = ws
            }
            credibilityKey = assessment.gradeKey
            credibilityArgument = assessment.argument
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Metadata

    func saveMetadataValue(fieldID: String) async {
        guard let entry = metadata.first(where: { $0.field.id == fieldID }) else { return }
        guard savingMetadataFieldID == nil else { return }
        let value = (metadataDrafts[fieldID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if entry.hasValue, value == entry.valueText { return }
        savingMetadataFieldID = fieldID
        defer { savingMetadataFieldID = nil }
        do {
            let date = dateInput(for: entry.field, valueText: value)
            let result = try await store.setSourceMetadata(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fieldID: fieldID,
                valueText: value,
                date: date
            )
            if let idx = metadata.firstIndex(where: { $0.field.id == fieldID }) {
                metadata[idx].valueText = result.valueText
                metadata[idx].dateValueID = result.dateValueID
                metadata[idx].hasValue = true
                metadataDrafts[fieldID] = result.valueText
                if var ws = workspace {
                    ws.metadata = metadata
                    workspace = ws
                }
            }
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    func dismissMetadataSuggestion(fieldID: String) async {
        do {
            let updated = try await store.dismissSourceMetadataSuggestion(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fieldID: fieldID
            )
            applyMetadata(updated)
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    /// Reorders saved fields only; suggestions stay below in their current order.
    func moveSavedMetadata(from source: IndexSet, to destination: Int) async {
        var saved = savedMetadata
        saved.move(fromOffsets: source, toOffset: destination)
        let ordered = saved + suggestedMetadata
        metadata = ordered
        await commitMetadataOrder(ordered.map(\.field.id))
    }

    private func commitMetadataOrder(_ fieldIDs: [String]) async {
        do {
            let updated = try await store.reorderSourceMetadata(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fieldIDs: fieldIDs
            )
            applyMetadata(updated)
        } catch {
            pageError = L10n.Errors.message(for: error)
            await refreshWorkspace()
        }
    }

    func openAddMetadata() {
        addMetadataFieldID = ""
        addMetadataValue = ""
        addMetadataFieldError = nil
        addMetadataValueError = nil
        isAddingMetadata = true
        Task {
            do {
                vocabularyFields = try await store.listMetadataFields(projectDir: projectDir)
            } catch {
                pageError = L10n.Errors.message(for: error)
            }
        }
    }

    func cancelAddMetadata() {
        guard !isSavingMetadataAdd else { return }
        isAddingMetadata = false
    }

    func createMetadataFromAdd() async {
        addMetadataFieldError = nil
        addMetadataValueError = nil
        if addMetadataFieldID.isEmpty {
            addMetadataFieldError = String(localized: L10n.Sources.metadataFieldRequired)
            return
        }
        let value = addMetadataValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            addMetadataValueError = String(localized: L10n.Sources.metadataValueRequired)
            return
        }
        isSavingMetadataAdd = true
        defer { isSavingMetadataAdd = false }
        do {
            let field = vocabularyFields.first { $0.id == addMetadataFieldID }
            let date = field.map { dateInput(for: $0, valueText: value) } ?? nil
            _ = try await store.setSourceMetadata(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fieldID: addMetadataFieldID,
                valueText: value,
                date: date
            )
            isAddingMetadata = false
            await refreshWorkspace()
        } catch {
            addMetadataValueError = L10n.Errors.message(for: error)
        }
    }

    private func dateInput(for field: CatalogMetadataField, valueText: String) -> CatalogDateValueInput? {
        guard field.dataType == "date" else { return nil }
        let trimmed = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let year = Int32(trimmed), (1000...9999).contains(year) else {
            // Free-text dates stay on value_text only until a richer date picker lands.
            return nil
        }
        return CatalogDateValueInput(
            kind: "point",
            qualifier: "",
            calendar: "gregorian",
            startYear: year,
            startMonth: nil,
            startDay: nil,
            phrase: ""
        )
    }

    // MARK: Notes

    func addNote() async {
        let body = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSavingNote else { return }
        isSavingNote = true
        defer { isSavingNote = false }
        do {
            let note = try await store.addSourceNote(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                body: body
            )
            noteDraft = ""
            if var ws = workspace {
                ws.notes.append(note)
                workspace = ws
            }
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    func updateNote(id: String, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let note = try await store.updateSourceNote(
                projectDir: projectDir,
                userID: userID,
                noteID: id,
                body: trimmed
            )
            if var ws = workspace, let idx = ws.notes.firstIndex(where: { $0.id == id }) {
                ws.notes[idx] = note
                workspace = ws
            }
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    func deleteNote(id: String) async {
        do {
            try await store.deleteSourceNote(projectDir: projectDir, userID: userID, noteID: id)
            if var ws = workspace {
                ws.notes.removeAll { $0.id == id }
                workspace = ws
            }
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Artifacts

    func toggleArtifactExpanded(_ id: String) {
        if expandedArtifactIDs.contains(id) {
            expandedArtifactIDs.remove(id)
        } else {
            expandedArtifactIDs.insert(id)
            if let art = artifacts.first(where: { $0.id == id }) {
                artifactLabels[id] = art.label
                artifactDescriptions[id] = art.description
                artifactFieldErrors[id] = nil
            }
        }
    }

    func artifactFieldsDirty(_ id: String) -> Bool {
        guard let art = artifacts.first(where: { $0.id == id }) else { return false }
        let label = (artifactLabels[id] ?? art.label).trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = (artifactDescriptions[id] ?? art.description).trimmingCharacters(in: .whitespacesAndNewlines)
        return label != art.label || desc != art.description
    }

    func canSaveArtifactFields(_ id: String) -> Bool {
        artifactFieldsDirty(id) && savingArtifactID == nil
    }

    func saveArtifactFields(id: String) async {
        guard let art = artifacts.first(where: { $0.id == id }) else { return }
        guard savingArtifactID == nil else { return }
        let label = (artifactLabels[id] ?? art.label).trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = (artifactDescriptions[id] ?? art.description).trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty {
            artifactFieldErrors[id] = String(localized: L10n.Sources.artifactLabelRequired)
            return
        }
        artifactFieldErrors[id] = nil
        if label == art.label, desc == art.description { return }
        savingArtifactID = id
        defer { savingArtifactID = nil }
        do {
            let updated = try await store.updateArtifact(
                projectDir: projectDir,
                userID: userID,
                artifactID: id,
                label: label,
                description: desc
            )
            replaceArtifact(updated)
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    func openAddArtifact() {
        artifactDraft = ArtifactDraft()
        artifactLabelError = nil
        isAddingArtifact = true
    }

    func cancelAddArtifact() {
        guard !isSavingArtifact else { return }
        isAddingArtifact = false
        artifactLabelError = nil
    }

    func pickArtifactFile() {
        let path = ProjectFiles.pickFileForIngest(
            prompt: String(localized: L10n.Sources.filePickPrompt),
            message: String(localized: L10n.Sources.filePickMessage)
        )
        guard let path else { return }
        artifactDraft.filePath = path
        artifactDraft.fileName = URL(fileURLWithPath: path).lastPathComponent
    }

    func clearArtifactFile() {
        artifactDraft.filePath = nil
        artifactDraft.fileName = nil
    }

    func createArtifact() async {
        guard !isSavingArtifact else { return }
        let label = artifactDraft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty {
            artifactLabelError = String(localized: L10n.Sources.artifactLabelRequired)
            return
        }
        isSavingArtifact = true
        defer { isSavingArtifact = false }
        do {
            var art = try await store.createArtifact(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fileID: "",
                label: label,
                description: artifactDraft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if let path = artifactDraft.filePath {
                let ingested = try await store.ingestArtifactFile(
                    projectDir: projectDir,
                    userID: userID,
                    artifactID: art.id,
                    path: path
                )
                art = ingested.artifact
            }
            if var ws = workspace {
                ws.artifacts.append(art)
                workspace = ws
            }
            artifactLabels[art.id] = art.label
            artifactDescriptions[art.id] = art.description
            isAddingArtifact = false
            artifactLabelError = nil
            toast = VocabularyToast(
                title: L10n.Sources.toastArtifactCreatedTitle(ref: art.ref),
                body: art.fileID.isEmpty
                    ? L10n.Sources.toastArtifactCreatedFileless
                    : L10n.Sources.toastArtifactCreatedWithFile,
                tone: .success
            )
        } catch {
            artifactLabelError = L10n.Errors.message(for: error)
        }
    }

    func addFile(toArtifactID id: String) async {
        guard let art = artifacts.first(where: { $0.id == id }), art.fileID.isEmpty else { return }
        let path = ProjectFiles.pickFileForIngest(
            prompt: String(localized: L10n.Sources.filePickPrompt),
            message: String(localized: L10n.Sources.filePickMessage)
        )
        guard let path else { return }
        do {
            let ingested = try await store.ingestArtifactFile(
                projectDir: projectDir,
                userID: userID,
                artifactID: id,
                path: path
            )
            replaceArtifact(ingested.artifact)
            toast = VocabularyToast(
                title: L10n.Sources.toastFileAttachedTitle,
                body: L10n.Sources.toastFileAttachedBody(name: ingested.file.originalFilename),
                tone: .success
            )
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    func openArtifactFile(_ art: CatalogArtifact) {
        guard let file = art.file, !file.relPath.isEmpty else { return }
        if !ProjectFiles.openObject(projectDir: projectDir, relPath: file.relPath) {
            pageError = String(localized: L10n.Sources.fileOpenMissing)
        }
    }

    private func replaceArtifact(_ updated: CatalogArtifact) {
        if var ws = workspace, let idx = ws.artifacts.firstIndex(where: { $0.id == updated.id }) {
            ws.artifacts[idx] = updated
            workspace = ws
        }
        artifactLabels[updated.id] = updated.label
        artifactDescriptions[updated.id] = updated.description
    }
}
