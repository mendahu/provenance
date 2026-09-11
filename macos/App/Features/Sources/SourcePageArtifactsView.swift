import SwiftUI

/// Artifacts accordion: list, expand/collapse detail, and the Add dialog form.
struct SourcePageArtifactsView: View {
    @Bindable var model: SourcePageModel

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            SourcePageSectionHeader(
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

    /// Label / description / optional file form for the Add Artifact dialog.
    var addForm: some View {
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
                        .frame(width: SourcePageLayout.artifactChevronWidth)
                    PVThumbnail(artifactThumbnail(art), size: SourcePageLayout.artifactRowThumbnailSize)
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
        .padding(.leading, SourcePageLayout.artifactDetailLeading)
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
                PVInlineEditActions(
                    isSaving: model.artifacts.savingID == art.id,
                    saveLabel: L10n.Sources.saveArtifact,
                    cancelLabel: L10n.Sources.cancelEdit,
                    saveDisabled: !model.artifacts.canSaveFields(art.id),
                    showsCancel: dirty,
                    accessibilityIdentifierPrefix: "sources.page.artifact.\(art.id)",
                    onSave: { Task { await model.artifacts.saveFields(id: art.id) } },
                    onCancel: { model.artifacts.cancelFields(id: art.id) }
                )

                if !dirty {
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
}
