import Foundation
import Observation

/// Metadata rows (saved values + type suggestions), the Add-metadata dialog,
/// and the structured DateValue editor for the Source page.
@MainActor
@Observable
final class SourceMetadataSection {
    /// Edit buffers keyed by field id.
    var drafts: [String: String] = [:]
    /// Saved row currently in explicit edit mode (one at a time).
    var editingFieldID: String?
    private(set) var savingFieldID: String?

    // MARK: Add dialog

    var isAdding = false
    var addFieldID = ""
    var addValue = ""
    var addFieldError: String?
    var addValueError: String?
    private(set) var isSavingAdd = false

    // MARK: Date editor

    var isEditingDate = false
    var dateEditorFieldID: String?
    var dateEditorDraft = DateValueDraft.empty()
    private(set) var isSavingDate = false

    private let context: SourcePageContext

    init(context: SourcePageContext) {
        self.context = context
    }

    var entries: [CatalogMetadataEntry] { context.workspace?.metadata ?? [] }

    /// Saved values only — drag-reorderable in the Metadata section.
    var saved: [CatalogMetadataEntry] {
        entries.filter(\.hasValue)
    }

    /// Type suggestions without a value — separate from the reorderable list.
    var suggested: [CatalogMetadataEntry] {
        entries.filter { !$0.hasValue && $0.suggested }
    }

    var fieldComboOptions: [PVComboBoxOption] {
        let used = Set(entries.map(\.field.id))
        return (context.workspace?.fields ?? [])
            .filter { !used.contains($0.id) }
            .map { PVComboBoxOption(value: $0.id, label: $0.label, subtext: $0.key) }
    }

