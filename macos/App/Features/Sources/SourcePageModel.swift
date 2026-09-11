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

    var toast: VocabularyToast?
    var pageError: String?

    private let sourceID: String
    private let projectDir: String
    private let userID: String
    private let store: any GenealogyStore
    private let onSourceUpdated: ((CatalogSource) -> Void)?

    init(
        sourceID: String,
        projectDir: String,
        userID: String,
        store: any GenealogyStore,
        onSourceUpdated: ((CatalogSource) -> Void)? = nil
    ) {
        self.sourceID = sourceID
        self.projectDir = projectDir
        self.userID = userID
        self.store = store
        self.onSourceUpdated = onSourceUpdated
    }

    var source: CatalogSource? { workspace?.source }

    var artifacts: [CatalogArtifact] { workspace?.artifacts ?? [] }

    var notes: [CatalogSourceNote] { workspace?.notes ?? [] }

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

    // MARK: Load

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            async let ws = store.getSourceWorkspace(projectDir: projectDir, sourceID: sourceID)
            async let g = store.listSourceCredibilityGrades(projectDir: projectDir)
            async let t = store.listSourceTypes(projectDir: projectDir)
            let workspace = try await ws
            grades = try await g
            types = try await t
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
            }
        }
    }

    func saveArtifactFields(id: String) async {
        guard let art = artifacts.first(where: { $0.id == id }) else { return }
        let label = (artifactLabels[id] ?? art.label).trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = (artifactDescriptions[id] ?? art.description).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        if label == art.label, desc == art.description { return }
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
