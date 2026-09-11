import SwiftUI

/// Sticky identity header: breadcrumbs, thumbnail, title edit, type chip.
struct SourcePageIdentityHeader: View {
    @Bindable var model: SourcePageModel
    let onBackToList: () -> Void

    var body: some View {
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
}
