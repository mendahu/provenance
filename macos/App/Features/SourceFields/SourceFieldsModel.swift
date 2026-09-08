import Foundation
import Observation

/// State for the **Source fields** workspace destination (S2-02 board /
/// S2-15 PR): browse/search/sort the project's `source_metadata_fields`
/// vocabulary, and create or edit `user`-origin rows. `provenencia` (and
/// any future `plugin:…`) rows are view-only — see `isSelectedFieldLocked`.
@MainActor
@Observable
final class SourceFieldsModel {
    /// The add/edit form's in-progress values. `key` is never part of this —
    /// it's minted server-side from `label` (`FieldSlug.kebab` mirrors the
    /// preview client-side; the engine is the source of truth).
    struct Draft: Equatable {
        var label: String
        var dataType: String
        var description: String
    }

    struct Toast: Equatable, Hashable {
        var title: String
        var body: String
    }

    /// Detail-pane mode. Illegal combinations of the old flags
    /// (`isAdding` + `selectedFieldID` + `resumeSelectionID`) are
    /// unrepresentable here. `draft` is set for `.adding` / `.editing`
    /// (form bindings) and also for `.viewing` (unused by the UI, but
    /// kept non-nil so tearing down `Binding($model.draft)` projections
    /// does not trap when leaving the form).
    enum Mode: Equatable {
        case empty
        case viewing(id: String)
        case adding(resumeID: String?)
        case editing(id: String)
    }

    private(set) var fields: [CatalogMetadataField] = []
    private(set) var isLoading = false
    var loadError: Error?

    var query = ""
    private(set) var sortAscending = true

    private(set) var mode: Mode = .empty
    /// Non-nil whenever a field is selected or the add form is open.
    /// Cleared only for `.empty`. Do not nil this while the edit/add form
    /// may still be in the hierarchy — `@Bindable` projections into an
    /// optional trap if it becomes nil mid-update (edit/add → view).
    var draft: Draft?
    private(set) var isSaving = false
    var formError: String?
    var toast: Toast?

    private let projectDir: String
    private let userID: String
    private let store: any GenealogyStore

    init(projectDir: String, userID: String, store: any GenealogyStore) {
        self.projectDir = projectDir
        self.userID = userID
        self.store = store
    }

    // MARK: Derived

