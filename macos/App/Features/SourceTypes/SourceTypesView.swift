import SwiftUI

/// The **Source types** workspace destination (S2-03 board / S2-16 PR):
/// browse and search the project's `source_types` vocabulary, edit or delete
/// a type, and assign or remove the metadata fields it suggests. Mounts
/// inside the existing S2-01 workspace content host — see
/// `WorkspaceContent` — not a second window chrome.
///
/// Navigation choice (S2-03 T-13 leaves this open): a master–detail split,
/// not expand-in-list or a pushed detail. A type carries a description plus
/// a variable-length suggestions list, so expanding a row in place would
/// push the rest of the vocabulary off screen; and assigning fields is a
/// back-and-forth task that a push would make tedious. It is also what
/// Source fields already does, so the two vocabulary destinations behave
/// alike.
struct SourceTypesView: View {
    @State private var model: SourceTypesModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Detail pane width — between the web board's `minmax(340px, 400px)`
    /// column and `PVSpacing.widthInspector` (340pt); no shared token covers
    /// this exact range, so it's a local literal like `PVToast`'s own
    /// `frame(maxWidth: 360)`.
    private let detailPaneWidth: CGFloat = 380

    init(projectDir: String, userID: String, store: any GenealogyStore) {
        _model = State(initialValue: SourceTypesModel(projectDir: projectDir, userID: userID, store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            PVDivider()
            HStack(spacing: 0) {
                SourceTypesListPane(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                PVDivider(axis: .vertical)
                SourceTypesDetailPane(model: model)
                    .frame(width: detailPaneWidth)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PVColor.surfacePage)
        .overlay(alignment: .topTrailing) {
            if let toast = model.toast {
                PVToast(
                    tone: toast.tone,
                    title: toast.title,
                    message: toast.body,
                    onDismiss: { model.toast = nil }
                )
                .id(toast)
                .padding(PVSpacing.space8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .accessibilityIdentifier("sourceTypes.toast")
            }
        }
        .animation(reduceMotion ? nil : PVMotion.easeStandard, value: model.toast)
        .pvConfirmSheet(
            item: pendingDelete,
            copy: deleteCopy(for:),
            isRunning: model.isDeleting,
            onConfirm: { Task { await model.confirmDelete() } }
        ) { type in
            deleteDetail(for: type)
        }
        .task { await model.load() }
        .accessibilityIdentifier("sourceTypes")
    }

    /// Dismissal is driven by the model, not by the sheet: a successful delete
    /// clears `pendingDeleteID`, and a failed one keeps the sheet up with the
    /// reason (see `pvConfirmSheet`). The sheet renders its copy and detail
    /// from the type it receives — a snapshot `pvConfirmSheet` holds through
    /// the dismiss animation — never from `model.pendingDeleteType` live.
    private var pendingDelete: Binding<CatalogSourceType?> {
        Binding(
            get: { model.pendingDeleteType },
            set: { if $0 == nil { model.cancelDelete() } }
        )
    }

    private func deleteCopy(for type: CatalogSourceType) -> PVConfirmCopy {
        PVConfirmCopy(
            title: L10n.SourceTypes.deleteConfirmTitle(label: type.label),
            message: String(localized: L10n.SourceTypes.deleteConfirmMessage),
            confirm: L10n.SourceTypes.deleteType,
            cancel: L10n.SourceTypes.deleteKeep
        )
    }

    /// The consequence that earns this a sheet rather than a plain alert: the
    /// mono-set key the delete releases, plus the reason if it failed.
    @ViewBuilder
    private func deleteDetail(for type: CatalogSourceType) -> some View {
        PVConfirmKeyChip(label: L10n.SourceTypes.deleteKeyReleased, value: type.key)
            .accessibilityIdentifier("sourceTypes.delete.key")
        if let deleteError = model.deleteError {
            PVCallout(tone: .danger, message: deleteError)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: PVSpacing.space8) {
            VStack(alignment: .leading, spacing: PVSpacing.space2) {
                Text(L10n.Workspace.sourceTypesTitle)
                    .font(PVFont.display(size: PVTypeScale.h1))
                    .foregroundStyle(PVColor.textDisplay)
                Text(L10n.SourceTypes.description)
                    .font(PVFont.body(size: PVTypeScale.bodySmall))
                    .foregroundStyle(PVColor.textMuted)
                    .frame(maxWidth: PVSpacing.measureProse, alignment: .leading)
            }
            Spacer(minLength: PVSpacing.space6)
            HStack(spacing: PVSpacing.space6) {
                Text(model.countLine)
                    .font(PVFont.mono(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textMuted)
                    .accessibilityIdentifier("sourceTypes.countLine")
                PVButton(L10n.SourceTypes.addType, variant: .primary, icon: .plus) {
                    model.openAdd()
                }
                .disabled(model.isAdding)
                .accessibilityIdentifier("sourceTypes.addType")
            }
        }
        .padding(.horizontal, PVSpacing.gutterPage)
        .padding(.top, PVSpacing.space8)
        .padding(.bottom, PVSpacing.space6)
    }
}

#if DEBUG
#Preview {
    let store = FakeStore()
    let projectDir = "/tmp/preview.provenencia"
    store.fieldsByProject[projectDir] = [
        CatalogMetadataField(id: "f1", key: "author", origin: "provenencia", label: "Author", dataType: "text", description: "Person or body responsible for the content."),
        CatalogMetadataField(id: "f2", key: "publication-date", origin: "provenencia", label: "Publication date", dataType: "date", description: "Date the source was published."),
        CatalogMetadataField(id: "f3", key: "publisher", origin: "provenencia", label: "Publisher", dataType: "text", description: "Who issued it."),
        CatalogMetadataField(id: "f4", key: "grandmas-album-code", origin: "user", label: "Grandma's album code", dataType: "text", description: "Pencil code on the back of prints."),
    ]
    store.sourceTypesByProject[projectDir] = [
        CatalogSourceType(id: "t1", key: "photograph", origin: "provenencia", label: "Photograph", description: "A photographic image of people, places or objects.", usedBy: 41),
        CatalogSourceType(id: "t2", key: "book", origin: "provenencia", label: "Book", description: "A published monograph — county history, compiled genealogy, printed transcript.", usedBy: 18),
        CatalogSourceType(id: "t3", key: "letter", origin: "provenencia", label: "Letter", description: "Private correspondence, held as the original or as a later transcript.", usedBy: 0),
        CatalogSourceType(id: "t4", key: "family-scrapbook", origin: "user", label: "Family scrapbook", description: "Nan's albums — pasted prints, clippings and pencil captions.", usedBy: 3),
        CatalogSourceType(id: "t5", key: "grave-memorial", origin: "plugin:findagrave", label: "Grave memorial", description: "A memorial page assembled from headstone photographs.", usedBy: 5),
    ]
    store.suggestionsByType["t2"] = [
        CatalogTypeSuggestion(field: store.fieldsByProject[projectDir]![0], sortOrder: 0),
        CatalogTypeSuggestion(field: store.fieldsByProject[projectDir]![2], sortOrder: 1),
        CatalogTypeSuggestion(field: store.fieldsByProject[projectDir]![1], sortOrder: 2),
    ]
    store.suggestionsByType["t4"] = [
        CatalogTypeSuggestion(field: store.fieldsByProject[projectDir]![3], sortOrder: 0),
    ]
    return SourceTypesView(projectDir: projectDir, userID: "00000000-0000-7000-8000-000000000001", store: store)
        .frame(width: 1180, height: 760)
}
#endif
