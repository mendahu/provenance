import SwiftUI

/// `source_credibility_grades.key` namespace — mirrors the seeded keys in
/// `core/database/sourcecredibilitygrades` (FFI carries them as plain
/// strings). Shared Catalog shelf so Source page chrome and any future
/// credibility UI stay on one vocabulary.
enum CatalogCredibility {
    static let lowTrust = "low_trust"
    static let standard = "standard"
    static let highTrust = "high_trust"

    /// Maps a grade key onto generic `PVChip` tones. Not evidence-grade
    /// colors (proven/probable/…) — source credibility is a different axis.
    static func chipTone(for key: String) -> PVChip.Tone {
        switch key {
        case lowTrust: return .danger
        case highTrust: return .success
        default: return .accent
        }
    }

    /// Dashed chrome for the default Standard chip before any assessment
    /// has been saved.
    static func isDashedUnset(key: String, hasSavedAssessment: Bool, draftKey: String) -> Bool {
        key == standard && !hasSavedAssessment && draftKey == standard
    }
}
