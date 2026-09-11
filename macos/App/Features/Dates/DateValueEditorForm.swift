import SwiftUI

/// Shared DateValue create/edit form body (kind, qualifier, cascade, time, phrase).
struct DateValueEditorForm: View {
    @Binding var draft: DateValueDraft

    private let months: [(String, String)] = [
        ("", "—"),
        ("1", "January"), ("2", "February"), ("3", "March"), ("4", "April"),
        ("5", "May"), ("6", "June"), ("7", "July"), ("8", "August"),
        ("9", "September"), ("10", "October"), ("11", "November"), ("12", "December"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space7) {
            kindSection
            if draft.isPoint {
                qualifierSection
            }
            PVDivider()
            cascadeSection(start: true)
            if draft.isRange {
                PVDivider()
                cascadeSection(start: false)
            }
            PVDivider()
            advancedToggle
            if draft.showAdvanced {
                advancedSection
            }
            storedAsBar
        }
    }

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space3) {
            Text(L10n.Sources.dateKindLabel)
                .font(PVFont.body(size: PVTypeScale.caption, weight: PVFontWeight.medium))
                .foregroundStyle(PVColor.textSecondary)
            HStack(spacing: 0) {
                kindChip(L10n.Sources.dateKindPoint, kind: "point")
                kindChip(L10n.Sources.dateKindRange, kind: "range")
            }
            .padding(2)
            .background(PVColor.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                    .stroke(PVColor.borderSubtle, lineWidth: 1)
            )
            if draft.isRange {
                Text(L10n.Sources.dateKindRangeHint)
                    .font(PVFont.body(size: PVTypeScale.micro, italic: true))
                    .foregroundStyle(PVColor.textMuted)
            }
        }
    }

    private func kindChip(_ title: LocalizedStringResource, kind: String) -> some View {
        let on = draft.kind == kind
        return Button {
            draft.setKind(kind)
        } label: {
            Text(title)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(on ? PVColor.textPrimary : PVColor.textMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(on ? PVColor.surfaceCard : Color.clear)
                        .pvShadow(on ? PVElevation.sm : [])
                )
        }
        .buttonStyle(.plain)
    }

    private var qualifierSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space3) {
            Text(L10n.Sources.dateQualifierLabel)
                .font(PVFont.body(size: PVTypeScale.caption, weight: PVFontWeight.medium))
                .foregroundStyle(PVColor.textSecondary)
            HStack(spacing: PVSpacing.space3) {
                qualifierChip(L10n.Sources.dateQualifierAsStated, "")
                qualifierChip(L10n.Sources.dateQualifierAbout, "ABT")
                qualifierChip(L10n.Sources.dateQualifierBefore, "BEF")
                qualifierChip(L10n.Sources.dateQualifierAfter, "AFT")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func qualifierChip(_ title: LocalizedStringResource, _ value: String) -> some View {
        let on = draft.qualifier == value
        return Button {
            draft.qualifier = value
        } label: {
            Text(title)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(on ? PVColor.accentSoftForeground : PVColor.textSecondary)
                .padding(.horizontal, PVSpacing.space5)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .fill(on ? PVColor.accentSoft : PVColor.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                        .stroke(on ? PVColor.accentLine : PVColor.borderDefault, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func cascadeSection(start: Bool) -> some View {
        let heading: LocalizedStringResource = start
            ? (draft.isRange ? L10n.Sources.dateEarliestHeading : L10n.Sources.datePointHeading)
            : L10n.Sources.dateLatestHeading
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            HStack(alignment: .firstTextBaseline) {
                Text(heading)
                    .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                    .tracking(PVTypeScale.micro * PVTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(PVColor.textMuted)
                Spacer()
                if start {
                    Text(L10n.Sources.dateLeaveEmptyHint)
                        .font(PVFont.body(size: PVTypeScale.micro, italic: true))
                        .foregroundStyle(PVColor.textFaint)
                }
            }
            HStack(alignment: .bottom, spacing: PVSpacing.space4) {
                cascadeField(
                    L10n.Sources.dateYear,
                    text: yearBinding(start),
                    width: 92,
                    mono: true,
                    isInvalid: draft.isFieldInvalid(.year, start: start)
                )
                monthPicker(start: start)
                cascadeField(
                    L10n.Sources.dateDay,
                    text: dayBinding(start),
                    width: 76,
                    mono: true,
                    disabled: monthBinding(start).wrappedValue.isEmpty,
                    isInvalid: draft.isFieldInvalid(.day, start: start)
                )
            }
            if let fieldErr = draft.cascadeFieldError(start: start) {
                Text(fieldErr)
                    .font(PVFont.body(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.danger)
                    .accessibilityIdentifier(start ? "sources.page.date.start.fieldError" : "sources.page.date.end.fieldError")
            } else if !start, let err = draft.endError {
                Text(err)
                    .font(PVFont.body(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.danger)
            }
            if start ? draft.hasFullStartDay : draft.hasFullEndDay {
                if start ? draft.showStartTime : draft.showEndTime {
                    timeBlock(start: start)
                }
                Button {
                    if start {
                        draft.showStartTime.toggle()
                    } else {
                        draft.showEndTime.toggle()
                    }
                } label: {
                    Text(start
                        ? (draft.showStartTime ? L10n.Sources.dateHideTime : L10n.Sources.dateAddTime)
                        : (draft.showEndTime ? L10n.Sources.dateHideTime : L10n.Sources.dateAddTime)
                    )
                    .font(PVFont.body(size: PVTypeScale.caption))
                    .foregroundStyle(PVColor.textLink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timeBlock(start: Bool) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space4) {
            HStack(alignment: .bottom, spacing: PVSpacing.space3) {
                cascadeField(
                    L10n.Sources.dateHour,
                    text: hourBinding(start),
                    width: 62,
                    mono: true,
                    isInvalid: draft.isFieldInvalid(.hour, start: start)
                )
                cascadeField(
                    L10n.Sources.dateMinute,
                    text: minuteBinding(start),
                    width: 62,
                    mono: true,
                    disabled: hourBinding(start).wrappedValue.isEmpty,
                    isInvalid: draft.isFieldInvalid(.minute, start: start)
                )
                if start {
                    cascadeField(
                        L10n.Sources.dateSecond,
                        text: secondBinding(start: true),
                        width: 62,
                        mono: true,
                        disabled: draft.startMinute == nil,
                        isInvalid: draft.isFieldInvalid(.second, start: true)
                    )
                    cascadeField(
                        L10n.Sources.dateMillisecond,
                        text: millisecondBinding(start: true),
                        width: 70,
                        mono: true,
                        disabled: draft.startSecond == nil,
                        isInvalid: draft.isFieldInvalid(.millisecond, start: true)
                    )
                }
                cascadeField(L10n.Sources.dateTimeZone, text: tzBinding(start), width: nil, mono: false)
            }
        }
        .padding(PVSpacing.space5)
        .background(PVColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                .stroke(PVColor.borderSubtle, lineWidth: 1)
        )
    }

    private var advancedToggle: some View {
        Button {
            draft.showAdvanced.toggle()
        } label: {
            Text(draft.showAdvanced ? L10n.Sources.dateHideAdvanced : L10n.Sources.dateShowAdvanced)
                .font(PVFont.body(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textLink)
        }
        .buttonStyle(.plain)
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space5) {
            VStack(alignment: .leading, spacing: PVSpacing.space2) {
                Text(L10n.Sources.dateCalendar)
                    .font(PVFont.body(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textSecondary)
                Picker("", selection: $draft.calendar) {
                    Text("Gregorian").tag("gregorian")
                    Text("Julian").tag("julian")
                    Text("French Republican").tag("french-republican")
                    Text("Hebrew").tag("hebrew")
                }
                .labelsHidden()
                .frame(width: 220)
            }
            VStack(alignment: .leading, spacing: PVSpacing.space2) {
                Text(L10n.Sources.datePhrase)
                    .font(PVFont.body(size: PVTypeScale.micro))
                    .foregroundStyle(PVColor.textSecondary)
                PVInput(text: $draft.phrase, size: .sm, prompt: LocalizedStringResource(
                    "sources.page.datePhrasePrompt",
                    defaultValue: "Michaelmas term",
                    comment: "Placeholder for DateValue phrase"
                ))
                Text(L10n.Sources.datePhraseHint)
                    .font(PVFont.body(size: PVTypeScale.micro, italic: true))
                    .foregroundStyle(PVColor.textMuted)
            }
        }
    }

    private var storedAsBar: some View {
        HStack(spacing: PVSpacing.space5) {
            Text(L10n.Sources.dateStoredAs)
                .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                .tracking(PVTypeScale.micro * PVTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(PVColor.textMuted)
            Text(draft.summary)
                .font(PVFont.mono(size: PVTypeScale.caption))
                .foregroundStyle(PVColor.textPrimary)
        }
        .padding(PVSpacing.space5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PVColor.surfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous)
                .stroke(PVColor.borderSubtle, lineWidth: 1)
        )
    }

    private func cascadeField(
        _ label: LocalizedStringResource,
        text: Binding<String>,
        width: CGFloat?,
        mono: Bool,
        disabled: Bool = false,
        isInvalid: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space2) {
            Text(label)
                .font(PVFont.body(size: PVTypeScale.micro))
                .foregroundStyle(isInvalid ? PVColor.danger : PVColor.textSecondary)
            PVInput(text: text, size: .sm, mono: mono, isInvalid: isInvalid)
                .frame(width: width)
                .disabled(disabled)
                .opacity(disabled ? 0.42 : 1)
        }
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private func monthPicker(start: Bool) -> some View {
        VStack(alignment: .leading, spacing: PVSpacing.space2) {
            Text(L10n.Sources.dateMonth)
                .font(PVFont.body(size: PVTypeScale.micro))
                .foregroundStyle(PVColor.textSecondary)
            Picker("", selection: monthBinding(start)) {
                ForEach(months, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .labelsHidden()
            .disabled(yearBinding(start).wrappedValue.isEmpty)
            .opacity(yearBinding(start).wrappedValue.isEmpty ? 0.42 : 1)
            .frame(width: 136)
        }
    }

    private func yearBinding(_ start: Bool) -> Binding<String> {
        intFieldBinding(
            get: { start ? draft.startYear : draft.endYear },
            set: { value in
                if start {
                    draft.startYear = value
                    draft.applyStartCascade()
                } else {
                    draft.endYear = value
                    draft.applyEndCascade()
                }
            }
        )
    }

    private func monthBinding(_ start: Bool) -> Binding<String> {
        Binding(
            get: {
                let value = start ? draft.startMonth : draft.endMonth
                return value.map(String.init) ?? ""
            },
            set: { raw in
                let value = Int32(raw)
                if start {
                    draft.startMonth = value
                    draft.applyStartCascade()
                } else {
                    draft.endMonth = value
                    draft.applyEndCascade()
                }
            }
        )
    }

    private func dayBinding(_ start: Bool) -> Binding<String> {
        intFieldBinding(
            get: { start ? draft.startDay : draft.endDay },
            set: { value in
                if start {
                    draft.startDay = value
                    draft.applyStartCascade()
                } else {
                    draft.endDay = value
                    draft.applyEndCascade()
                }
            }
        )
    }

    private func hourBinding(_ start: Bool) -> Binding<String> {
        intFieldBinding(
            get: { start ? draft.startHour : draft.endHour },
            set: { value in
                if start {
                    draft.startHour = value
                    draft.applyStartCascade()
                } else {
                    draft.endHour = value
                    draft.applyEndCascade()
                }
            }
        )
    }

    private func minuteBinding(_ start: Bool) -> Binding<String> {
        intFieldBinding(
            get: { start ? draft.startMinute : draft.endMinute },
            set: { value in
                if start {
                    draft.startMinute = value
                    draft.applyStartCascade()
                } else {
                    draft.endMinute = value
                    draft.applyEndCascade()
                }
            }
        )
    }

    private func secondBinding(start: Bool) -> Binding<String> {
        intFieldBinding(
            get: { start ? draft.startSecond : draft.endSecond },
            set: { value in
                if start {
                    draft.startSecond = value
                    draft.applyStartCascade()
                } else {
                    draft.endSecond = value
                    draft.applyEndCascade()
                }
            }
        )
    }

    private func millisecondBinding(start: Bool) -> Binding<String> {
        intFieldBinding(
            get: { start ? draft.startMillisecond : draft.endMillisecond },
            set: { value in
                if start {
                    draft.startMillisecond = value
                    draft.applyStartCascade()
                } else {
                    draft.endMillisecond = value
                    draft.applyEndCascade()
                }
            }
        )
    }

    private func tzBinding(_ start: Bool) -> Binding<String> {
        start ? $draft.startTZ : $draft.endTZ
    }

    private func intFieldBinding(
        get: @escaping () -> Int32?,
        set: @escaping (Int32?) -> Void
    ) -> Binding<String> {
        Binding(
            get: { get().map(String.init) ?? "" },
            set: { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    set(nil)
                } else if let value = Int32(trimmed) {
                    set(value)
                }
            }
        )
    }
}
