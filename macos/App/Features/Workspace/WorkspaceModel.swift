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

    private let defaults: UserDefaults

    init(selectedSection: Section = .sources, defaults: UserDefaults = .standard) {
        self.selectedSection = selectedSection
        self.defaults = defaults
        isSidebarCollapsed = defaults.bool(forKey: Self.sidebarCollapsedDefaultsKey)
    }

    func toggleSidebarCollapsed() {
        isSidebarCollapsed.toggle()
        defaults.set(isSidebarCollapsed, forKey: Self.sidebarCollapsedDefaultsKey)
    }
}