    var canSubmitAdd: Bool {
        !isSavingAdd
            && !addFieldID.isEmpty
            && !addValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The entry already carries a structured DateValue.
    func isStructured(_ entry: CatalogMetadataEntry) -> Bool {
        !entry.dateValueID.isEmpty || !entry.dateSummary.isEmpty
    }

    /// True when the open date editor reopens an existing structured
    /// DateValue (Edit date) rather than structuring one for the first time.
    var isDateEditMode: Bool {
        guard let fieldID = dateEditorFieldID,
              let entry = entries.first(where: { $0.field.id == fieldID })
        else { return false }
        return isStructured(entry)
    }

    /// Dialog subtitle: `SRC-XXXXX · Metadata · <field label>`.
    var dateEditorSubtitle: LocalizedStringResource? {
        guard let fieldID = dateEditorFieldID,
              let entry = entries.first(where: { $0.field.id == fieldID })
        else { return nil }
        let ref = context.source?.ref ?? "…"
        let text = "\(ref) · Metadata · \(entry.field.label)"
        return LocalizedStringResource(String.LocalizationValue(text))
    }

    /// Seeds edit buffers for saved values and drops buffers for rows that no
    /// longer exist (dismissed suggestions). Also exits any open edit mode.
    func resetDrafts() {
        editingFieldID = nil
        syncDrafts()
    }

    private func syncDrafts() {
        for e in entries where drafts[e.field.id] == nil || e.hasValue {
            drafts[e.field.id] = e.valueText
        }
        let ids = Set(entries.map(\.field.id))
        drafts = drafts.filter { ids.contains($0.key) }
    }

    // MARK: Row edit

    func beginEdit(fieldID: String) {
        guard let entry = entries.first(where: { $0.field.id == fieldID }), entry.hasValue else { return }
        if let current = editingFieldID, current != fieldID {
            cancelEdit()
        }
        drafts[fieldID] = entry.valueText
        editingFieldID = fieldID
    }

    func cancelEdit() {
        guard let fieldID = editingFieldID else { return }
        guard savingFieldID == nil else { return }
        if let entry = entries.first(where: { $0.field.id == fieldID }) {
            drafts[fieldID] = entry.valueText
        }
        editingFieldID = nil
    }

    func save(fieldID: String) async {
        guard let entry = entries.first(where: { $0.field.id == fieldID }) else { return }
        guard savingFieldID == nil else { return }
        let value = (drafts[fieldID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if entry.hasValue, value == entry.valueText {
            if editingFieldID == fieldID {
                editingFieldID = nil
            }
            return
        }
        savingFieldID = fieldID
        defer { savingFieldID = nil }
        do {
            let updated = try await context.store.setSourceMetadata(
                projectDir: context.projectDir,
                userID: context.userID,
                sourceID: context.sourceID,
                fieldID: fieldID,
                valueText: value,
                date: nil
            )
            replaceEntry(updated)
            if editingFieldID == fieldID {
                editingFieldID = nil
            }
        } catch {
            context.pageError = L10n.Errors.message(for: error)
        }
    }

    func dismissSuggestion(fieldID: String) async {
        do {
            let updated = try await context.store.dismissSourceMetadataSuggestion(
                projectDir: context.projectDir,
                userID: context.userID,
                sourceID: context.sourceID,
                fieldID: fieldID
            )
            context.workspace?.metadata = updated
            syncDrafts()
        } catch {
            context.pageError = L10n.Errors.message(for: error)
        }
    }

    /// Reorders saved fields only; suggestions stay below in their current
    /// order. On failure the optimistic move is reverted.
    func moveSaved(from source: IndexSet, to destination: Int) async {
        let previous = entries
        var savedRows = saved
        savedRows.move(fromOffsets: source, toOffset: destination)
        let ordered = savedRows + suggested
        context.workspace?.metadata = ordered
        do {
            let updated = try await context.store.reorderSourceMetadata(
                projectDir: context.projectDir,
                userID: context.userID,
                sourceID: context.sourceID,
                fieldIDs: ordered.map(\.field.id)
            )
            context.workspace?.metadata = updated
            syncDrafts()
        } catch {
            context.pageError = L10n.Errors.message(for: error)
            context.workspace?.metadata = previous
        }
    }

    // MARK: Add dialog

    func openAdd() {
        addFieldID = ""
        addValue = ""
        addFieldError = nil
        addValueError = nil
        isAdding = true
    }

    func cancelAdd() {
        guard !isSavingAdd else { return }
        isAdding = false
    }

    func createFromAdd() async {
        addFieldError = nil
        addValueError = nil
        if addFieldID.isEmpty {
            addFieldError = String(localized: L10n.Sources.metadataFieldRequired)
            return
        }
        let value = addValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            addValueError = String(localized: L10n.Sources.metadataValueRequired)
            return
        }
        isSavingAdd = true
        defer { isSavingAdd = false }
        do {
            let entry = try await context.store.setSourceMetadata(
                projectDir: context.projectDir,
                userID: context.userID,
                sourceID: context.sourceID,
                fieldID: addFieldID,
                valueText: value,
                date: nil
            )
            replaceEntry(entry)
            isAdding = false
        } catch {
            addValueError = L10n.Errors.message(for: error)
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
        if let date = entries.first(where: { $0.field.id == fieldID })?.date {
            dateEditorDraft = DateValueDraft(from: date)
        } else {
            dateEditorDraft = DateValueDraft.empty()
        }
        isEditingDate = true
    }

    func cancelDateEditor() {
        guard !isSavingDate else { return }
        isEditingDate = false
        dateEditorFieldID = nil
        dateEditorDraft = DateValueDraft.empty()
    }

    func saveDateEditor() async {
        guard let fieldID = dateEditorFieldID else { return }
        guard !isSavingDate else { return }
        guard dateEditorDraft.isValid else { return }
        let value = (drafts[fieldID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            context.pageError = String(localized: L10n.Sources.metadataValueRequired)
            return
        }
        isSavingDate = true
        defer { isSavingDate = false }
        do {
            let entry = try await context.store.setSourceMetadata(
                projectDir: context.projectDir,
                userID: context.userID,
                sourceID: context.sourceID,
                fieldID: fieldID,
                valueText: value,
                date: dateEditorDraft.toInput()
            )
            replaceEntry(entry)
            isEditingDate = false
            dateEditorFieldID = nil
            dateEditorDraft = DateValueDraft.empty()
        } catch {
            context.pageError = L10n.Errors.message(for: error)
        }
    }

    /// Patches one workspace row from a `setSourceMetadata` response (the
    /// server returns the refreshed entry, including structured date state).
    private func replaceEntry(_ entry: CatalogMetadataEntry) {
        if let idx = entries.firstIndex(where: { $0.field.id == entry.field.id }) {
            context.workspace?.metadata[idx] = entry
        } else {
            context.workspace?.metadata.append(entry)
        }
        drafts[entry.field.id] = entry.valueText
    }
}
