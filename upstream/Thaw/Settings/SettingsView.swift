//
//  SettingsView.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import AppKit
import SwiftUI
import ThawUI

// MARK: - SettingsView

struct SettingsView: View {
    let appState: AppState
    let navigationState: AppNavigationState
    let generalSettings: GeneralSettings

    var body: some View {
        SimpleModeSettingsPane(itemManager: appState.itemManager, settings: generalSettings)
            .frame(minWidth: 620, minHeight: 500)
            .navigationTitle("Neat")
            .onAppear {
                navigationState.isSimpleModeSettings = true
            }
    }
}

// MARK: - SettingsDetailLayout

enum SettingsDetailLayout {
    /// Comfortable reading width for settings groups. Title and form share this
    /// column so they stay aligned when the window grows.
    static let columnMaxWidth: CGFloat = 748
    /// Offset from the window top under the transparent unified toolbar.
    /// Intentionally well below the ~60pt safe-area push.
    static let titleTopInset: CGFloat = 28

    /// Leading inset aligned with grouped form section cards / headers.
    static let titleHorizontalInset: CGFloat = 28
}

extension EnvironmentValues {
    @Entry var settingsPaneTitle: LocalizedStringKey?
}

// MARK: - BehindWindowMaterialBackground

/// Behind-window vibrancy so surfaces sample the desktop rather than the
/// system-owned NavigationSplitView backdrop beneath the SwiftUI layer.
/// The behind-window material every Thaw window surface is built on. Shared
/// with the What's New reader so it sits on the same glass as the panes.
struct BehindWindowMaterialBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context _: Context) {
        configure(view)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
    }
}

/// The system glass button, unmodified: its own padding and shape, so a
/// Settings button looks like one in System Settings and follows macOS as the
/// style changes. Kept as a name so call sites say what they mean.
extension PrimitiveButtonStyle where Self == GlassButtonStyle {
    static var settingsGlass: GlassButtonStyle {
        .glass
    }
}

// MARK: - SettingsDetailHeader

/// The toolbar's overflow menu: window-level switches that have no pane of their own.
/// Anything with a row in a pane stays out, so each setting has one home.
private struct SettingsOverflowMenu: View {
    let appState: AppState
    let generalSettings: GeneralSettings
    @Binding var isCustomizeSidebarPresented: Bool