    var visibleFields: [CatalogMetadataField] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = q.isEmpty ? fields : fields.filter { matches($0, query: q) }
        return filtered.sorted { a, b in
            let order = a.label.localizedCaseInsensitiveCompare(b.label)
            return sortAscending ? order == .orderedAscending : order == .orderedDescending
        }
    }

    var isAdding: Bool {
        if case .adding = mode { return true }
        return false
    }

    var selectedField: CatalogMetadataField? {
        switch mode {
        case .viewing(let id), .editing(let id):
            return fields.first { $0.id == id }
        case .empty, .adding:
            return nil
        }
    }

    var isSelectedFieldLocked: Bool {
        if case .viewing = mode { return true }
        return false
    }

    /// Live key preview while adding — mirrors what the engine will mint.
    var draftKey: String {
        FieldSlug.kebab(draft?.label ?? "")
    }

    var isDirty: Bool {
        guard case .editing = mode, let field = selectedField, let draft else { return false }
        return draft.label != field.label || draft.dataType != field.dataType || draft.description != field.description
    }

    var canSubmit: Bool {
        guard let draft, !isSaving, !draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return isAdding || isDirty
    }

    var seededCount: Int { fields.filter { $0.origin == SourceFieldOrigin.provenencia }.count }
    var userCount: Int { fields.filter { $0.origin == SourceFieldOrigin.user }.count }
    var pluginCount: Int { fields.filter { $0.origin != SourceFieldOrigin.provenencia && $0.origin != SourceFieldOrigin.user }.count }

    var countLine: String {
        if pluginCount > 0 {
            return L10n.SourceFields.countLineWithPlugin(total: fields.count, seeded: seededCount, user: userCount, plugin: pluginCount)
        }
        return L10n.SourceFields.countLine(total: fields.count, seeded: seededCount, user: userCount)
    }

    // MARK: Actions

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            fields = try await store.listMetadataFields(projectDir: projectDir)
        } catch {
            loadError = error
        }
    }

    func toggleLabelSort() {
        sortAscending.toggle()
    }

    func select(_ id: String) {
        guard let field = fields.first(where: { $0.id == id }) else { return }
        formError = nil
        // Always keep `draft` non-nil here. The locked (.viewing) panel does
        // not bind it, but going edit/add → view with `draft = nil` in the
        // same turn tears down `Binding($model.draft)` and traps.
        draft = Draft(label: field.label, dataType: field.dataType, description: field.description)
        if field.origin == SourceFieldOrigin.user {
            mode = .editing(id: id)
        } else {
            mode = .viewing(id: id)
        }
    }

    func openAdd() {
        let resumeID: String? = switch mode {
        case .viewing(let id), .editing(let id): id
        case .empty, .adding: nil
        }
        formError = nil
        mode = .adding(resumeID: resumeID)
        draft = Draft(label: "", dataType: SourceFieldDataType.text, description: "")
    }

    func cancelAdd() {
        guard case .adding(let resumeID) = mode else { return }
        formError = nil
        if let resumeID {
            select(resumeID)
        } else {
            mode = .empty
            // Leave `draft` in place — nilling it in the same turn as
            // removing the form races `@Bindable` optional projections.
        }
    }

    func revertEdit() {
        guard case .editing(let id) = mode, let field = fields.first(where: { $0.id == id }) else { return }
        draft = Draft(label: field.label, dataType: field.dataType, description: field.description)
        formError = nil
    }

    func submit() async {
        guard let draft else { return }
        let label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            formError = String(localized: L10n.SourceFields.errorLabelRequired)
            return
        }
        if isAdding && FieldSlug.kebab(label).isEmpty {
            formError = String(localized: L10n.SourceFields.errorUnslugifiable)
            return
        }
        isSaving = true
        formError = nil
        defer { isSaving = false }
        do {
            switch mode {
            case .adding:
                let created = try await store.createMetadataField(
                    projectDir: projectDir, userID: userID,
                    label: label, dataType: draft.dataType, description: draft.description
                )
                fields.append(created)
                query = ""
                mode = .editing(id: created.id)
                self.draft = Draft(label: created.label, dataType: created.dataType, description: created.description)
                toast = Toast(
                    title: String(localized: L10n.SourceFields.toastAddedTitle),
                    body: L10n.SourceFields.toastAddedBody(label: created.label, key: created.key)
                )
            case .editing(let id):
                let updated = try await store.updateMetadataField(
                    projectDir: projectDir, userID: userID, fieldID: id,
                    label: label, dataType: draft.dataType, description: draft.description
                )
                if let idx = fields.firstIndex(where: { $0.id == updated.id }) {
                    fields[idx] = updated
                }
                mode = .editing(id: updated.id)
                self.draft = Draft(label: updated.label, dataType: updated.dataType, description: updated.description)
                toast = Toast(
                    title: String(localized: L10n.SourceFields.toastUpdatedTitle),
                    body: L10n.SourceFields.toastUpdatedBody(label: updated.label, key: updated.key)
                )
            case .empty, .viewing:
                break
            }
        } catch {
            formError = L10n.Errors.message(for: error)
        }
    }

    private func matches(_ field: CatalogMetadataField, query: String) -> Bool {
        field.label.lowercased().contains(query)
            || field.key.lowercased().contains(query)
            || field.description.lowercased().contains(query)
    }
}

/// `CatalogMetadataField.origin` / `.dataType` namespaces — mirrors
/// `core/database/sourcefields`'s `Origin…`/`DataType…` constants (the FFI
/// layer carries these as plain strings, not an enum).
enum SourceFieldOrigin {
    static let provenencia = "provenencia"
    static let user = "user"

    private static let pluginPrefix = "plugin:"

    /// The id after `plugin:` (e.g. `"plugin:findagrave"` → `"findagrave"`),
    /// or the raw origin unchanged when it has no such prefix.
    static func pluginID(from origin: String) -> String {
        origin.hasPrefix(pluginPrefix) ? String(origin.dropFirst(pluginPrefix.count)) : origin
    }
}

enum SourceFieldDataType {
    static let text = "text"
    static let date = "date"
}
