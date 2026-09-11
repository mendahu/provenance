import SwiftUI

/// Notes stream: existing rows with explicit edit/save/cancel, plus the composer.
struct SourcePageNotesView: View {
    @Bindable var model: SourcePageModel

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space6) {
            SourcePageSectionHeader(
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
                        isEditing: model.notes.editingNoteID == note.id,
                        bodyDraft: $model.notes.bodyDraft,
                        bodyError: $model.notes.bodyError,
                        isSaving: model.notes.isSaving && model.notes.editingNoteID == note.id,
                        onBeginEdit: { model.notes.beginEdit(id: note.id) },
                        onSave: { Task { await model.notes.saveEdit() } },
                        onCancel: { model.notes.cancelEdit() },
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
                    .frame(width: SourcePageLayout.notesBylineWidth, alignment: .leading)

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
}

private struct SourcePageNoteRow: View {
    let note: CatalogSourceNote
    let isEditing: Bool
    @Binding var bodyDraft: String
    @Binding var bodyError: String?
    let isSaving: Bool
    let onBeginEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PVSpacing.space6) {
            VStack(alignment: .leading, spacing: PVSpacing.space1) {
                Text(note.authorDisplayName)
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textSecondary)
                if !note.createdAt.isEmpty {
                    Text(TimestampFormat.boardStamp(note.createdAt))
                        .font(PVFont.mono(size: PVTypeScale.micro))
                        .foregroundStyle(PVColor.textFaint)
                }
            }
            .frame(width: SourcePageLayout.notesBylineWidth, alignment: .leading)

            if isEditing {
                VStack(alignment: .leading, spacing: PVSpacing.space4) {
                    TextField("", text: $bodyDraft, axis: .vertical)
                        .font(PVFont.body(size: PVTypeScale.bodySmall, weight: PVFontWeight.regular))
                        .foregroundStyle(PVColor.textPrimary)
                        .textFieldStyle(.plain)
                        .lineLimit(1...12)
                        .padding(.vertical, PVSpacing.space3)
                        .padding(.horizontal, PVSpacing.space4)
                        .background(
                            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                                .fill(PVColor.surfaceCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                                .stroke(PVColor.borderDefault, lineWidth: 1)
                        )
                        .accessibilityIdentifier("sources.page.note.\(note.id)")
                        .disabled(isSaving)
                        .onChange(of: bodyDraft) { _, _ in bodyError = nil }

                    if let bodyError {
                        Text(bodyError)
                            .font(PVFont.body(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.danger)
                    }

                    HStack(spacing: PVSpacing.space4) {
                        PVButton(
                            L10n.Sources.saveNote,
                            variant: .primary,
                            size: .sm,
                            loading: isSaving
                        ) {
                            onSave()
                        }
                        .accessibilityIdentifier("sources.page.note.\(note.id).save")
                        PVButton(L10n.Sources.cancelEdit, variant: .ghost, size: .sm) {
                            onCancel()
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("sources.page.note.\(note.id).cancel")

                        Spacer(minLength: 0)

                        PVIconButton(.trash, label: L10n.Sources.deleteNote, size: .sm, tone: .danger) {
                            onDelete()
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("sources.page.note.\(note.id).delete")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(note.body)
                    .font(PVFont.body(size: PVTypeScale.bodySmall, weight: PVFontWeight.regular))
                    .foregroundStyle(PVColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, PVSpacing.space3)
                    .accessibilityIdentifier("sources.page.note.\(note.id)")

                HStack(spacing: PVSpacing.space2) {
                    PVIconButton(.penLine, label: L10n.Sources.editNote, size: .sm) {
                        onBeginEdit()
                    }
                    .accessibilityIdentifier("sources.page.note.\(note.id).edit")

                    PVIconButton(.trash, label: L10n.Sources.deleteNote, size: .sm, tone: .danger) {
                        onDelete()
                    }
                    .accessibilityIdentifier("sources.page.note.\(note.id).delete")
                }
            }
        }
        .padding(.vertical, PVSpacing.space6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PVColor.borderSubtle)
                .frame(height: 1)
        }
    }
}
