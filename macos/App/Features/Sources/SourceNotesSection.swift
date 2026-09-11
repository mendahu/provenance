import Foundation
import Observation

/// Research notes on the Source page: composer draft plus row updates and
/// deletes.
@MainActor
@Observable
final class SourceNotesSection {
    var draft = ""
    private(set) var isSaving = false

    private let context: SourcePageContext

    init(context: SourcePageContext) {
        self.context = context
    }

    var items: [CatalogSourceNote] { context.workspace?.notes ?? [] }

    func add() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let note = try await context.store.addSourceNote(
                projectDir: context.projectDir,
                userID: context.userID,
                sourceID: context.sourceID,
                body: body
            )
            draft = ""
            context.workspace?.notes.append(note)
        } catch {
            context.pageError = L10n.Errors.message(for: error)
        }
    }

    func update(id: String, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let note = try await context.store.updateSourceNote(
                projectDir: context.projectDir,
                userID: context.userID,
                noteID: id,
                body: trimmed
            )
            if let idx = context.workspace?.notes.firstIndex(where: { $0.id == id }) {
                context.workspace?.notes[idx] = note
            }
        } catch {
            context.pageError = L10n.Errors.message(for: error)
        }
    }

    func delete(id: String) async {
        do {
            try await context.store.deleteSourceNote(
                projectDir: context.projectDir,
                userID: context.userID,
                noteID: id
            )
            context.workspace?.notes.removeAll { $0.id == id }
        } catch {
            context.pageError = L10n.Errors.message(for: error)
        }
    }
}
