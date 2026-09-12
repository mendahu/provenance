import Foundation
import Observation

/// Shared dependencies and workspace state for the Source page section
/// models (identity, credibility, metadata, notes, artifacts).
///
/// The workspace is the single source of truth: sections read saved values
/// from it and mutate it directly after successful writes. Non-field
/// failures surface through `pageError`; section-specific validation stays
/// on the owning section.
@MainActor
@Observable
final class SourcePageContext {
    let sourceID: String
    let projectDir: String
    let userID: String
    let store: any GenealogyStore
    /// Notifies the Sources list when identity changes (title/type edits).
    let onSourceUpdated: ((CatalogSource) -> Void)?

    var workspace: CatalogSourceWorkspace?
    /// Non-field failure banner shared by the page sections.
    var pageError: String?
    var toast: VocabularyToast?

    /// Clears the shared banner before a new section mutation.
    func clearPageError() {
        pageError = nil
    }

    init(
        sourceID: String,
        projectDir: String,
        userID: String,
        store: any GenealogyStore,
        onSourceUpdated: ((CatalogSource) -> Void)?
    ) {
        self.sourceID = sourceID
        self.projectDir = projectDir
        self.userID = userID
        self.store = store
        self.onSourceUpdated = onSourceUpdated
    }

    var source: CatalogSource? { workspace?.source }
}
