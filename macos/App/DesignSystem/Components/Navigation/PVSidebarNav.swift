import SwiftUI

/// Mirrors `components/navigation/SidebarNav.jsx`, plus the `collapsed`
/// prop the S2-01 design brief added to that component (icon-only rail,
/// group label dropped in favour of the rail's own scroll column, hairline
/// divider — see the board's Frame 7 callout). One flat group of
/// destinations only; nested groups aren't ported since nothing needs them
/// yet.
///
/// `.accessibilityIdentifier` is normally left to the call site
/// (`DesignSystem/README.md`), but this component renders every row
/// itself, so there's no single returned `View` a call site could chain an
/// identifier onto — `PVSidebarNavItem.accessibilityIdentifier` carries
/// that call-site-owned value as data instead.
struct PVSidebarNavItem: Identifiable, Equatable {
    let id: String
    let label: LocalizedStringResource
    let icon: PVSymbol
    let accessibilityIdentifier: String

    static func == (lhs: PVSidebarNavItem, rhs: PVSidebarNavItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Provenencia's leading sidebar navigation list. Expanded mode shows an
/// optional group eyebrow plus icon + label rows; collapsed mode is an
/// icon-only rail exposing each destination's name via a system tooltip
/// and accessibility label. Both share the same idle / hover / selected /
/// disabled treatments (disabled follows the standard `.disabled(_:)`
/// environment, same as `PVButtonStyle`).
struct PVSidebarNav: View {
    let groupLabel: LocalizedStringResource?
    let items: [PVSidebarNavItem]
    let selection: String
    let collapsed: Bool
    let onSelect: (String) -> Void

    init(
        groupLabel: LocalizedStringResource? = nil,
        items: [PVSidebarNavItem],
        selection: String,
        collapsed: Bool,
        onSelect: @escaping (String) -> Void
    ) {
        self.groupLabel = groupLabel
        self.items = items
        self.selection = selection
        self.collapsed = collapsed
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: collapsed ? .center : .leading, spacing: PVSpacing.space1) {
            if let groupLabel, !collapsed {
                Text(groupLabel)
                    .font(PVFont.body(size: PVTypeScale.micro, weight: PVFontWeight.semibold))
                    .tracking(PVTypeScale.micro * PVTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(PVColor.textFaint)
                    .padding(.horizontal, PVSpacing.space4)
                    .padding(.bottom, PVSpacing.space2)
            }
            ForEach(items) { item in
                PVSidebarNavButton(
                    item: item,
                    isSelected: item.id == selection,
                    collapsed: collapsed,
                    action: { onSelect(item.id) }
                )
            }
        }
        .padding(collapsed ? PVSpacing.space4 : PVSpacing.space5)
        .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
    }
}

/// A `Button` plus modifiers chained *after* `.buttonStyle(.plain)` gives
/// the button two different hit-testing surfaces: the button's own tap
/// gesture sees only what's inside its label, while a separately-attached
/// `.onHover` sees the fully-composed outer view — an earlier version of
/// this row learned that the hard way, needing two different
/// `contentShape`s for two different pointer interactions. Routing
/// through a proper `ButtonStyle` (`PVSidebarNavRowStyle`/`Body` below),
/// backed by the shared `PVHoverEffect` every `ButtonStyle` body in this
/// design system now uses, collapses that back to one surface — click,
/// hover, and the pressed state all agree by construction.
private struct PVSidebarNavButton: View {
    let item: PVSidebarNavItem
    let isSelected: Bool
    let collapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PVSpacing.space5) {
                PVIcon(item.icon, size: collapsed ? 16 : 15)
                if !collapsed {
                    Text(item.label)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(PVSidebarNavRowStyle(isSelected: isSelected, collapsed: collapsed))
        .pvHelp(item.label, when: collapsed)
        .accessibilityLabel(Text(item.label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(item.accessibilityIdentifier)
    }
}

private struct PVSidebarNavRowStyle: ButtonStyle {
    let isSelected: Bool
    let collapsed: Bool

    func makeBody(configuration: Configuration) -> some View {
        PVSidebarNavRowBody(configuration: configuration, isSelected: isSelected, collapsed: collapsed)
    }
}

private struct PVSidebarNavRowBody: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    let collapsed: Bool

    var body: some View {
        PVHoverEffect(isPressed: configuration.isPressed) { showHover in
            let background: Color = isSelected ? PVColor.surfaceSelected : (showHover ? PVColor.surfaceHover : .clear)

            configuration.label
                .frame(width: collapsed ? 32 : nil, height: collapsed ? 32 : nil)
                .frame(maxWidth: collapsed ? nil : .infinity, alignment: .leading)
                .font(PVFont.body(size: PVTypeScale.bodySmall, weight: isSelected ? PVFontWeight.semibold : PVFontWeight.regular))
                .foregroundStyle(isSelected ? PVColor.textPrimary : PVColor.textSecondary)
                .padding(.horizontal, collapsed ? 0 : PVSpacing.space4)
                .padding(.vertical, collapsed ? 0 : PVSpacing.space4)
                .background(RoundedRectangle(cornerRadius: PVRadius.sm, style: .continuous).fill(background))
        }
    }
}

private extension View {
    /// Attaches a system tooltip only in `collapsed` mode, where the
    /// destination's label isn't visible as text.
    @ViewBuilder
    func pvHelp(_ text: LocalizedStringResource, when condition: Bool) -> some View {
        if condition {
            help(Text(text))
        } else {
            self
        }
    }
}

#Preview {
    let items = [
        PVSidebarNavItem(id: "sources", label: L10n.Workspace.sourcesTitle, icon: .library, accessibilityIdentifier: "preview.nav.sources"),
        PVSidebarNavItem(id: "source-types", label: L10n.Workspace.sourceTypesTitle, icon: .tag, accessibilityIdentifier: "preview.nav.sourceTypes"),
        PVSidebarNavItem(id: "source-fields", label: L10n.Workspace.sourceFieldsTitle, icon: .list, accessibilityIdentifier: "preview.nav.sourceFields"),
    ]
    return HStack(alignment: .top, spacing: PVSpacing.space9) {
        PVSidebarNav(groupLabel: L10n.Workspace.navGroupLabel, items: items, selection: "sources", collapsed: false, onSelect: { _ in })
            .frame(width: 220)
        PVSidebarNav(items: items, selection: "source-types", collapsed: true, onSelect: { _ in })
            .frame(width: 78)
    }
    .padding(PVSpacing.space9)
    .background(PVColor.surfaceCard)
}
