import SwiftUI

/// Individual Source page (S2-18 / S2-25): breadcrumb, identity, Description +
/// Credibility beside Metadata, Artifacts accordion, Notes.
struct SourcePageView: View {
    @State private var model: SourcePageModel
    let onBackToList: () -> Void

    init(
        sourceID: String,
        projectDir: String,
        userID: String,
        sessionDisplayName: String = "",
        store: any GenealogyStore,
        onBackToList: @escaping () -> Void,
        onSourceUpdated: ((CatalogSource) -> Void)? = nil
    ) {
        _model = State(
            initialValue: SourcePageModel(
                sourceID: sourceID,
                projectDir: projectDir,
                userID: userID,
                sessionDisplayName: sessionDisplayName,
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
                    overviewColumns
                    artifactsSection
                    notesSection
                }
            }
            .padding(.horizontal, PVSpacing.gutterPage)
            .padding(.top, PVSpacing.space8)
            .padding(.bottom, PVSpacing.space10)
            // Fill the pane so the ScrollView scrollbar sits on the trailing
            // edge — a maxWidth on this stack alone shrinks the scroll view.
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .pvDialog(
            isPresented: addMetadataPresented,
            copy: PVDialogCopy(
                title: L10n.Sources.addMetadataDialogTitle,
                subtitle: L10n.Sources.addMetadataDialogSubtitle,
                confirm: L10n.Sources.addMetadataConfirm,
                cancel: L10n.Sources.cancelAction
            ),
            isRunning: model.isSavingMetadataAdd,
            confirmDisabled: !model.canSubmitMetadataAdd,
            onConfirm: { Task { await model.createMetadataFromAdd() } }
        ) {
            addMetadataForm
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

    private var addMetadataPresented: Binding<Bool> {
        Binding(
            get: { model.isAddingMetadata },
            set: { presented in
                if presented {
                    model.openAddMetadata()
                } else {
                    model.cancelAddMetadata()
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
        }
        .onChange(of: model.title) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                await model.saveIdentity()
            }
        }
    }

    /// Board: Description + Credibility | Metadata.
    /// LazyVGrid wraps below ~900pt (sidebar + gutters leave ~1060 at a 1366 window).
    private var overviewColumns: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 400), spacing: PVSpacing.space11, alignment: .top),
                GridItem(.flexible(minimum: 480), spacing: PVSpacing.space11, alignment: .top),
            ],
            alignment: .leading,
            spacing: PVSpacing.space10
        ) {
            descriptionAndCredibility
            metadataSection
        }
    }

    private var descriptionAndCredibility: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space10) {
            descriptionSection
            credibilitySection
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            sectionHeader(title: L10n.Sources.descriptionHeading)
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
            .onChange(of: model.description) { _, _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    await model.saveIdentity()
                }
            }
        }
    }

    // MARK: Credibility

    private var credibilitySection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            sectionHeader(
                title: L10n.Sources.credibilityHeading,
                aside: {
                    Text(L10n.Sources.credibilityHint)
                        .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                        .foregroundStyle(PVColor.textMuted)
                        .lineLimit(2)
                }
            )

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

    // MARK: Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            sectionHeader(
                title: L10n.Sources.metadataHeading,
                meta: model.savedMetadata.isEmpty
                    ? nil
                    : "\(model.savedMetadata.count)",
                actions: {
                    PVButton(L10n.Sources.addMetadata, variant: .primary, size: .sm, icon: .plus) {
                        model.openAddMetadata()
                    }
                    .accessibilityIdentifier("sources.page.addMetadata")
                }
            )

            Text(L10n.Sources.metadataIntro)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textMuted)
                .frame(maxWidth: PVSpacing.measureProse, alignment: .leading)

            if model.savedMetadata.isEmpty, model.suggestedMetadata.isEmpty {
                Text(L10n.Sources.metadataEmptyMessage)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
                    .accessibilityIdentifier("sources.page.metadata.empty")
            } else {
                if !model.savedMetadata.isEmpty {
                    PVReorderableList(items: model.savedMetadata, onMove: { source, destination in
                        Task { await model.moveSavedMetadata(from: source, to: destination) }
                    }) { entry in
                        savedMetadataRow(entry)
                    }
                    .frame(height: CGFloat(model.savedMetadata.count) * 44)
                    .scrollDisabled(true)
                    .accessibilityIdentifier("sources.page.metadata.list")
                }

                if !model.suggestedMetadata.isEmpty {
                    VStack(alignment: .leading, spacing: PVSpacing.space4) {
                        Text(L10n.Sources.metadataSuggestionsHeading)
                            .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                            .tracking(PVTypeScale.micro * PVTracking.caps)
                            .textCase(.uppercase)
                            .foregroundStyle(PVColor.textFaint)
                            .padding(.top, model.savedMetadata.isEmpty ? 0 : PVSpacing.space7)

                        ForEach(model.suggestedMetadata) { entry in
                            suggestionMetadataRow(entry)
                        }
                    }
                    .accessibilityIdentifier("sources.page.metadata.suggestions")
                }
            }
        }
    }

    private func savedMetadataRow(_ entry: CatalogMetadataEntry) -> some View {
        let fieldID = entry.field.id
        return HStack(spacing: PVSpacing.space5) {
            PVReorderHandle()
            Text(entry.field.label)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textMuted)
                .frame(width: 170, alignment: .leading)
            PVInput(
                text: Binding(
                    get: { model.metadataDrafts[fieldID] ?? entry.valueText },
                    set: { model.metadataDrafts[fieldID] = $0 }
                ),
                size: .sm,
                mono: true
            )
            .onSubmit { Task { await model.saveMetadataValue(fieldID: fieldID) } }
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

            metadataTypeBadge(entry.field.dataType)
        }
        .padding(.vertical, PVSpacing.space3)
        .padding(.horizontal, PVSpacing.space4)
    }

    private func suggestionMetadataRow(_ entry: CatalogMetadataEntry) -> some View {
        let fieldID = entry.field.id
        return HStack(spacing: PVSpacing.space5) {
            Text(entry.field.label)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textMuted)
                .frame(width: 170, alignment: .leading)
                .padding(.leading, 20)
            PVInput(
                text: Binding(
                    get: { model.metadataDrafts[fieldID] ?? "" },
                    set: { model.metadataDrafts[fieldID] = $0 }
                ),
                size: .sm,
                mono: true,
                prompt: L10n.Sources.metadataSuggestionPlaceholder
            )
            .onSubmit { Task { await model.saveMetadataValue(fieldID: fieldID) } }
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

            PVButton(
                L10n.Sources.saveMetadataSuggestion,
                variant: .ghost,
                size: .sm,
                loading: model.savingMetadataFieldID == fieldID
            ) {
                Task { await model.saveMetadataValue(fieldID: fieldID) }
            }
            .disabled(
                (model.metadataDrafts[fieldID] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).save")

            PVIconButton(.dismiss, label: L10n.Sources.dismissMetadataSuggestion, size: .sm) {
                Task { await model.dismissMetadataSuggestion(fieldID: fieldID) }
            }
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).dismiss")
        }
        .padding(.vertical, PVSpacing.space4)
        .padding(.horizontal, PVSpacing.space5)
        .background(PVColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(PVColor.borderDefault)
        )
    }

    @ViewBuilder
    private func metadataTypeBadge(_ dataType: String) -> some View {
        if dataType == "date" {
            PVBadge(L10n.SourceFields.dataTypeDate, tone: .info, icon: .calendar, subtle: true)
        } else {
            PVBadge(L10n.SourceFields.dataTypeText, tone: .neutral, icon: .textType, subtle: true)
        }
    }

    private var addMetadataForm: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVField(
                label: L10n.Sources.metadataField,
                hint: L10n.Sources.metadataFieldHint,
                error: model.addMetadataFieldError,
                required: true
            ) {
                PVComboBox(
                    selection: $model.addMetadataFieldID,
                    options: model.metadataFieldComboOptions,
                    placeholder: L10n.Sources.metadataField,
                    emptyLabel: L10n.Sources.typeNoMatch,
                    isInvalid: model.addMetadataFieldError != nil,
                    label: L10n.Sources.metadataField,
                    accessibilityIdentifierPrefix: "sources.page.addMetadata.field"
                )
                .onChange(of: model.addMetadataFieldID) { _, newValue in
                    if !newValue.isEmpty { model.addMetadataFieldError = nil }
                }
            }
            PVField(
                label: L10n.Sources.metadataValue,
                hint: L10n.Sources.metadataValueHint,
                error: model.addMetadataValueError,
                required: true
            ) {
                PVInput(
                    text: $model.addMetadataValue,
                    isInvalid: model.addMetadataValueError != nil
                )
                .onChange(of: model.addMetadataValue) { _, _ in
                    model.addMetadataValueError = nil
                }
            }
        }
    }

    // MARK: Section chrome

    private func sectionHeader<Aside: View, Actions: View>(
        title: LocalizedStringResource,
        meta: String? = nil,
        @ViewBuilder aside: () -> Aside = { EmptyView() },
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PVSpacing.space5) {
            Text(title)
                .font(PVFont.display(size: PVTypeScale.h3, weight: PVFontWeight.semibold))
                .foregroundStyle(PVColor.textDisplay)
            if let meta {
                Text(meta)
                    .font(PVFont.mono(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
            }
            aside()
            Spacer(minLength: 0)
            actions()
        }
        .padding(.bottom, PVSpacing.space4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PVColor.borderDefault)
                .frame(height: 1)
        }
    }

    // MARK: Artifacts

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            sectionHeader(
                title: L10n.Sources.artifactsHeading,
                meta: model.artifacts.isEmpty ? nil : "\(model.artifacts.count)",
                actions: {
                    PVButton(L10n.Sources.addArtifact, variant: .primary, size: .sm, icon: .plus) {
                        model.openAddArtifact()
                    }
                    .accessibilityIdentifier("sources.page.addArtifact")
                }
            )

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
        .padding(.top, PVSpacing.space11 - PVSpacing.space9)
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
            }
        }
    }

    private func artifactDetail(_ art: CatalogArtifact) -> some View {
        HStack(alignment: .top, spacing: PVSpacing.space8) {
            artifactFieldsColumn(art)
                .frame(minWidth: 280, maxWidth: .infinity, alignment: .leading)
            artifactPrimaryFileColumn(art)
                .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, PVSpacing.space7)
        .padding(.trailing, PVSpacing.space8)
        .padding(.bottom, PVSpacing.space8)
        .padding(.leading, 62)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PVColor.surfaceSunken)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PVColor.borderSubtle)
                .frame(height: 1)
        }
    }

    private func artifactFieldsColumn(_ art: CatalogArtifact) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVField(
                label: L10n.Sources.artifactLabel,
                hint: L10n.Sources.artifactLabelHint,
                error: model.artifactFieldErrors[art.id],
                required: true
            ) {
                PVInput(
                    text: Binding(
                        get: { model.artifactLabels[art.id] ?? art.label },
                        set: {
                            model.artifactLabels[art.id] = $0
                            model.artifactFieldErrors[art.id] = nil
                        }
                    ),
                    size: .sm,
                    isInvalid: model.artifactFieldErrors[art.id] != nil
                )
                .onSubmit { Task { await model.saveArtifactFields(id: art.id) } }
            }

            PVField(
                label: L10n.Sources.artifactDescription,
                hint: L10n.Sources.artifactDescriptionHint
            ) {
                TextField(
                    "",
                    text: Binding(
                        get: { model.artifactDescriptions[art.id] ?? art.description },
                        set: { model.artifactDescriptions[art.id] = $0 }
                    ),
                    axis: .vertical
                )
                .font(PVFont.body(size: PVTypeScale.bodySmall))
                .foregroundStyle(PVColor.textPrimary)
                .textFieldStyle(.plain)
                .lineLimit(3...8)
                .padding(.horizontal, PVInputChrome.horizontalInset)
                .padding(.vertical, PVSpacing.space4)
                .background(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .fill(PVColor.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .stroke(PVColor.borderDefault, lineWidth: 1)
                )
                .accessibilityIdentifier("sources.page.artifact.\(art.id).description")
                .onSubmit { Task { await model.saveArtifactFields(id: art.id) } }
            }

            HStack {
                Spacer(minLength: 0)
                PVButton(
                    L10n.Sources.saveArtifact,
                    variant: .primary,
                    size: .sm,
                    loading: model.savingArtifactID == art.id
                ) {
                    Task { await model.saveArtifactFields(id: art.id) }
                }
                .disabled(!model.canSaveArtifactFields(art.id) && model.savingArtifactID != art.id)
                .accessibilityIdentifier("sources.page.artifact.\(art.id).save")
            }

            if let pageError = model.pageError {
                PVCallout(tone: .danger, message: pageError)
            }
        }
    }

    private func artifactPrimaryFileColumn(_ art: CatalogArtifact) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space4) {
            Text(L10n.Sources.primaryFileHeading)
                .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                .tracking(PVTypeScale.micro * PVTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(PVColor.textFaint)

            if let file = art.file, !art.fileID.isEmpty {
                HStack(spacing: PVSpacing.space6) {
                    PVThumbnail(.empty, size: 56)
                    VStack(alignment: .leading, spacing: PVSpacing.space2) {
                        Text(file.originalFilename)
                            .font(PVFont.mono(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.textPrimary)
                            .lineLimit(2)
                        Text(fileMetaLine(file))
                            .font(PVFont.mono(size: PVTypeScale.micro))
                            .foregroundStyle(PVColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PVButton(L10n.Sources.openFile, variant: .secondary, size: .sm, icon: .externalLink) {
                        model.openArtifactFile(art)
                    }
                    .accessibilityIdentifier("sources.page.artifact.\(art.id).open")
                }
                .padding(PVSpacing.space6)
                .background(PVColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .stroke(PVColor.borderSubtle, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture { model.openArtifactFile(art) }

                Text(L10n.Sources.openFileCaption)
                    .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                    .foregroundStyle(PVColor.textMuted)
            } else {
                PVCallout(
                    tone: .neutral,
                    message: String(localized: L10n.Sources.filelessHint),
                    compact: true
                )
                PVButton(L10n.Sources.addFile, variant: .primary, size: .sm, icon: .fileUp) {
                    Task { await model.addFile(toArtifactID: art.id) }
                }
                .accessibilityIdentifier("sources.page.artifact.\(art.id).addFile")
            }
        }
    }

    private func fileMetaLine(_ file: CatalogFileRef) -> String {
        let size = ByteCountFormatter.string(fromByteCount: file.byteSize, countStyle: .file)
        return "\(file.mediaType) · \(size)"
    }

    // MARK: Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            sectionHeader(
                title: L10n.Sources.notesHeading,
                meta: model.notes.isEmpty ? nil : "\(model.notes.count)"
            )

            if model.notes.isEmpty {
                PVEmptyState(
                    icon: .penLine,
                    title: L10n.Sources.notesEmptyTitle,
                    message: String(localized: L10n.Sources.notesEmptyMessage),
                    compact: true
                )
                .accessibilityIdentifier("sources.page.notes.empty")
            } else {
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
            }

            HStack(alignment: .top, spacing: PVSpacing.space6) {
                Text(L10n.Sources.noteComposerAttribution(displayName: model.sessionDisplayName))
                    .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                    .foregroundStyle(PVColor.textFaint)
                    .frame(width: 150, alignment: .leading)

                VStack(alignment: .trailing, spacing: PVSpacing.space4) {
                    TextField(
                        "",
                        text: $model.noteDraft,
                        prompt: Text(L10n.Sources.notePlaceholder),
                        axis: .vertical
                    )
                    .font(PVFont.body(size: PVTypeScale.bodySmall))
                    .foregroundStyle(PVColor.textPrimary)
                    .textFieldStyle(.plain)
                    .lineLimit(2...8)
                    .padding(PVSpacing.space3)
                    .background(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .fill(PVColor.surfaceSunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .strokeBorder(PVColor.borderSubtle, lineWidth: 1)
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
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.top, model.notes.isEmpty ? PVSpacing.space7 : 0)
        }
        .padding(.top, PVSpacing.space11 - PVSpacing.space9)
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
        HStack(alignment: .top, spacing: PVSpacing.space6) {
            VStack(alignment: .leading, spacing: PVSpacing.space1) {
                Text(note.authorDisplayName)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textSecondary)
                if !note.createdAt.isEmpty {
                    Text(Self.formatStamp(note.createdAt))
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.textFaint)
                }
            }
            .frame(width: 150, alignment: .leading)

            TextField("", text: $bodyText, axis: .vertical)
                .font(PVFont.body(size: PVTypeScale.bodySmall))
                .foregroundStyle(PVColor.textSecondary)
                .textFieldStyle(.plain)
                .lineLimit(1...12)
                .padding(.vertical, PVSpacing.space3)
                .padding(.horizontal, PVSpacing.space4)
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
        .padding(.vertical, PVSpacing.space6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PVColor.borderSubtle)
                .frame(height: 1)
        }
    }

    /// Board stamp: `04 Mar 2026 · 7:22 PM MST`.
    private static func formatStamp(_ rfc3339: String) -> String {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        guard let date = withFraction.date(from: rfc3339) ?? plain.date(from: rfc3339) else {
            return rfc3339
        }
        let datePart = date.formatted(.dateTime.day(.twoDigits).month(.abbreviated).year())
        let timePart = date.formatted(.dateTime.hour().minute().timeZone(.specificName(.short)))
        return "\(datePart) · \(timePart)"
    }
}
