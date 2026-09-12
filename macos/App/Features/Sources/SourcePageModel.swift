import Foundation
import Observation

/// State for the individual Source page (S2-18): loads the workspace and
/// composes the section models (identity, credibility, metadata, notes,
/// artifacts). Each section owns its own drafts, saving flags, and errors;
/// the shared `SourcePageContext` owns the workspace itself.
@MainActor
@Observable
final class SourcePageModel {
    // `var` (not `let`) so SwiftUI can form writable key paths for
    // `$model.section.draft` bindings; the sections are never reassigned.
    var identity: SourceIdentitySection
    var credibility: SourceCredibilitySection
    var metadata: SourceMetadataSection
    var notes: SourceNotesSection
    var artifacts: SourceArtifactsSection

    private(set) var isLoading = false
    var loadError: Error?

    /// Session contributor name for the note composer byline.
    let sessionDisplayName: String

    private let context: SourcePageContext

    init(
        sourceID: String,
        projectDir: String,
        userID: String,
        sessionDisplayName: String = "",
        store: any GenealogyStore,
        onSourceUpdated: ((CatalogSource) -> Void)? = nil
    ) {
        let context = SourcePageContext(
            sourceID: sourceID,
            projectDir: projectDir,
            userID: userID,
            store: store,
            onSourceUpdated: onSourceUpdated
        )
        self.context = context
        self.sessionDisplayName = sessionDisplayName
        identity = SourceIdentitySection(context: context)
        credibility = SourceCredibilitySection(context: context)
        metadata = SourceMetadataSection(context: context)
        notes = SourceNotesSection(context: context)
        artifacts = SourceArtifactsSection(context: context)
    }

    var workspace: CatalogSourceWorkspace? { context.workspace }

    var source: CatalogSource? { context.source }

    /// Project folder for resolving `objects/…` thumbnail paths.
    var pageProjectDir: String { context.projectDir }

    /// Non-field failure banner shared by the page sections.
    var pageError: String? {
        get { context.pageError }
        set { context.pageError = newValue }
    }

    var toast: VocabularyToast? {
        get { context.toast }
        set { context.toast = newValue }
    }

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            // One exclusive catalog open: the workspace payload carries the
            // page vocabulary (types, grades, fields) alongside the source.
            let workspace = try await context.store.getSourceWorkspace(
                projectDir: context.projectDir,
                sourceID: context.sourceID
            )
            apply(workspace)
        } catch {
            loadError = error
        }
    }

    private func apply(_ workspace: CatalogSourceWorkspace) {
        context.workspace = workspace
        identity.reset()
        credibility.resetDrafts()
        metadata.resetDrafts()
        notes.reset()
        artifacts.seedDrafts()
    }
}
