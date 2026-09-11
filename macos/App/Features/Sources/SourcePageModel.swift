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
    private(set) var isLoading = false
    var loadError: Error?

    var titleError: String?
    private(set) var isSavingIdentity = false

    // MARK: Title edit

    var editingTitle = false
    var titleDraft = ""

    // MARK: Type edit

    var editingType = false
    var typeDraftID = ""

    // MARK: Description edit

    var editingDescription = false
    var descriptionDraft = ""

    // MARK: Credibility drafts (saved values are derived from `workspace`)

    var credibilityDraftKey = "standard"
    var credibilityArgumentDraft = ""
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

    /// Edit buffers keyed by field id.
    var metadataDrafts: [String: String] = [:]
    /// Saved metadata row currently in explicit edit mode (one at a time).
    var editingMetadataFieldID: String?
    private(set) var savingMetadataFieldID: String?
    var isAddingMetadata = false
    var addMetadataFieldID = ""
    var addMetadataValue = ""
    var addMetadataFieldError: String?
    var addMetadataValueError: String?
    private(set) var isSavingMetadataAdd = false

    // MARK: Date editor

    var isEditingDate = false
    var dateEditorFieldID: String?
    var dateEditorDraft = DateValueDraft.empty()
    private(set) var isSavingDateEditor = false

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

    /// Saved identity, derived from the workspace (single source of truth).
    var title: String { workspace?.source.title ?? "" }

    var description: String { workspace?.source.description ?? "" }

    var sourceTypeID: String { workspace?.source.sourceTypeID ?? "" }

    /// Saved grade key; defaults to `standard` when no assessment row.
    var credibilityKey: String { workspace?.credibility?.gradeKey ?? "standard" }

    var credibilityArgument: String { workspace?.credibility?.argument ?? "" }

    /// Workspace metadata rows; writes go straight to the workspace.
    var metadata: [CatalogMetadataEntry] {
        get { workspace?.metadata ?? [] }
        set { workspace?.metadata = newValue }
    }

    var artifacts: [CatalogArtifact] { workspace?.artifacts ?? [] }

    var notes: [CatalogSourceNote] { workspace?.notes ?? [] }

    /// Page vocabulary rides on the workspace payload (one catalog open).
    var grades: [CatalogCredibilityGrade] { workspace?.grades ?? [] }

    var types: [CatalogSourceType] { workspace?.types ?? [] }

    private var vocabularyFields: [CatalogMetadataField] { workspace?.fields ?? [] }

    /// Project folder for resolving `objects/…` thumbnail paths.
    var pageProjectDir: String { projectDir }

    var typeComboOptions: [PVComboBoxOption] {
        types.map { PVComboBoxOption(value: $0.id, label: $0.label, subtext: $0.key) }
    }

    /// Resting type label from committed `sourceTypeID`.
    var typeLabel: String {
        types.first { $0.id == sourceTypeID }?.label ?? ""
    }

    /// Grade shown in the chips (draft selection, falling back to Standard).
    var displayedCredibilityGrade: CatalogCredibilityGrade? {
        grades.first { $0.key == credibilityDraftKey }
            ?? grades.first { $0.key == "standard" }
            ?? grades.first
    }

    var credibilityDirty: Bool {
        credibilityDraftKey != credibilityKey
            || credibilityArgumentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            != credibilityArgument.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSavedCredibilityAssessment: Bool {
        workspace?.credibility != nil
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
            // One exclusive catalog open: the workspace payload carries the
            // page vocabulary (types, grades, fields) alongside the source.
            let workspace = try await store.getSourceWorkspace(
                projectDir: projectDir,
                sourceID: sourceID
            )
            applyWorkspace(workspace)
        } catch {
            loadError = error
        }
    }

    private func applyWorkspace(_ workspace: CatalogSourceWorkspace) {
        self.workspace = workspace

        editingTitle = false
        titleDraft = ""
        editingType = false
        typeDraftID = workspace.source.sourceTypeID
        editingDescription = false
        descriptionDraft = ""

        editingMetadataFieldID = nil
        syncMetadataDrafts()
        credibilityDraftKey = credibilityKey
        credibilityArgumentDraft = credibilityArgument

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
        syncMetadataDrafts()
    }

    /// Seeds edit buffers for saved values and drops buffers for rows that
    /// no longer exist (dismissed suggestions).
    private func syncMetadataDrafts() {
        for e in metadata where metadataDrafts[e.field.id] == nil || e.hasValue {
            metadataDrafts[e.field.id] = e.valueText
        }
        let ids = Set(metadata.map(\.field.id))
        metadataDrafts = metadataDrafts.filter { ids.contains($0.key) }
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

    // MARK: Identity — title

    func beginEditTitle() {
        titleDraft = title
        titleError = nil
        editingTitle = true
    }

    func cancelEditTitle() {
        guard !isSavingIdentity else { return }
        editingTitle = false
        titleDraft = ""
        titleError = nil
    }

    func saveTitle() async {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            titleError = String(localized: L10n.Sources.pageTitleRequired)
            return
        }
        await saveIdentity(
            title: trimmed,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceTypeID: sourceTypeID
        )
        if titleError == nil {
            editingTitle = false
            titleDraft = ""
        }
    }

    // MARK: Identity — type

    func beginEditType() {
        // Blank the picker so the researcher can type immediately; Cancel
        // restores `sourceTypeID`.
        typeDraftID = ""
        editingType = true
    }

    func cancelEditType() {
        guard !isSavingIdentity else { return }
        typeDraftID = sourceTypeID
        editingType = false
    }

    func saveType() async {
        let typeID = typeDraftID.isEmpty ? sourceTypeID : typeDraftID
        await saveIdentity(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceTypeID: typeID
        )
        if titleError == nil {
            editingType = false
        }
    }

    // MARK: Identity — description

    func beginEditDescription() {
        descriptionDraft = description
        editingDescription = true
    }

    func cancelEditDescription() {
        guard !isSavingIdentity else { return }
        editingDescription = false
        descriptionDraft = ""
    }

    func saveDescription() async {
        await saveIdentity(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceTypeID: sourceTypeID
        )
        if titleError == nil {
            editingDescription = false
            descriptionDraft = ""
        }
    }

    /// Shared `updateSource` write used by title / type / description saves.
    private func saveIdentity(title: String, description: String, sourceTypeID: String) async {
        guard !isSavingIdentity else { return }
        if title.isEmpty {
            titleError = String(localized: L10n.Sources.pageTitleRequired)
            return
        }
        guard let current = workspace?.source else { return }
        if title == current.title,
           description == current.description,
           sourceTypeID == current.sourceTypeID
        {
            titleError = nil
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
                title: title,
                description: description
            )
            titleError = nil
            workspace?.source = updated
            typeDraftID = updated.sourceTypeID
            onSourceUpdated?(updated)
        } catch {
            titleError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Credibility

    func selectCredibilityDraft(key: String) {
        credibilityDraftKey = key
    }

    func cancelCredibility() {
        guard !isSavingCredibility else { return }
        credibilityDraftKey = credibilityKey
        credibilityArgumentDraft = credibilityArgument
    }

    func saveCredibility() async {
        guard !isSavingCredibility else { return }
        guard let grade = grades.first(where: { $0.key == credibilityDraftKey })
            ?? displayedCredibilityGrade
            ?? grades.first
        else {
            return
        }
        let argument = credibilityArgumentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        // Missing row + Standard + empty argument: keep display-only (no write).
        if workspace?.credibility == nil,
           grade.key == "standard",
           argument.isEmpty
        {
            credibilityDraftKey = "standard"
            credibilityArgumentDraft = ""
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
                argument: argument
            )
            workspace?.credibility = assessment
            credibilityDraftKey = credibilityKey
            credibilityArgumentDraft = credibilityArgument
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Metadata

    func beginEditMetadata(fieldID: String) {
        guard let entry = metadata.first(where: { $0.field.id == fieldID }), entry.hasValue else { return }
        if let current = editingMetadataFieldID, current != fieldID {
            cancelEditMetadata()
        }
        metadataDrafts[fieldID] = entry.valueText
        editingMetadataFieldID = fieldID
    }

    func cancelEditMetadata() {
        guard let fieldID = editingMetadataFieldID else { return }
        guard savingMetadataFieldID == nil else { return }
        if let entry = metadata.first(where: { $0.field.id == fieldID }) {
            metadataDrafts[fieldID] = entry.valueText
        }
        editingMetadataFieldID = nil
    }

    func saveMetadataValue(fieldID: String) async {
        guard let entry = metadata.first(where: { $0.field.id == fieldID }) else { return }
        guard savingMetadataFieldID == nil else { return }
        let value = (metadataDrafts[fieldID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if entry.hasValue, value == entry.valueText {
            if editingMetadataFieldID == fieldID {
                editingMetadataFieldID = nil
            }
            return
        }
        savingMetadataFieldID = fieldID
        defer { savingMetadataFieldID = nil }
        do {
            let entry = try await store.setSourceMetadata(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fieldID: fieldID,
                valueText: value,
                date: nil
            )
            replaceMetadataEntry(entry)
            if editingMetadataFieldID == fieldID {
                editingMetadataFieldID = nil
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
            let entry = try await store.setSourceMetadata(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fieldID: addMetadataFieldID,
                valueText: value,
                date: nil
            )
            replaceMetadataEntry(entry)
            isAddingMetadata = false
        } catch {
            addMetadataValueError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Date editor

    func openStructureDate(fieldID: String) {
        dateEditorFieldID = fieldID
        dateEditorDraft = DateValueDraft.empty()
        isEditingDate = true
    }

    func openEditDate(fieldID: String) {
        dateEditorFieldID = fieldID
        if let date = metadata.first(where: { $0.field.id == fieldID })?.date {
            dateEditorDraft = DateValueDraft(from: date)
        } else {
            dateEditorDraft = DateValueDraft.empty()
        }
        isEditingDate = true
    }

    func cancelDateEditor() {
        guard !isSavingDateEditor else { return }
        isEditingDate = false
        dateEditorFieldID = nil
        dateEditorDraft = DateValueDraft.empty()
    }

    func saveDateEditor() async {
        guard let fieldID = dateEditorFieldID else { return }
        guard !isSavingDateEditor else { return }
        guard dateEditorDraft.isValid else { return }
        let value = (metadataDrafts[fieldID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            pageError = String(localized: L10n.Sources.metadataValueRequired)
            return
        }
        isSavingDateEditor = true
        defer { isSavingDateEditor = false }
        do {
            let entry = try await store.setSourceMetadata(
                projectDir: projectDir,
                userID: userID,
                sourceID: sourceID,
                fieldID: fieldID,
                valueText: value,
                date: dateEditorDraft.toInput()
            )
            replaceMetadataEntry(entry)
            isEditingDate = false
            dateEditorFieldID = nil
            dateEditorDraft = DateValueDraft.empty()
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    /// Patches one workspace row from a `setSourceMetadata` response (the
    /// server returns the refreshed entry, including structured date state).
    private func replaceMetadataEntry(_ entry: CatalogMetadataEntry) {
        if let idx = metadata.firstIndex(where: { $0.field.id == entry.field.id }) {
            metadata[idx] = entry
        } else {
            metadata.append(entry)
        }
        metadataDrafts[entry.field.id] = entry.valueText
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
            workspace?.notes.append(note)
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
            if let idx = workspace?.notes.firstIndex(where: { $0.id == id }) {
                workspace?.notes[idx] = note
            }
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    func deleteNote(id: String) async {
        do {
            try await store.deleteSourceNote(projectDir: projectDir, userID: userID, noteID: id)
            workspace?.notes.removeAll { $0.id == id }
        } catch {
            pageError = L10n.Errors.message(for: error)
        }
    }

    // MARK: Artifacts

    func toggleArtifactExpanded(_ id: String) {
        if expandedArtifactIDs.contains(id) {
            expandedArtifactIDs.removeAll()
        } else {
            // Accordion: only one Artifact expanded at a time.
            expandedArtifactIDs = [id]
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

    func cancelArtifactFields(id: String) {
        guard savingArtifactID != id else { return }
        guard let art = artifacts.first(where: { $0.id == id }) else { return }
        artifactLabels[id] = art.label
        artifactDescriptions[id] = art.description
        artifactFieldErrors[id] = nil
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
            workspace?.artifacts.append(art)
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
        if let idx = workspace?.artifacts.firstIndex(where: { $0.id == updated.id }) {
            workspace?.artifacts[idx] = updated
        }
        artifactLabels[updated.id] = updated.label
        artifactDescriptions[updated.id] = updated.description
    }
}