    var body: some View {
        @Bindable var generalSettings = generalSettings
        let menuBarManager = appState.menuBarManager
        Menu {
            Button(menuBarManager.isSwapped ? "Swap Back" : "Swap Shown and Hidden Items") {
                menuBarManager.toggleSwap()
            }
            Button(menuBarManager.isZenModeActive ? "Leave Zen Mode" : "Zen Mode") {
                menuBarManager.toggleZenMode()
            }
            Divider()
            Menu {
                AppUIZoomControls(showsShortcuts: false)
            } label: {
                Text("Zoom")
            }
            Divider()
            Toggle("Simple Mode", isOn: $generalSettings.simpleMode)
            // Simple Mode has no sidebar to customize, and the sheet is only
            // attached to the full window.
            if !generalSettings.simpleMode {
                Divider()
                Button("Customize Sidebar…") {
                    isCustomizeSidebarPresented = true
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .menuIndicator(.hidden)
    }
}

// MARK: - SettingsSearchResults

/// Search results in the detail column, on the same reading width as the
/// panes they stand in for.
private struct SettingsSearchResults: View {
    @Environment(SearchModel.self) private var searchModel
    let navigationState: AppNavigationState

    private var resultCount: Int {
        searchModel.displayedGroups.reduce(0) { $0 + $1.entries.count }
    }

    var body: some View {
        @Bindable var searchModel = searchModel
        if searchModel.displayedGroups.isEmpty {
            SearchEmptyView(query: searchModel.searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // A count makes a long list read as bounded, and tells the
                // reader whether narrowing the query is worth it.
                Text("^[\(resultCount) result](inflect: true)")
                    .font(ThawType.detail.weight(.medium))
                    .foregroundStyle(ThawInk.supporting)
                    .padding(.horizontal, SettingsDetailLayout.titleHorizontalInset + 6)
                    .padding(.bottom, 6)
                    .accessibilityAddTraits(.updatesFrequently)

                SearchResultsList(groups: searchModel.displayedGroups) { entry in
                    SettingsSearchNavigation.selectSearchResult(
                        entry,
                        navigationState: navigationState,
                        query: &searchModel.searchText
                    )
                }
                .frame(maxWidth: SettingsDetailLayout.columnMaxWidth)
                .padding(.horizontal, SettingsDetailLayout.titleHorizontalInset - 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - SettingsSidebar

/// The sidebar: a plain source list of panes over a pinned profile control.
///
/// The pane header names the pane; the sidebar only ever lists where to go
/// and which profile is live.
private struct SettingsSidebar: View {
    @Environment(SearchModel.self) private var searchModel
    let appState: AppState
    let navigationState: AppNavigationState
    let generalSettings: GeneralSettings

    private static let listWidth: CGFloat = 210

    var body: some View {
        // The profile switcher lives in the toolbar, so the list runs to the
        // foot of the sidebar.
        SettingsSidebarPaneList(navigationState: navigationState)
            .navigationSplitViewColumnWidth(min: Self.listWidth, ideal: Self.listWidth, max: 250)
            .onChange(of: generalSettings.simpleMode) { _, _ in
                searchModel.updateDisplayedItems()
            }
    }
}

// MARK: - SettingsSidebarPanes

/// The sidebar's direct destinations, one flat list with no headings.
///
/// The basics (General, Layout, Visibility, Appearance, Thaw Bar) sit at the
/// top, with About last. Custom Status Icon is not a destination: it is an
/// Experiments toggle. Scripts is an unbuilt
/// placeholder with no route from the window.
enum SettingsSidebarPanes {
    /// One sidebar group: its direct destinations. Groups are separated by a
    /// small gap, with no text heading, the way macOS Settings separates its
    /// top group from the rest.
    struct Group: Identifiable {
        let panes: [SettingsNavigationIdentifier]

        /// A group is never empty: visibleGroups(hidden:) drops empty ones.
        var id: SettingsNavigationIdentifier {
            panes[0]
        }
    }

    static let groups: [Group] = [
        // The basics sit at the top: the everyday surfaces (General, Menu Bar,
        // Appearance, Thaw Bar) need no heading.
        Group(panes: [
            .general, .menuBarLayout, .visibility, .menuBarAppearance, .thawBar,
            .profiles, .hotkeys, .automation, .displays,
            .privacy, .theLab, .tools, .about,
        ]),
    ]

    /// Every direct destination, flattened.
    static let all: [SettingsNavigationIdentifier] = groups.flatMap(\.panes)

    /// Groups with hidden panes filtered out. A group that empties entirely is
    /// dropped so no empty section sits in the sidebar.
    static func visibleGroups(hidden: Set<String>) -> [Group] {
        groups.compactMap { group in
            let panes = group.panes.filter { !hidden.contains($0.rawValue) }
            return panes.isEmpty ? nil : Group(panes: panes)
        }
    }
}

// MARK: - SettingsProfileChip

/// The toolbar's chip for the live profile, with a menu to switch, in the
/// spot Xcode gives its scheme: the one setting people change most often
/// without wanting the Profiles pane.
private struct SettingsProfileChip: View {
    @Environment(SearchModel.self) private var searchModel
    let appState: AppState
    let navigationState: AppNavigationState
    @State private var errorMessage: String?

    private var profileManager: ProfileManager {
        appState.profileManager
    }

    private var activeProfile: ProfileMetadata? {
        guard let id = profileManager.activeProfileID else {
            return nil
        }
        return profileManager.profiles.first { $0.id == id }
    }

    private var activeProfileName: String {
        activeProfile?.name ?? String(localized: "No active profile")
    }

    /// Loads and applies a profile the way the status item menu does.
    ///
    /// Throws rather than swallowing a failed load: a profile that cannot be
    /// read closes the menu and changes nothing, which reads as the app
    /// ignoring the choice. Callers surface it the way the Profiles pane
    /// does, so the same failure says the same thing wherever it happens.
    static func apply(_ metadata: ProfileMetadata, appState: AppState) throws {
        let profileManager = appState.profileManager
        guard metadata.id != profileManager.activeProfileID else {
            return
        }
        let profile = try profileManager.loadProfile(id: metadata.id)
        let previousID = profileManager.activeProfileID
        profileManager.activeProfileID = metadata.id
        profileManager.applyProfile(profile, to: appState, previousProfileID: previousID)
    }

    var body: some View {
        Menu {
            if profileManager.profiles.isEmpty {
                Text("No profiles saved")
            } else {
                ForEach(profileManager.profiles) { profile in
                    Button {
                        apply(profile)
                    } label: {
                        if profile.id == profileManager.activeProfileID {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }
            }
            Divider()
            Button("Manage Profiles…") {
                // A sidebar jump ends the search, or the detail column keeps stale results.
                searchModel.searchText = ""
                SettingsSearchNavigation.selectSidebarPane(.profiles, navigationState: navigationState)
            }
        } label: {
            Label(activeProfileName, systemImage: "person.crop.rectangle.stack")
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        }
        .menuIndicator(.visible)
        .fixedSize()
        .help("Active profile")
        .accessibilityLabel("Active profile")
        .accessibilityValue(activeProfileName)
        .errorAlert("Couldn’t switch profile", message: $errorMessage)
    }

    private func apply(_ metadata: ProfileMetadata) {
        do {
            try Self.apply(metadata, appState: appState)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - SettingsSidebarPaneList

/// The settings sidebar navigation list: a standard macOS source list, one
/// SF Symbol and one label per row, and nothing drawn by hand.
///
/// The selection binding is what makes it a source list rather than a stack
/// of buttons: AppKit draws the selected row, walks it with the arrow keys,
/// emphasises it while the list holds key focus and greys it when focus is
/// elsewhere, and reports the selected row to VoiceOver. Selection, hover
/// and keyboard focus are all the system's marks here; a row that paints
/// its own only ends up fighting the fill underneath it.
private struct SettingsSidebarPaneList: View {
    @Environment(SearchModel.self) private var searchModel
    let navigationState: AppNavigationState

    /// Width of the icon column, so labels line up whatever each symbol's
    /// own width is.
    private static let iconColumn: CGFloat = 22

    @Environment(\.colorScheme) private var colorScheme

    /// The accent, deepened in dark mode so a light one such as yellow keeps
    /// its contrast against the selected label.
    private var accent: Color {
        colorScheme == .dark ? Color.accentColor.mix(with: .black, by: 0.4) : Color.accentColor
    }

    private var selection: Binding<SettingsNavigationIdentifier?> {
        Binding {
            // Routes outside the sidebar, such as Scripts, select no row.
            SettingsSidebarPanes.all.contains(navigationState.settingsNavigationIdentifier)
                ? navigationState.settingsNavigationIdentifier
                : nil
        } set: { pane in
            guard let pane else {
                return
            }
            // Clear the search first: the clicked pane may already be selected,
            // and a leftover search would keep the detail column on results.
            searchModel.searchText = ""
            SettingsSearchNavigation.selectSidebarPane(pane, navigationState: navigationState)
        }
    }

    var body: some View {
        let visible = SettingsSidebarPanes.visibleGroups(hidden: navigationState.hiddenSidebarPanes)
            .flatMap(\.panes)
        // One list and no Sections: a Section makes SwiftUI back the list with
        // an outline view, and switching into that mode crashes AppKit on a
        // freed row view (sizeLastColumnToFit) on macOS 27.0 and 27.2.
        List(selection: selection) {
            ForEach(visible, id: \.self) { identifier in
                let isSelected = identifier == navigationState.settingsNavigationIdentifier
                Label {
                    Text(identifier.localized)
                        .font(ThawType.detail.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                } icon: {
                    identifier.iconResource.view
                        .font(ThawType.symbol.weight(.medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: Self.iconColumn)
                }
                // Only the selection fill carries the accent. Applied per row,
                // where the sidebar reads it.
                .listItemTint(isSelected ? .preferred(accent) : .monochrome)
            }
        }
        .listStyle(.sidebar)
        // The selection fill uses the same deepened accent.
        .tint(accent)
        // Medium rows whatever the system's sidebar size: at Large the labels
        // and symbols crowd a settings window this narrow.
        .environment(\.sidebarRowSize, .medium)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, ThawSpacing.base, for: .scrollContent)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

// MARK: - Toolbar pieces

/// Back and forward through the panes visited in this window, like a
/// browser, so a detour to check one setting is one click back.
@MainActor
@Observable
final class SettingsPaneHistory {
    private(set) var back: [SettingsNavigationIdentifier] = []
    private(set) var forward: [SettingsNavigationIdentifier] = []
    /// Set while a history move is changing the pane, so the change is not
    /// recorded as a new visit.
    private var isTravelling = false

    func record(leaving pane: SettingsNavigationIdentifier) {
        guard !isTravelling else { return }
        back.append(pane)
        if back.count > 50 {
            back.removeFirst()
        }
        forward.removeAll()
    }

    func goBack(from current: SettingsNavigationIdentifier, navigationState: AppNavigationState) {
        guard let target = back.popLast() else { return }
        forward.append(current)
        travel(to: target, navigationState: navigationState)
    }

    func goForward(from current: SettingsNavigationIdentifier, navigationState: AppNavigationState) {
        guard let target = forward.popLast() else { return }
        back.append(current)
        travel(to: target, navigationState: navigationState)
    }

    private func travel(to pane: SettingsNavigationIdentifier, navigationState: AppNavigationState) {
        isTravelling = true
        SettingsSearchNavigation.selectSidebarPane(pane, navigationState: navigationState)
        isTravelling = false
    }
}

private struct SettingsHistoryButtons: View {
    let history: SettingsPaneHistory
    let navigationState: AppNavigationState

    var body: some View {
        Button {
            history.goBack(from: navigationState.settingsNavigationIdentifier, navigationState: navigationState)
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
        .disabled(history.back.isEmpty)
        .help("Back")

        Button {
            history.goForward(from: navigationState.settingsNavigationIdentifier, navigationState: navigationState)
        } label: {
            Label("Forward", systemImage: "chevron.forward")
        }
        .disabled(history.forward.isEmpty)
        .help("Forward")
    }
}
