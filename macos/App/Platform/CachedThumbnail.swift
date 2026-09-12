import SwiftUI

/// Loads a project object thumbnail through `ThumbnailCache` and feeds
/// `PVThumbnail` (empty / loading / image). Features should not call
/// `NSImage(contentsOf:)` on the render path.
struct CachedThumbnail: View {
    let projectDir: String
    let relPath: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = PVRadius.sm

    @State private var content: PVThumbnail.Content = .empty

    var body: some View {
        PVThumbnail(content, size: size, cornerRadius: cornerRadius)
            .task(id: taskID) {
                await load()
            }
    }

    private var taskID: String {
        "\(projectDir)\0\(relPath)"
    }

    private func load() async {
        let trimmed = relPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            content = .empty
            return
        }
        content = PVThumbnail.Content(loading: true)
        if let nsImage = await ThumbnailCache.shared.image(
            projectDir: projectDir,
            relPath: trimmed
        ) {
            content = PVThumbnail.Content(image: Image(nsImage: nsImage))
        } else {
            content = .empty
        }
    }
}
