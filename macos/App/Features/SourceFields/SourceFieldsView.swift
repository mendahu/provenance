import SwiftUI

/// The **Source fields** workspace destination (S2-02 board / S2-15 PR):
/// browse, search, and create/edit the project's `source_metadata_fields`
/// vocabulary. Mounts inside the existing S2-01 workspace content host —
/// see `WorkspaceContent` — not a second window chrome.
///
/// Chrome choice for add/edit (S2-02 F-18 leaves this open): a nested
/// detail pane beside the list, not a modal/sheet. It keeps the
/// researcher's place in the list while filling out the form and matches
/// the density of the rest of the workspace.
struct SourceFieldsView: View {
    @State private var model: SourceFieldsModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Detail pane width — between the web board's `minmax(360px, 420px)`
    /// column and `PVSpacing.widthInspector` (340pt); no shared token
    /// covers this exact range, so it's a local literal like
    /// `PVToast`'s own `frame(maxWidth: 360)`.
    private let detailPaneWidth: CGFloat = 380

    init(projectDir: String, userID: String, store: any GenealogyStore) {
        _model = State(initialValue: SourceFieldsModel(projectDir: projectDir, userID: userID, store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            PVDivider()
            HStack(spacing: 0) {
                SourceFieldsListPane(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                PVDivider(axis: .vertical)
                SourceFieldsDetailPane(model: model)
                    .frame(width: detailPaneWidth)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PVColor.surfacePage)
        .overlay(alignment: .topTrailing) {
            if let toast = model.toast {
                PVToast(
                    tone: .success,
                    title: toast.title,
                    message: toast.body,
                    onDismiss: { model.toast = nil }
                )
                .id(toast)
                .padding(PVSpacing.space8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .accessibilityIdentifier("sourceFields.toast")
            }
        }
        .animation(reduceMotion ? nil : PVMotion.easeStandard, value: model.toast)
        .pvConfirmSheet(
            item: pendingDelete,
            copy: deleteCopy(for:),
            isRunning: model.isDeleting,
            onConfirm: { Task { await model.confirmDelete() } }
        ) { field in
            deleteDetail(for: field)
        }
        .task { await model.load() }
        .accessibilityIdentifier("sourceFields")
    }

    /// Dismissal is driven by the model, not by the sheet: a successful delete
    /// clears `pendingDeleteID`, and a failed one keeps the sheet up with the
    /// reason (see `pvConfirmSheet`). The sheet renders its copy and detail
    /// from the field it receives — a snapshot `pvConfirmSheet` holds through
    /// the dismiss animation — never from `model.pendingDeleteField` live.
    private var pendingDelete: Binding<CatalogMetadataField?> {
        Binding(
            get: { model.pendingDeleteField },
            set: { if $0 == nil { model.cancelDelete() } }
        )
    }

    private func deleteCopy(for field: CatalogMetadataField) -> PVConfirmCopy {
        PVConfirmCopy(
            title: L10n.SourceFields.deleteConfirmTitle(label: field.label),
            message: String(localized: L10n.SourceFields.deleteConfirmMessage),
            confirm: L10n.SourceFields.deleteField,
            cancel: L10n.SourceFields.deleteKeep
        )
    }

    /// The consequence that earns this a sheet rather than a plain alert: the
    /// mono-set key the delete releases, plus the reason if it failed.
    @ViewBuilder
    private func deleteDetail(for field: CatalogMetadataField) -> some View {
        PVConfirmKeyChip(label: L10n.SourceFields.deleteKeyReleased, value: field.key)
            .accessibilityIdentifier("sourceFields.delete.key")
        if let deleteError = model.deleteError {
            PVCallout(tone: .danger, message: deleteError)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: PVSpacing.space8) {
            VStack(alignment: .leading, spacing: PVSpacing.space2) {
                Text(L10n.Workspace.sourceFieldsTitle)
                    .font(PVFont.display(size: PVTypeScale.h1))
                    .foregroundStyle(PVColor.textDisplay)
                Text(L10n.SourceFields.description)
                    .font(PVFont.body(size: PVTypeScale.bodySmall))
                    .foregroundStyle(PVColor.textMuted)
                    .frame(maxWidth: PVSpacing.measureProse, alignment: .leading)
            }
            Spacer(minLength: PVSpacing.space6)
            HStack(spacing: PVSpacing.space6) {
                Text(model.countLine)
                    .font(PVFont.mono(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textMuted)
                    .accessibilityIdentifier("sourceFields.countLine")
                PVButton(L10n.SourceFields.addField, variant: .primary, icon: .plus) {
                    model.openAdd()
                }
                .disabled(model.isAdding)
                .accessibilityIdentifier("sourceFields.addField")
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
        CatalogMetadataField(id: "1", key: "author", origin: "provenencia", label: "Author", dataType: "text", description: "Person or body responsible for the content of the source."),
        CatalogMetadataField(id: "2", key: "publication-date", origin: "provenencia", label: "Publication date", dataType: "date", description: "Date the source was published."),
        CatalogMetadataField(id: "3", key: "grandmas-album-code", origin: "user", label: "Grandma's album code", dataType: "text", description: "Pencil code on the back of prints."),
        CatalogMetadataField(id: "4", key: "memorial-id", origin: "plugin:findagrave", label: "Memorial id", dataType: "text", description: "Numeric memorial identifier."),
    ]
    return SourceFieldsView(projectDir: projectDir, userID: "00000000-0000-7000-8000-000000000001", store: store)
        .frame(width: 1180, height: 760)
}
#endif
