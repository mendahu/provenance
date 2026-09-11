import SwiftUI

/// Individual Source page (S2-18): breadcrumb, identity, credibility, Artifacts
/// accordion, Notes. Metadata editor is S2-25.
struct SourcePageView: View {
    @State private var model: SourcePageModel
    let onBackToList: () -> Void

    init(
        sourceID: String,
        projectDir: String,
        userID: String,
        store: any GenealogyStore,
        onBackToList: @escaping () -> Void,
        onSourceUpdated: ((CatalogSource) -> Void)? = nil
    ) {
        _model = State(
            initialValue: SourcePageModel(
                sourceID: sourceID,
                projectDir: projectDir,
                userID: userID,
                store: store,
                onSourceUpdated: onSourceUpdated
            )
        )
        self.onBackToList = onBackToList
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PVSpacing.space9) {
                breadcrumbs
                if model.isLoading && model.workspace == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, PVSpacing.space9)
                } else if let loadError = model.loadError, model.workspace == nil {
                    PVCallout(tone: .danger, message: L10n.Errors.message(for: loadError))
                } else {
                    identitySection
                    credibilitySection
                    artifactsSection
                    notesSection
                }
            }
            .padding(.horizontal, PVSpacing.gutterPage)
            .padding(.top, PVSpacing.space8)
            .padding(.bottom, PVSpacing.space10)
            .frame(maxWidth: PVSpacing.measureForm + 160, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PVColor.surfacePage)
        .vocabularyToastOverlay($model.toast, identifier: "sources.page.toast")
        .pvDialog(
            isPresented: addArtifactPresented,
            copy: PVDialogCopy(
                title: L10n.Sources.addArtifactDialogTitle,
                subtitle: L10n.Sources.addArtifactDialogSubtitle,
                confirm: L10n.Sources.addArtifactConfirm,
                cancel: L10n.Sources.cancelAction
            ),
            isRunning: model.isSavingArtifact,
            confirmDisabled: !model.canSubmitArtifact,
            onConfirm: { Task { await model.createArtifact() } }
        ) {
            addArtifactForm
        }
        .task { await model.load() }
        .accessibilityIdentifier("sources.page")
    }

    private var addArtifactPresented: Binding<Bool> {
        Binding(
            get: { model.isAddingArtifact },
            set: { presented in
                if presented {
                    model.openAddArtifact()
                } else {
                    model.cancelAddArtifact()
                }
            }
        )
    }

    private var breadcrumbs: some View {
        PVBreadcrumbs(items: [
            PVBreadcrumbItem(
                id: "sources",
                label: String(localized: L10n.Sources.breadcrumbSources),
                action: onBackToList
            ),
            PVBreadcrumbItem(
                id: "ref",
                label: model.source?.ref ?? "…",
                action: nil
            ),
        ])
        .accessibilityIdentifier("sources.page.breadcrumbs")
    }

    // MARK: Identity

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            TextField(
                "",
                text: $model.title,
                prompt: Text(L10n.Sources.formTitle),
                axis: .vertical
            )
            .font(PVFont.display(size: PVTypeScale.h1, weight: PVFontWeight.semibold))
            .foregroundStyle(PVColor.textDisplay)
            .textFieldStyle(.plain)
            .lineLimit(1...4)
            .accessibilityIdentifier("sources.page.title")
            .onChange(of: model.title) { _, _ in model.titleError = nil }
            .onSubmit { Task { await model.saveIdentity() } }

            if let titleError = model.titleError {
                Text(titleError)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.danger)
            }

            HStack(alignment: .firstTextBaseline, spacing: PVSpacing.space5) {
                PVComboBox(
                    selection: $model.sourceTypeID,
                    options: model.typeComboOptions,
                    placeholder: L10n.Sources.typePlaceholder,
                    emptyLabel: L10n.Sources.typeNoMatch,
                    label: L10n.Sources.pageFormType,
                    accessibilityIdentifierPrefix: "sources.page.type"
                )
                .frame(maxWidth: 280)
                .onChange(of: model.sourceTypeID) { _, _ in
                    Task { await model.saveIdentity() }
                }

                if let ref = model.source?.ref {
                    Text(ref)
                        .font(PVFont.mono(size: PVTypeScale.caption))
                        .foregroundStyle(PVColor.textMuted)
                        .accessibilityIdentifier("sources.page.ref")
                }
            }

            TextField(
                "",
                text: $model.description,
                prompt: Text(L10n.Sources.descriptionPlaceholder),
                axis: .vertical
            )
            .font(PVFont.body(size: PVTypeScale.body))
            .foregroundStyle(PVColor.textSecondary)
            .textFieldStyle(.plain)
            .lineLimit(2...8)
            .accessibilityIdentifier("sources.page.description")
            .onSubmit { Task { await model.saveIdentity() } }
        }
        .onChange(of: model.title) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                await model.saveIdentity()
            }
        }
        .onChange(of: model.description) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                await model.saveIdentity()
            }
        }
    }

    // MARK: Credibility

    private var credibilitySection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            Text(L10n.Sources.credibilityHeading)
                .font(PVFont.display(size: PVTypeScale.h3, weight: PVFontWeight.semibold))
                .foregroundStyle(PVColor.textDisplay)

            HStack(spacing: PVSpacing.space4) {
                ForEach(model.grades, id: \.id) { grade in
                    credibilityChip(grade)
                }
            }
            .accessibilityIdentifier("sources.page.credibility.grades")

            PVInput(
                text: $model.credibilityArgument,
                size: .sm,
                prompt: L10n.Sources.credibilityArgumentPlaceholder
            )
            .accessibilityIdentifier("sources.page.credibility.argument")
            .onSubmit { Task { await model.saveCredibilityArgument() } }
            .onChange(of: model.credibilityArgument) { _, _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    await model.saveCredibilityArgument()
                }
            }

            Text(L10n.Sources.credibilityHint)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textMuted)
                .frame(maxWidth: PVSpacing.measureProse, alignment: .leading)
        }
    }

    private func credibilityChip(_ grade: CatalogCredibilityGrade) -> some View {
        let selected = model.credibilityKey == grade.key
        let colors = credibilityColors(for: grade.key)
        return Button {
            Task { await model.selectCredibility(key: grade.key) }
        } label: {
            Text(grade.label)
                .font(PVFont.body(size: PVTypeScale.caption, weight: PVFontWeight.medium))
                .foregroundStyle(selected ? colors.fg : PVColor.textSecondary)
                .padding(.horizontal, PVSpacing.space5)
                .padding(.vertical, PVSpacing.space3)
                .background(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .fill(selected ? colors.bg : PVColor.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .stroke(selected ? colors.fg.opacity(0.35) : PVColor.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sources.page.credibility.\(grade.key)")
    }

    private func credibilityColors(for key: String) -> (bg: Color, fg: Color) {
        switch key {
        case "low_trust":
            return (PVColor.dangerSoft, PVColor.danger)
        case "high_trust":
            return (PVColor.successSoft, PVColor.success)
        default:
            return (PVColor.accentSoft, PVColor.accent)
        }
    }

    // MARK: Artifacts

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            HStack(alignment: .center) {
                Text(L10n.Sources.artifactsHeading)
                    .font(PVFont.display(size: PVTypeScale.h3, weight: PVFontWeight.semibold))
                    .foregroundStyle(PVColor.textDisplay)
                Spacer(minLength: 0)
                PVButton(L10n.Sources.addArtifact, variant: .primary, size: .sm, icon: .plus) {
                    model.openAddArtifact()
                }
                .accessibilityIdentifier("sources.page.addArtifact")
            }

            if model.artifacts.isEmpty {
                PVEmptyState(
                    icon: .photo,
                    title: L10n.Sources.artifactsEmptyTitle,
                    message: String(localized: L10n.Sources.artifactsEmptyMessage),
                    compact: true
                )
                .accessibilityIdentifier("sources.page.artifacts.empty")
            } else {
                VStack(spacing: 0) {
                    ForEach(model.artifacts, id: \.id) { art in
                        artifactRow(art)
                        if art.id != model.artifacts.last?.id {
                            PVDivider()
                        }
                    }
                }
                .background(PVColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous)
                        .stroke(PVColor.borderSubtle, lineWidth: 1)
                )
                .accessibilityIdentifier("sources.page.artifacts.list")
            }
        }
    }

    private func artifactRow(_ art: CatalogArtifact) -> some View {
        let expanded = model.expandedArtifactIDs.contains(art.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                model.toggleArtifactExpanded(art.id)
            } label: {
                HStack(spacing: PVSpacing.space6) {
                    PVThumbnail(.empty, size: 44)
                    Text(art.label.isEmpty ? art.ref : art.label)
                        .font(PVFont.body(size: PVTypeScale.bodySmall))
                        .foregroundStyle(PVColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(art.ref)
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.textMuted)
                    PVIcon(.chevronDown, size: 11)
                        .foregroundStyle(PVColor.textFaint)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .padding(.horizontal, PVSpacing.space6)
                .padding(.vertical, PVSpacing.space5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sources.page.artifact.\(art.id)")

            if expanded {
                artifactDetail(art)
                    .padding(.horizontal, PVSpacing.space6)
                    .padding(.bottom, PVSpacing.space6)
            }
        }
    }

    private func artifactDetail(_ art: CatalogArtifact) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVField(
                label: L10n.Sources.artifactLabel,
                hint: L10n.Sources.artifactLabelHint,
                required: true
            ) {
                PVInput(
                    text: Binding(
                        get: { model.artifactLabels[art.id] ?? art.label },
                        set: { model.artifactLabels[art.id] = $0 }
                    ),
                    size: .sm
                )
                .onSubmit { Task { await model.saveArtifactFields(id: art.id) } }
            }
            PVField(
                label: L10n.Sources.artifactDescription,
                hint: L10n.Sources.artifactDescriptionHint
            ) {
                PVInput(
                    text: Binding(
                        get: { model.artifactDescriptions[art.id] ?? art.description },
                        set: { model.artifactDescriptions[art.id] = $0 }
                    ),
                    size: .sm
                )
                .onSubmit { Task { await model.saveArtifactFields(id: art.id) } }
            }

            if let file = art.file, !art.fileID.isEmpty {
                HStack(spacing: PVSpacing.space6) {
                    VStack(alignment: .leading, spacing: PVSpacing.space2) {
                        Text(file.originalFilename)
                            .font(PVFont.body(size: PVTypeScale.bodySmall, weight: PVFontWeight.medium))
                            .foregroundStyle(PVColor.textPrimary)
                        Text(fileMetaLine(file))
                            .font(PVFont.mono(size: PVTypeScale.micro))
                            .foregroundStyle(PVColor.textMuted)
                    }
                    Spacer(minLength: 0)
                    PVButton(L10n.Sources.openFile, variant: .secondary, size: .sm, icon: .externalLink) {
                        model.openArtifactFile(art)
                    }
                    .accessibilityIdentifier("sources.page.artifact.\(art.id).open")
                }
                .padding(PVSpacing.space6)
                .background(PVColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .stroke(PVColor.borderSubtle, lineWidth: 1)
                )

                Text(L10n.Sources.openFileCaption)
                    .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                    .foregroundStyle(PVColor.textMuted)
            } else {
                Text(L10n.Sources.filelessHint)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
                PVButton(L10n.Sources.addFile, variant: .primary, size: .sm, icon: .fileUp) {
                    Task { await model.addFile(toArtifactID: art.id) }
                }
                .accessibilityIdentifier("sources.page.artifact.\(art.id).addFile")
            }

            if let pageError = model.pageError {
                PVCallout(tone: .danger, message: pageError)
            }
        }
        .padding(.top, PVSpacing.space4)
    }

    private func fileMetaLine(_ file: CatalogFileRef) -> String {
        let size = ByteCountFormatter.string(fromByteCount: file.byteSize, countStyle: .file)
        return "\(file.mediaType) · \(size)"
    }

    // MARK: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            Text(L10n.Sources.notesHeading)
                .font(PVFont.display(size: PVTypeScale.h3, weight: PVFontWeight.semibold))
                .foregroundStyle(PVColor.textDisplay)

            ForEach(model.notes, id: \.id) { note in
                SourcePageNoteRow(
                    note: note,
                    onCommit: { body in
                        Task { await model.updateNote(id: note.id, body: body) }
                    },
                    onDelete: {
                        Task { await model.deleteNote(id: note.id) }
                    }
                )
            }

            VStack(alignment: .trailing, spacing: PVSpacing.space4) {
                PVInput(
                    text: $model.noteDraft,
                    size: .sm,
                    prompt: L10n.Sources.notePlaceholder
                )
                .accessibilityIdentifier("sources.page.noteDraft")
                PVButton(
                    L10n.Sources.addNote,
                    variant: .secondary,
                    size: .sm,
                    icon: .plus,
                    loading: model.isSavingNote
                ) {
                    Task { await model.addNote() }
                }
                .disabled(model.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("sources.page.addNote")
            }
        }
    }

    // MARK: Add Artifact form

    private var addArtifactForm: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVField(
                label: L10n.Sources.artifactLabel,
                hint: L10n.Sources.artifactLabelHint,
                error: model.artifactLabelError,
                required: true
            ) {
                PVInput(
                    text: $model.artifactDraft.label,
                    isInvalid: model.artifactLabelError != nil
                )
                .accessibilityIdentifier("sources.page.addArtifact.label")
            }
            PVField(
                label: L10n.Sources.artifactDescription,
                hint: L10n.Sources.formDescriptionHint
            ) {
                PVInput(text: $model.artifactDraft.description)
                    .accessibilityIdentifier("sources.page.addArtifact.description")
            }
            PVField(label: L10n.Sources.optionalFile) {
                HStack(spacing: PVSpacing.space4) {
                    if let name = model.artifactDraft.fileName {
                        Text(name)
                            .font(PVFont.mono(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.textPrimary)
                            .lineLimit(1)
                        PVButton(L10n.Sources.clearFile, variant: .ghost, size: .sm) {
                            model.clearArtifactFile()
                        }
                    } else {
                        PVButton(L10n.Sources.chooseFile, variant: .secondary, size: .sm, icon: .fileUp) {
                            model.pickArtifactFile()
                        }
                        .accessibilityIdentifier("sources.page.addArtifact.chooseFile")
                    }
                }
            }
        }
    }
}

private struct SourcePageNoteRow: View {
    let note: CatalogSourceNote
    let onCommit: (String) -> Void
    let onDelete: () -> Void
    @State private var bodyText: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: PVSpacing.space4) {
            TextField("", text: $bodyText, axis: .vertical)
                .font(PVFont.body(size: PVTypeScale.bodySmall))
                .foregroundStyle(PVColor.textSecondary)
                .textFieldStyle(.plain)
                .lineLimit(1...12)
                .accessibilityIdentifier("sources.page.note.\(note.id)")
                .onAppear { bodyText = note.body }
                .onChange(of: note.body) { _, newValue in
                    if bodyText != newValue { bodyText = newValue }
                }
                .onSubmit { onCommit(bodyText) }
                .onChange(of: bodyText) { _, newValue in
                    guard newValue != note.body else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        if bodyText == newValue {
                            onCommit(newValue)
                        }
                    }
                }

            PVIconButton(.trash, label: L10n.Sources.deleteNote, size: .sm, tone: .danger) {
                onDelete()
            }
            .accessibilityIdentifier("sources.page.note.\(note.id).delete")
        }
        .padding(.vertical, PVSpacing.space3)
    }
}
