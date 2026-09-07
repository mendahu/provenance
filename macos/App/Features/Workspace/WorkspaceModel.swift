import Foundation
import Observation

/// State for the post-onboarding app workspace: which top-level
/// destination is selected, and whether the sidebar is showing labels or
/// collapsed to an icon rail. See
/// `docs/deployment-plan/spike-2/design/S2-01-workspace-chrome.md`.
@MainActor
@Observable
final class WorkspaceModel {
    /// Spike 2's top-level destinations (W-13, W-16), plus Files — added to
    /// the design board after the written brief, alongside Source content
    /// (its Artifact ingest / file preview arrives in S2-03). Raw values
    /// match the design board's kebab-case section ids.
    enum Section: String, CaseIterable {
        case sources
        case sourceTypes = "source-types"
        case sourceFields = "source-fields"
        case files

        var label: LocalizedStringResource {
            switch self {
            case .sources: L10n.Workspace.sourcesTitle
            case .sourceTypes: L10n.Workspace.sourceTypesTitle
            case .sourceFields: L10n.Workspace.sourceFieldsTitle
            case .files: L10n.Workspace.filesTitle
            }
        }

        var placeholderNote: LocalizedStringResource {
            switch self {
            case .sources: L10n.Workspace.sourcesPlaceholderNote
            case .sourceTypes: L10n.Workspace.sourceTypesPlaceholderNote
            case .sourceFields: L10n.Workspace.sourceFieldsPlaceholderNote
            case .files: L10n.Workspace.filesPlaceholderNote
            }
        }

        var icon: PVSymbol {
            switch self {
            case .sources: .library
            case .sourceTypes: .tag
            case .sourceFields: .list
            case .files: .folderOpen
            }
        }
    }

    /// W-5: the researcher chooses this; it's never derived from window
    /// width. Persisted per install via `UserDefaults`, as the design brief
    /// suggests.
    private static let sidebarCollapsedDefaultsKey = "pv.sidebarCollapsed"

    var selectedSection: Section
    var isSidebarCollapsed: Bool
    /// Trailing nav-row counts, keyed by destination — absent (rather than
    /// `0`) until `refreshCounts()` succeeds for that section.
    var counts: [Section: Int] = [:]

    private let store: any GenealogyStore
    private let projectDir: String
    private let defaults: UserDefaults

    init(
        projectDir: String,
        store: any GenealogyStore,
        selectedSection: Section = .sources,
        defaults: UserDefaults = .standard
    ) {
        self.projectDir = projectDir
        self.store = store
        self.selectedSection = selectedSection
        self.defaults = defaults
        isSidebarCollapsed = defaults.bool(forKey: Self.sidebarCollapsedDefaultsKey)
    }

    func toggleSidebarCollapsed() {
        isSidebarCollapsed.toggle()
        defaults.set(isSidebarCollapsed, forKey: Self.sidebarCollapsedDefaultsKey)
    }

    /// Refreshes every section's nav-row count, **sequentially, not
    /// concurrently**: by design (`database.Catalog`'s own doc comment —
    /// "an exclusive connection to one provenencia.sqlite file"), every
    /// FFI call that touches project data opens its own `Catalog`, takes
    /// an OS-level `PRAGMA locking_mode=EXCLUSIVE` + `BEGIN IMMEDIATE`
    /// lock on the sqlite file for the call's duration, and releases it
    /// on close — WAL mode and a busy-timeout are configured (see
    /// `core/database/catalog.go`), but neither overrides an exclusive
    /// lock. So at most one call can be "inside" a project's catalog at
    /// once, on purpose — not a bug, but this session's `async let` for
    /// three simultaneous calls did reliably make two or three of them
    /// fail with a generic `internal.unknown` fighting over that lock.
    /// Awaiting one at a time respects it and avoided every failure in
    /// repeated manual testing.
    ///
    /// Each query is still independent (`try?`) so one failing doesn't
    /// blank out the others — a missing count badge is a fine degradation
    /// for what's decoration, not something worth surfacing as an error
    /// toast.
    ///
    /// Nothing else can mutate Source/type/field/file data yet
    /// (S2-15/16/17/18 aren't built), so a single refresh on the
    /// workspace appearing is enough for now — once those land, they
    /// should call this again after their own mutations rather than this
    /// becoming reactive.
    func refreshCounts() async {
        let sources = try? await store.listSources(projectDir: projectDir).count
        let sourceTypes = try? await store.listSourceTypes(projectDir: projectDir).count
        let sourceFields = try? await store.listMetadataFields(projectDir: projectDir).count
        let files = try? await store.countFiles(projectDir: projectDir)

        var next: [Section: Int] = [:]
        if let sources { next[.sources] = sources }
        if let sourceTypes { next[.sourceTypes] = sourceTypes }
        if let sourceFields { next[.sourceFields] = sourceFields }
        if let files { next[.files] = files }
        counts = next
    }
}
