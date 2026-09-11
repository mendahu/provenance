import SwiftUI

/// Individual Source page (S2-18 / S2-25): sticky identity header, Description +
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
        VStack(spacing: 0) {
            if model.workspace != nil || model.isLoading || model.loadError != nil {
                identityHeader
            }
            ScrollView {
                VStack(alignment: .leading, spacing: PVSpacing.space9) {
                    if model.isLoading && model.workspace == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, PVSpacing.space9)
                    } else if let loadError = model.loadError, model.workspace == nil {
                        PVCallout(tone: .danger, message: L10n.Errors.message(for: loadError))
                    } else {
                        overviewColumns
                        artifactsSection
                        notesSection
                    }
                }
                .frame(maxWidth: PVSpacing.widthContentMax, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PVSpacing.gutterPage)
                .padding(.top, PVSpacing.space8)
                .padding(.bottom, PVSpacing.space10)
            }
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
            isRunning: model.artifacts.isSavingDraft,
            confirmDisabled: !model.artifacts.canSubmitDraft,
            onConfirm: { Task { await model.artifacts.create() } }
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
            isRunning: model.metadata.isSavingAdd,
            confirmDisabled: !model.metadata.canSubmitAdd,
            onConfirm: { Task { await model.metadata.createFromAdd() } }
        ) {
            addMetadataForm
        }
        .pvDialog(
            isPresented: dateEditorPresented,
            copy: PVDialogCopy(
                title: model.metadata.isDateEditMode
                    ? L10n.Sources.editDateDialogTitle
                    : L10n.Sources.addDateDialogTitle,
                subtitle: model.metadata.dateEditorSubtitle,
                confirm: model.metadata.isDateEditMode
                    ? L10n.Sources.saveDateConfirm
                    : L10n.Sources.addDateConfirm,
                cancel: L10n.Sources.cancelAction
            ),
            isRunning: model.metadata.isSavingDate,
            confirmDisabled: !canSaveDateEditor,
            onConfirm: { Task { await model.metadata.saveDateEditor() } }
        ) {
            DateValueEditorForm(draft: $model.metadata.dateEditorDraft)
        }
        .task { await model.load() }
        .accessibilityIdentifier("sources.page")
    }

    private var addArtifactPresented: Binding<Bool> {
        Binding(
            get: { model.artifacts.isAdding },
            set: { presented in
                if presented {
                    model.artifacts.openAdd()
                } else {
                    model.artifacts.cancelAdd()
                }
            }
        )
    }

    private var addMetadataPresented: Binding<Bool> {
        Binding(
            get: { model.metadata.isAdding },
            set: { presented in
                if presented {
                    model.metadata.openAdd()
                } else {
                    model.metadata.cancelAdd()
                }
            }
        )
    }

    private var dateEditorPresented: Binding<Bool> {
        Binding(
            get: { model.metadata.isEditingDate },
            set: { presented in
                if !presented {
                    model.metadata.cancelDateEditor()
                }
            }
        )
    }

    private var canSaveDateEditor: Bool {
        model.metadata.dateEditorDraft.isValid && !model.metadata.isSavingDate
    }

    // MARK: Sticky identity header

    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            breadcrumbs
            if model.workspace != nil {
                HStack(alignment: .top, spacing: PVSpacing.space7) {
                    PVThumbnail(sourceThumbnail, size: 72)
                    titleCluster
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: PVSpacing.widthContentMax, alignment: .leading)
            }
        }
        .padding(.top, PVSpacing.space5)
        .padding(.horizontal, PVSpacing.gutterPage)
        .padding(.bottom, PVSpacing.space6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PVColor.surfaceCard)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PVColor.borderSubtle)
                .frame(height: 1)
        }
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

    private var sourceThumbnail: PVThumbnail.Content {
        if let image = ProjectFiles.thumbnailImage(
            projectDir: model.pageProjectDir,
            relPath: model.source?.thumbnailRelPath ?? ""
        ) {
            return PVThumbnail.Content(image: image)
        }
        return .empty
    }

    private var titleCluster: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space4) {
            HStack(alignment: .firstTextBaseline, spacing: PVSpacing.space4) {
                if model.identity.editingTitle {
                    VStack(alignment: .leading, spacing: PVSpacing.space2) {
                        TextField(
                            "",
                            text: $model.identity.titleDraft,
                            prompt: Text(L10n.Sources.formTitle),
                            axis: .vertical
                        )
                        .font(PVFont.display(size: PVTypeScale.h1, weight: PVFontWeight.semibold))
                        .foregroundStyle(PVColor.textDisplay)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .padding(.horizontal, PVSpacing.space5)
                        .padding(.vertical, PVSpacing.space4)
                        .background(
                            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                                .fill(PVColor.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                                .stroke(PVColor.borderFocus, lineWidth: 1.5)
                        )
                        .accessibilityIdentifier("sources.page.title")
                        .onChange(of: model.identity.titleDraft) { _, _ in model.identity.titleError = nil }
                        .onSubmit { Task { await model.identity.saveTitle() } }
                        .disabled(model.identity.isSaving)

                        if let titleError = model.identity.titleError {
                            Text(titleError)
                                .font(PVFont.body(size: PVTypeScale.caption))
                                .foregroundStyle(PVColor.danger)
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)

                    HStack(spacing: PVSpacing.space3) {
                        PVButton(
                            L10n.Sources.saveAction,
                            variant: .primary,
                            size: .sm,
                            loading: model.identity.isSaving
                        ) {
                            Task { await model.identity.saveTitle() }
                        }
                        .accessibilityIdentifier("sources.page.title.save")
                        PVButton(L10n.Sources.cancelEdit, variant: .ghost, size: .sm) {
                            model.identity.cancelEditTitle()
                        }
                        .disabled(model.identity.isSaving)
                        .accessibilityIdentifier("sources.page.title.cancel")
                    }
                } else {
                    Text(model.identity.title)
                        .font(PVFont.display(size: PVTypeScale.h1, weight: PVFontWeight.semibold))
                        .foregroundStyle(PVColor.textDisplay)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("sources.page.title")

                    PVIconButton(.penLine, label: L10n.Sources.editTitle, size: .sm) {
                        model.identity.beginEditTitle()
                    }
                    .accessibilityIdentifier("sources.page.title.edit")
                }
            }

            metaRow
        }
    }

    private var metaRow: some View {
        HStack(alignment: .center, spacing: PVSpacing.space5) {
            if let ref = model.source?.ref {
                Text(ref)
                    .font(PVFont.mono(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
                    .accessibilityIdentifier("sources.page.ref")
            }

            Text("·")
                .foregroundStyle(PVColor.borderDefault)

            if model.identity.editingType {
                VStack(alignment: .leading, spacing: PVSpacing.space2) {
                    HStack(spacing: PVSpacing.space3) {
                        PVComboBox(
                            selection: $model.identity.typeDraftID,
                            options: model.identity.typeComboOptions,
                            placeholder: L10n.Sources.typePlaceholder,
                            emptyLabel: L10n.Sources.typeNoMatch,
                            label: L10n.Sources.pageFormType,
                            accessibilityIdentifierPrefix: "sources.page.type",
                            activateOnAppear: true
                        )
                        .frame(width: 210)
                        .disabled(model.identity.isSaving)
                        .onChange(of: model.identity.typeDraftID) { _, newValue in
                            guard !newValue.isEmpty, newValue != model.identity.sourceTypeID else { return }
                            Task { await model.identity.saveType() }
                        }

                        PVIconButton(.dismiss, label: L10n.Sources.cancelEdit, size: .sm) {
                            model.identity.cancelEditType()
                        }
                        .disabled(model.identity.isSaving)
                        .accessibilityIdentifier("sources.page.type.cancel")
                    }

                    if let typeError = model.identity.typeError {
                        Text(typeError)
                            .font(PVFont.body(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.danger)
                    }
                }
            } else {
                HStack(spacing: PVSpacing.space3) {
                    Text(model.identity.typeLabel)
                        .font(PVFont.body(size: PVTypeScale.caption, weight: PVFontWeight.medium))
                        .foregroundStyle(PVColor.recordMarriage)
                        .padding(.horizontal, PVSpacing.space4)
                        .padding(.vertical, PVSpacing.space2)
                        .background(
                            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                                .fill(Color.pvDynamic(
                                    light: PVPalette.plum100,
                                    dark: PVPalette.hex("#3A2434")
                                ))
                        )
                        .accessibilityIdentifier("sources.page.type")

                    PVIconButton(.penLine, label: L10n.Sources.editType, size: .sm) {
                        model.identity.beginEditType()
                    }
                    .accessibilityIdentifier("sources.page.type.edit")
                }
            }
        }
    }

    /// Board: Description + Credibility | Metadata.
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

    // MARK: Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            sectionHeader(
                title: L10n.Sources.descriptionHeading,
                actions: {
                    if !model.identity.editingDescription {
                        PVButton(
                            L10n.Sources.editDescription,
                            variant: .ghost,
                            size: .sm,
                            icon: .penLine
                        ) {
                            model.identity.beginEditDescription()
                        }
                        .accessibilityIdentifier("sources.page.description.edit")
                    }
                }
            )

            if model.identity.editingDescription {
                VStack(alignment: .leading, spacing: PVSpacing.space4) {
                    TextField(
                        "",
                        text: $model.identity.descriptionDraft,
                        prompt: Text(L10n.Sources.descriptionPlaceholder),
                        axis: .vertical
                    )
                    .font(PVFont.body(size: PVTypeScale.body, weight: PVFontWeight.regular))
                    .foregroundStyle(PVColor.textPrimary)
                    .textFieldStyle(.plain)
                    .lineLimit(3...12)
                    .padding(.horizontal, PVSpacing.space5)
                    .padding(.vertical, PVSpacing.space4)
                    .background(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .fill(PVColor.surfaceCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                            .stroke(PVColor.borderDefault, lineWidth: 1)
                    )
                    .accessibilityIdentifier("sources.page.description")
                    .disabled(model.identity.isSaving)

                    if let descriptionError = model.identity.descriptionError {
                        Text(descriptionError)
                            .font(PVFont.body(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.danger)
                    }

                    HStack(spacing: PVSpacing.space4) {
                        PVButton(
                            L10n.Sources.saveDescription,
                            variant: .primary,
                            size: .sm,
                            loading: model.identity.isSaving
                        ) {
                            Task { await model.identity.saveDescription() }
                        }
                        .accessibilityIdentifier("sources.page.description.save")
                        PVButton(L10n.Sources.cancelEdit, variant: .ghost, size: .sm) {
                            model.identity.cancelEditDescription()
                        }
                        .disabled(model.identity.isSaving)
                        .accessibilityIdentifier("sources.page.description.cancel")
                    }
                }
            } else if !model.identity.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(model.identity.description)
                    .font(PVFont.body(size: PVTypeScale.body, weight: PVFontWeight.regular))
                    .foregroundStyle(PVColor.textSecondary)
                    .lineSpacing((PVLineHeight.normal - 1) * PVTypeScale.body)
                    .accessibilityIdentifier("sources.page.description")
            }
        }
    }

    // MARK: Credibility

    private var credibilitySection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            sectionHeader(
                title: L10n.Sources.credibilityHeading,
                aside: {
                    Text(
                        model.credibility.hasSavedAssessment
                            ? L10n.Sources.credibilityHint
                            : L10n.Sources.credibilityHintUnset
                    )
                    .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                    .foregroundStyle(PVColor.textMuted)
                    .lineLimit(2)
                }
            )

            HStack(spacing: PVSpacing.space4) {
                ForEach(model.credibility.grades, id: \.id) { grade in
                    credibilityChip(grade)
                }
            }
            .accessibilityIdentifier("sources.page.credibility.grades")

            PVInput(
                text: $model.credibility.argumentDraft,
                size: .sm,
                prompt: L10n.Sources.credibilityArgumentPlaceholder
            )
            .accessibilityIdentifier("sources.page.credibility.argument")

            HStack(spacing: PVSpacing.space4) {
                PVButton(
                    L10n.Sources.saveAssessment,
                    variant: .primary,
                    size: .sm,
                    loading: model.credibility.isSaving
                ) {
                    Task { await model.credibility.save() }
                }
                .disabled(!model.credibility.isDirty && !model.credibility.isSaving)
                .accessibilityIdentifier("sources.page.credibility.save")

                if model.credibility.isDirty {
                    PVButton(L10n.Sources.cancelEdit, variant: .ghost, size: .sm) {
                        model.credibility.cancel()
                    }
                    .disabled(model.credibility.isSaving)
                    .accessibilityIdentifier("sources.page.credibility.cancel")
                } else {
                    Text(
                        model.credibility.hasSavedAssessment
                            ? L10n.Sources.credibilitySavedStatus
                            : L10n.Sources.credibilityUnsavedStatus
                    )
                    .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                    .foregroundStyle(PVColor.textFaint)
                }
            }
        }
    }

    private func credibilityChip(_ grade: CatalogCredibilityGrade) -> some View {
        let selected = model.credibility.draftKey == grade.key
        let dashedUnset = grade.key == "standard"
            && !model.credibility.hasSavedAssessment
            && model.credibility.draftKey == "standard"
        let colors = credibilityColors(for: grade.key)
        return Button {
            model.credibility.selectDraft(key: grade.key)
        } label: {
            Text(grade.label)
                .font(PVFont.body(
                    size: PVTypeScale.caption,
                    weight: selected ? PVFontWeight.semibold : PVFontWeight.regular
                ))
                .foregroundStyle(selected ? colors.fg : PVColor.textSecondary)
                .padding(.horizontal, PVSpacing.space5)
                .padding(.vertical, PVSpacing.space3)
                .background(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .fill(selected ? colors.bg : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .strokeBorder(
                            selected ? colors.fg : PVColor.borderDefault,
                            style: StrokeStyle(lineWidth: 1, dash: dashedUnset ? [4, 3] : [])
                        )
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
                meta: model.metadata.saved.isEmpty
                    ? nil
                    : L10n.Sources.metadataFieldCount(model.metadata.saved.count),
                actions: {
                    PVButton(L10n.Sources.addMetadata, variant: .primary, size: .sm, icon: .plus) {
                        model.metadata.openAdd()
                    }
                    .accessibilityIdentifier("sources.page.addMetadata")
                }
            )

            Text(L10n.Sources.metadataIntro)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textMuted)
                .frame(maxWidth: PVSpacing.measureProse, alignment: .leading)

            if model.metadata.saved.isEmpty, model.metadata.suggested.isEmpty {
                Text(L10n.Sources.metadataEmptyMessage)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
                    .accessibilityIdentifier("sources.page.metadata.empty")
            } else {
                if !model.metadata.saved.isEmpty {
                    PVReorderableList(items: model.metadata.saved, onMove: { source, destination in
                        Task { await model.metadata.moveSaved(from: source, to: destination) }
                    }) { entry in
                        savedMetadataRow(entry)
                    }
                    .accessibilityIdentifier("sources.page.metadata.list")
                }

                if !model.metadata.suggested.isEmpty {
                    VStack(alignment: .leading, spacing: PVSpacing.space4) {
                        Text(L10n.Sources.metadataSuggestionsHeading)
                            .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                            .tracking(PVTypeScale.micro * PVTracking.caps)
                            .textCase(.uppercase)
                            .foregroundStyle(PVColor.textFaint)
                            .padding(.top, model.metadata.saved.isEmpty ? 0 : PVSpacing.space7)

                        ForEach(model.metadata.suggested) { entry in
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
        let isDate = entry.field.dataType == "date"
        let structured = model.metadata.isStructured(entry)
        let editing = model.metadata.editingFieldID == fieldID
        return VStack(alignment: .leading, spacing: PVSpacing.space2) {
            HStack(alignment: .top, spacing: PVSpacing.space5) {
                PVReorderHandle()
                    .padding(.top, 6)
                Text(entry.field.label)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textMuted)
                    .frame(width: 170, alignment: .leading)
                    .padding(.top, 6)

                if editing {
                    HStack(alignment: .top, spacing: PVSpacing.space3) {
                        TextField(
                            "",
                            text: Binding(
                                get: { model.metadata.drafts[fieldID] ?? entry.valueText },
                                set: { model.metadata.drafts[fieldID] = $0 }
                            ),
                            axis: .vertical
                        )
                        .font(PVFont.mono(size: PVTypeScale.caption))
                        .foregroundStyle(PVColor.textPrimary)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .padding(.horizontal, PVInputChrome.horizontalInset)
                        .padding(.vertical, PVSpacing.space3)
                        .background(
                            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                                .fill(PVColor.surfaceRaised)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                                .stroke(PVColor.borderDefault, lineWidth: 1)
                        )
                        .onSubmit { Task { await model.metadata.save(fieldID: fieldID) } }
                        .disabled(model.metadata.savingFieldID == fieldID)
                        .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

                        PVButton(
                            L10n.Sources.saveAction,
                            variant: .primary,
                            size: .sm,
                            loading: model.metadata.savingFieldID == fieldID
                        ) {
                            Task { await model.metadata.save(fieldID: fieldID) }
                        }
                        .disabled(
                            (model.metadata.drafts[fieldID] ?? "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        )
                        .accessibilityIdentifier("sources.page.metadata.\(fieldID).save")

                        PVIconButton(.dismiss, label: L10n.Sources.cancelEdit, size: .sm) {
                            model.metadata.cancelEdit()
                        }
                        .disabled(model.metadata.savingFieldID == fieldID)
                        .accessibilityIdentifier("sources.page.metadata.\(fieldID).cancel")
                    }
                } else {
                    HStack(alignment: .top, spacing: PVSpacing.space3) {
                        Text(entry.valueText)
                            .font(PVFont.mono(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                            .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

                        PVIconButton(.penLine, label: L10n.Sources.editMetadataValue, size: .sm) {
                            model.metadata.beginEdit(fieldID: fieldID)
                        }
                        .padding(.top, 2)
                        .accessibilityIdentifier("sources.page.metadata.\(fieldID).edit")
                    }
                }

                metadataTypeBadge(entry.field.dataType)
                    .padding(.top, 4)
            }

            if isDate {
                HStack(spacing: PVSpacing.space4) {
                    Text(L10n.Sources.metadataStructuredLabel)
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.textFaint)

                    if structured {
                        Text(entry.dateSummary)
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.accentSoftForeground)
                        .padding(.horizontal, PVSpacing.space3)
                        .frame(height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(PVColor.accentSoft)
                        )
                    } else {
                        Text(L10n.Sources.metadataNotStructured)
                            .font(PVFont.body(size: PVTypeScale.micro, italic: true))
                            .foregroundStyle(PVColor.textMuted)
                    }

                    Button {
                        if structured {
                            model.metadata.openEditDate(fieldID: fieldID)
                        } else {
                            model.metadata.openStructureDate(fieldID: fieldID)
                        }
                    } label: {
                        Text(structured ? L10n.Sources.editDate : L10n.Sources.structureDate)
                            .font(PVFont.body(size: PVTypeScale.micro))
                            .foregroundStyle(structured ? PVColor.textPrimary : PVColor.textLink)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(
                                        PVColor.borderDefault,
                                        style: StrokeStyle(
                                            lineWidth: 1,
                                            dash: structured ? [] : [4, 3]
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        structured
                            ? "sources.page.metadata.\(fieldID).editDate"
                            : "sources.page.metadata.\(fieldID).structureDate"
                    )
                }
                .padding(.leading, 20 + PVSpacing.space5 + 170 + PVSpacing.space5)
            }
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
                    get: { model.metadata.drafts[fieldID] ?? "" },
                    set: { model.metadata.drafts[fieldID] = $0 }
                ),
                size: .sm,
                mono: true,
                prompt: L10n.Sources.metadataSuggestionPlaceholder
            )
            .onSubmit { Task { await model.metadata.save(fieldID: fieldID) } }
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).value")

            PVButton(
                L10n.Sources.saveMetadataSuggestion,
                variant: .ghost,
                size: .sm,
                loading: model.metadata.savingFieldID == fieldID
            ) {
                Task { await model.metadata.save(fieldID: fieldID) }
            }
            .disabled(
                (model.metadata.drafts[fieldID] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
            .accessibilityIdentifier("sources.page.metadata.\(fieldID).save")

            PVIconButton(.dismiss, label: L10n.Sources.dismissMetadataSuggestion, size: .sm) {
                Task { await model.metadata.dismissSuggestion(fieldID: fieldID) }
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
                error: model.metadata.addFieldError,
                required: true
            ) {
                PVComboBox(
                    selection: $model.metadata.addFieldID,
                    options: model.metadata.fieldComboOptions,
                    placeholder: L10n.Sources.metadataField,
                    emptyLabel: L10n.Sources.typeNoMatch,
                    isInvalid: model.metadata.addFieldError != nil,
                    label: L10n.Sources.metadataField,
                    accessibilityIdentifierPrefix: "sources.page.addMetadata.field"
                )
                .onChange(of: model.metadata.addFieldID) { _, newValue in
                    if !newValue.isEmpty { model.metadata.addFieldError = nil }
                }
            }
            PVField(
                label: L10n.Sources.metadataValue,
                hint: L10n.Sources.metadataValueHint,
                error: model.metadata.addValueError,
                required: true
            ) {
                PVInput(
                    text: $model.metadata.addValue,
                    isInvalid: model.metadata.addValueError != nil
                )
                .onChange(of: model.metadata.addValue) { _, _ in
                    model.metadata.addValueError = nil
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
                meta: model.artifacts.items.isEmpty
                    ? nil
                    : L10n.Sources.artifactsCount(model.artifacts.items.count),
                actions: {
                    PVButton(L10n.Sources.addArtifact, variant: .primary, size: .sm, icon: .plus) {
                        model.artifacts.openAdd()
                    }
                    .accessibilityIdentifier("sources.page.addArtifact")
                }
            )

            if model.artifacts.items.isEmpty {
                VStack(spacing: PVSpacing.space6) {
                    PVEmptyState(
                        icon: .photo,
                        title: L10n.Sources.artifactsEmptyTitle,
                        message: String(localized: L10n.Sources.artifactsEmptyMessage),
                        compact: true
                    )
                    PVButton(L10n.Sources.addArtifact, variant: .primary, size: .sm, icon: .plus) {
                        model.artifacts.openAdd()
                    }
                    .accessibilityIdentifier("sources.page.artifacts.empty.add")
                }
                .padding(.vertical, PVSpacing.space9)
                .frame(maxWidth: .infinity)
                .background(PVColor.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.md, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .foregroundStyle(PVColor.borderDefault)
                )
                .accessibilityIdentifier("sources.page.artifacts.empty")
            } else {
                VStack(spacing: 0) {
                    ForEach(model.artifacts.items, id: \.id) { art in
                        artifactRow(art)
                        if art.id != model.artifacts.items.last?.id {
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
                .pvShadow(PVElevation.sm)
                .accessibilityIdentifier("sources.page.artifacts.list")
            }
        }
        .padding(.top, PVSpacing.space11 - PVSpacing.space9)
    }

    private func artifactRow(_ art: CatalogArtifact) -> some View {
        let expanded = model.artifacts.expandedIDs.contains(art.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                model.artifacts.toggleExpanded(art.id)
            } label: {
                HStack(spacing: PVSpacing.space6) {
                    PVIcon(.chevronForward, size: 15)
                        .foregroundStyle(PVColor.textMuted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 18)
                    PVThumbnail(artifactThumbnail(art), size: 44)
                    Text(art.label.isEmpty ? art.ref : art.label)
                        .font(PVFont.body(size: PVTypeScale.bodySmall))
                        .foregroundStyle(PVColor.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(art.ref)
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.textMuted)
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
        let dirty = model.artifacts.fieldsDirty(art.id)
        return VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVField(
                label: L10n.Sources.artifactLabel,
                hint: L10n.Sources.artifactLabelHint,
                error: model.artifacts.fieldErrors[art.id],
                required: true
            ) {
                PVInput(
                    text: Binding(
                        get: { model.artifacts.labels[art.id] ?? art.label },
                        set: {
                            model.artifacts.labels[art.id] = $0
                            model.artifacts.fieldErrors[art.id] = nil
                        }
                    ),
                    size: .sm,
                    isInvalid: model.artifacts.fieldErrors[art.id] != nil
                )
                .onSubmit { Task { await model.artifacts.saveFields(id: art.id) } }
            }

            PVField(
                label: L10n.Sources.artifactDescription,
                hint: L10n.Sources.artifactDescriptionHint
            ) {
                TextField(
                    "",
                    text: Binding(
                        get: { model.artifacts.descriptions[art.id] ?? art.description },
                        set: { model.artifacts.descriptions[art.id] = $0 }
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
                .onSubmit { Task { await model.artifacts.saveFields(id: art.id) } }
            }

            HStack(spacing: PVSpacing.space4) {
                PVButton(
                    L10n.Sources.saveArtifact,
                    variant: .primary,
                    size: .sm,
                    loading: model.artifacts.savingID == art.id
                ) {
                    Task { await model.artifacts.saveFields(id: art.id) }
                }
                .disabled(!model.artifacts.canSaveFields(art.id) && model.artifacts.savingID != art.id)
                .accessibilityIdentifier("sources.page.artifact.\(art.id).save")

                if dirty {
                    PVButton(L10n.Sources.cancelEdit, variant: .ghost, size: .sm) {
                        model.artifacts.cancelFields(id: art.id)
                    }
                    .disabled(model.artifacts.savingID == art.id)
                    .accessibilityIdentifier("sources.page.artifact.\(art.id).cancel")
                } else {
                    Text(L10n.Sources.noUnsavedChanges)
                        .font(PVFont.body(size: PVTypeScale.caption, italic: true))
                        .foregroundStyle(PVColor.textFaint)
                }

                Spacer(minLength: 0)
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
                    PVThumbnail(artifactThumbnail(art), size: 56)
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
                        model.artifacts.open(art)
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
                .onTapGesture { model.artifacts.open(art) }
            } else {
                PVCallout(
                    tone: .neutral,
                    message: String(localized: L10n.Sources.filelessHint),
                    compact: true
                )
                PVButton(L10n.Sources.addFile, variant: .primary, size: .sm, icon: .fileUp) {
                    Task { await model.artifacts.addFile(to: art.id) }
                }
                .accessibilityIdentifier("sources.page.artifact.\(art.id).addFile")
            }
        }
    }

    private func artifactThumbnail(_ art: CatalogArtifact) -> PVThumbnail.Content {
        if let image = ProjectFiles.thumbnailImage(
            projectDir: model.pageProjectDir,
            relPath: art.thumbnailRelPath
        ) {
            return PVThumbnail.Content(image: image)
        }
        return .empty
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
                meta: model.notes.items.isEmpty ? nil : "\(model.notes.items.count)"
            )

            if model.notes.items.isEmpty {
                PVEmptyState(
                    icon: .penLine,
                    title: L10n.Sources.notesEmptyTitle,
                    message: String(localized: L10n.Sources.notesEmptyMessage),
                    compact: true
                )
                .accessibilityIdentifier("sources.page.notes.empty")
            } else {
                ForEach(model.notes.items, id: \.id) { note in
                    SourcePageNoteRow(
                        note: note,
                        onCommit: { body in
                            Task { await model.notes.update(id: note.id, body: body) }
                        },
                        onDelete: {
                            Task { await model.notes.delete(id: note.id) }
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
                        text: $model.notes.draft,
                        prompt: Text(L10n.Sources.notePlaceholder),
                        axis: .vertical
                    )
                    .font(PVFont.body(size: PVTypeScale.bodySmall, weight: PVFontWeight.regular))
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
                        variant: .primary,
                        size: .sm,
                        icon: .plus,
                        loading: model.notes.isSaving
                    ) {
                        Task { await model.notes.add() }
                    }
                    .disabled(model.notes.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("sources.page.addNote")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.top, model.notes.items.isEmpty ? PVSpacing.space7 : 0)
        }
        .padding(.top, PVSpacing.space11 - PVSpacing.space9)
    }

    // MARK: Add Artifact form

    private var addArtifactForm: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            PVField(
                label: L10n.Sources.artifactLabel,
                hint: L10n.Sources.artifactLabelHint,
                error: model.artifacts.draftLabelError,
                required: true
            ) {
                PVInput(
                    text: $model.artifacts.draft.label,
                    isInvalid: model.artifacts.draftLabelError != nil
                )
                .accessibilityIdentifier("sources.page.addArtifact.label")
            }
            PVField(
                label: L10n.Sources.artifactDescription,
                hint: L10n.Sources.formDescriptionHint
            ) {
                PVInput(text: $model.artifacts.draft.description)
                    .accessibilityIdentifier("sources.page.addArtifact.description")
            }
            PVField(label: L10n.Sources.optionalFile) {
                HStack(spacing: PVSpacing.space4) {
                    if let name = model.artifacts.draft.fileName {
                        Text(name)
                            .font(PVFont.mono(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.textPrimary)
                            .lineLimit(1)
                        PVButton(L10n.Sources.clearFile, variant: .ghost, size: .sm) {
                            model.artifacts.clearFile()
                        }
                    } else {
                        PVButton(L10n.Sources.chooseFile, variant: .secondary, size: .sm, icon: .fileUp) {
                            model.artifacts.pickFile()
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
                .font(PVFont.body(size: PVTypeScale.bodySmall, weight: PVFontWeight.regular))
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
