import SwiftUI

/// Minimal Source page stand-in until S2-18 ships the real page. Exists so
/// list row activation and Add Source → Create can navigate away from the
/// list without inventing master–detail chrome.
struct SourcePageStubView: View {
    let source: CatalogSource?
    let typeLabel: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PVSpacing.space7) {
            Button {
                onBack()
            } label: {
                HStack(spacing: PVSpacing.space3) {
                    PVIcon(.chevronForward, size: 12)
                        .rotationEffect(.degrees(180))
                    Text(L10n.Sources.stubBack)
                }
            }
            .buttonStyle(.pv(.link, size: .sm))
            .accessibilityIdentifier("sources.stub.back")

            VStack(alignment: .leading, spacing: PVSpacing.space3) {
                if let source {
                    Text(source.title.isEmpty ? source.ref : source.title)
                        .font(PVFont.display(size: PVTypeScale.h1, weight: PVFontWeight.semibold))
                        .foregroundStyle(PVColor.textDisplay)
                    HStack(spacing: PVSpacing.space5) {
                        if !typeLabel.isEmpty {
                            Text(typeLabel)
                                .font(PVFont.body(size: PVTypeScale.bodySmall))
                                .foregroundStyle(PVColor.textSecondary)
                        }
                        Text(source.ref)
                            .font(PVFont.mono(size: PVTypeScale.caption))
                            .foregroundStyle(PVColor.textMuted)
                    }
                }
                Text(L10n.Sources.stubNote)
                    .font(PVFont.body(size: PVTypeScale.bodySmall, italic: true))
                    .foregroundStyle(PVColor.textMuted)
                    .frame(maxWidth: PVSpacing.measureProse, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PVSpacing.gutterPage)
        .padding(.top, PVSpacing.space8)
        .padding(.bottom, PVSpacing.space9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PVColor.surfacePage)
        .accessibilityIdentifier("sources.stub")
    }
}
