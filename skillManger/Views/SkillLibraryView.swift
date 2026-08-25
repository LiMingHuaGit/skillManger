//
//  SkillLibraryView.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case library
    case recommendations
    case standaloneSkills
    case plugins
    case pluginSkills
    case favorites
    case recents
    case settings

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        switch self {
        case .library: L10n.string("Library", locale: locale)
        case .recommendations: L10n.string("Recommended", locale: locale)
        case .standaloneSkills: L10n.string("Standalone Skills", locale: locale)
        case .plugins: L10n.string("Plugins", locale: locale)
        case .pluginSkills: L10n.string("Plugin Skills", locale: locale)
        case .favorites: L10n.string("Favorites", locale: locale)
        case .recents: L10n.string("Recents", locale: locale)
        case .settings: L10n.string("Settings", locale: locale)
        }
    }

    var systemImage: String {
        switch self {
        case .library: "books.vertical"
        case .recommendations: "sparkles"
        case .standaloneSkills: "text.book.closed"
        case .plugins: "puzzlepiece.extension"
        case .pluginSkills: "square.stack.3d.up"
        case .favorites: "star"
        case .recents: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct SkillLibraryView: View {
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var languageSettings: AppLanguageSettings
    @ObservedObject var launchAtLoginSettings: LaunchAtLoginSettings
    @State private var selectedSection: LibrarySection = .library
    @State private var selectedPluginID: PluginPackage.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Section("Skill Manager") {
                    ForEach(LibrarySection.allCases) { section in
                        Label(section.title(locale: languageSettings.locale), systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
            .navigationTitle(L10n.string("Skills", locale: languageSettings.locale))
            .frame(minWidth: 190)
        } content: {
            if selectedSection == .settings {
                SettingsView(store: store, languageSettings: languageSettings, launchAtLoginSettings: launchAtLoginSettings)
            } else if selectedSection == .plugins {
                pluginList
            } else {
                skillList
            }
        } detail: {
            if selectedSection == .settings {
                EmptyStateView(title: L10n.string("Settings", locale: languageSettings.locale), message: L10n.string("Manage roots, templates, and indexing from the middle panel.", locale: languageSettings.locale), systemImage: "gearshape")
            } else if selectedSection == .plugins {
                PluginDetailView(store: store, package: selectedPlugin)
            } else {
                SkillDetailView(store: store, skill: selectedDisplayedSkill)
            }
        }
        .onChange(of: selectedSection) { _, newValue in
            applySection(newValue)
        }
    }

    private var skillList: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(16)
                .background(.background)
            Divider()

            if displayedSkills.isEmpty {
                EmptyStateView(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: store.skills.isEmpty ? "tray" : "magnifyingglass"
                )
            } else {
                List(selection: $store.selectedSkillID) {
                    ForEach(displayedSkills) { skill in
                        if selectedSection == .recommendations, let recommendation = store.recommendation(for: skill.id) {
                            RecommendedSkillRowView(recommendation: recommendation, isFavorite: store.favoriteSkillIDs.contains(skill.id))
                                .tag(skill.id)
                        } else {
                            SkillRowView(skill: skill, isFavorite: store.favoriteSkillIDs.contains(skill.id))
                                .tag(skill.id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(selectedSection.title(locale: languageSettings.locale))
        .onAppear(perform: keepSkillSelectionInsideDisplayedSkills)
        .onChange(of: displayedSkills) { _, _ in
            keepSkillSelectionInsideDisplayedSkills()
        }
    }

    private var pluginList: some View {
        VStack(spacing: 0) {
            HStack {
                TextField(L10n.string("Search plugin name, marketplace, version, or path", locale: languageSettings.locale), text: $store.searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(L10n.string("Search plugins", locale: languageSettings.locale))

                Button {
                    try? store.refresh()
                } label: {
                    Label(L10n.string("Re-index", locale: languageSettings.locale), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .background(.background)
            Divider()

            if displayedPlugins.isEmpty {
                EmptyStateView(
                    title: L10n.string("No plugins indexed", locale: languageSettings.locale),
                    message: L10n.string("Enabled Codex plugins will appear here after indexing.", locale: languageSettings.locale),
                    systemImage: "puzzlepiece.extension"
                )
            } else {
                List(selection: $selectedPluginID) {
                    ForEach(displayedPlugins) { package in
                        PluginRowView(package: package)
                            .tag(package.id)
                    }
                }
                .listStyle(.inset)
                .onAppear {
                    selectedPluginID = selectedPluginID ?? displayedPlugins.first?.id
                }
                .onChange(of: displayedPlugins) { _, plugins in
                    if selectedPluginID == nil || plugins.contains(where: { $0.id == selectedPluginID }) == false {
                        selectedPluginID = plugins.first?.id
                    }
                }
            }
        }
        .navigationTitle(selectedSection.title(locale: languageSettings.locale))
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField(L10n.string("Search name, tag, use case, or path", locale: languageSettings.locale), text: $store.searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(L10n.string("Search skills", locale: languageSettings.locale))

                Picker(L10n.string("Sort", locale: languageSettings.locale), selection: $store.sortMode) {
                    ForEach(SkillSortMode.allCases) { mode in
                        Text(L10n.string(mode.localizationKey, locale: languageSettings.locale)).tag(mode)
                    }
                }
                .labelsHidden()

                Button {
                    try? store.refresh()
                } label: {
                    Label(L10n.string("Re-index", locale: languageSettings.locale), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if selectedSection == .recommendations {
                recommendationToolbar
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SkillLibraryFilter.allCases) { filter in
                        Button(L10n.string(filter.localizationKey, locale: languageSettings.locale)) {
                            store.selectedFilter = filter
                            selectedSection = section(for: filter)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(store.selectedFilter == filter ? .black : .gray.opacity(0.2))
                        .foregroundStyle(store.selectedFilter == filter ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        if selectedSection == .recommendations {
            return L10n.string("No recommended skills", locale: languageSettings.locale)
        }
        return store.skills.isEmpty ? L10n.string("No skills indexed", locale: languageSettings.locale) : L10n.string("No matching skills", locale: languageSettings.locale)
    }

    private var emptyMessage: String {
        if selectedSection == .recommendations {
            return store.recommendationError ?? L10n.string("Pick or refresh a recent Codex chat to match it with your local skills.", locale: languageSettings.locale)
        }
        return store.skills.isEmpty
        ? L10n.string("Add a skill root in Settings or check that local skill folders are readable.", locale: languageSettings.locale)
        : L10n.string("Try another search term or switch filters.", locale: languageSettings.locale)
    }

    private var recommendationToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(L10n.string("Recommended from Codex", locale: languageSettings.locale), systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))

                Picker(L10n.string("Codex chat", locale: languageSettings.locale), selection: $store.selectedCodexSessionID) {
                    ForEach(store.codexSessions) { session in
                        Text(session.displayTitle)
                            .lineLimit(1)
                            .tag(Optional(session.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 360)

                Button {
                    store.refreshRecommendations()
                } label: {
                    Label(L10n.string("Refresh recommendations", locale: languageSettings.locale), systemImage: "wand.and.sparkles")
                }
                .buttonStyle(.bordered)
            }

            if let session = store.selectedCodexSession {
                HStack(spacing: 6) {
                    CodexSessionTitleView(session: session)
                    Text(L10n.format("%d recommended skills", locale: languageSettings.locale, store.skillRecommendations.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
            } else if let recommendationError = store.recommendationError {
                Text(recommendationError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }

    private func applySection(_ section: LibrarySection) {
        switch section {
        case .library: store.selectedFilter = .all
        case .recommendations:
            store.selectedFilter = .recommended
            store.refreshRecommendations()
        case .standaloneSkills: store.selectedFilter = .all
        case .plugins: store.selectedFilter = .all
        case .pluginSkills: store.selectedFilter = .plugin
        case .favorites: store.selectedFilter = .favorites
        case .recents: store.selectedFilter = .recent
        case .settings: break
        }
    }

    private func section(for filter: SkillLibraryFilter) -> LibrarySection {
        switch filter {
        case .recommended: .recommendations
        case .favorites: .favorites
        case .recent: .recents
        case .plugin: .pluginSkills
        default: .library
        }
    }

    private var selectedPlugin: PluginPackage? {
        guard let selectedPluginID else { return displayedPlugins.first }
        return displayedPlugins.first { $0.id == selectedPluginID } ?? displayedPlugins.first
    }

    private var selectedDisplayedSkill: Skill? {
        guard let selectedSkillID = store.selectedSkillID else { return displayedSkills.first }
        return displayedSkills.first { $0.id == selectedSkillID } ?? displayedSkills.first
    }

    private var displayedSkills: [Skill] {
        switch selectedSection {
        case .recommendations:
            return filtered(store.recommendationRankedSkills)
        case .standaloneSkills:
            return filtered(store.standaloneSkills)
        case .pluginSkills:
            return filtered(store.pluginSkills)
        default:
            return store.visibleSkills
        }
    }

    private var displayedPlugins: [PluginPackage] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return store.pluginPackages }
        return store.pluginPackages.filter { package in
            [package.name, package.marketplaceID, package.version ?? "", package.rootPath, package.displayName]
                .contains { $0.lowercased().contains(query) }
        }
    }

    private func filtered(_ skills: [Skill]) -> [Skill] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return skills }
        return skills.filter { skill in
            ([skill.name, skill.description, skill.sourcePath] + skill.tags)
                .contains { $0.lowercased().contains(query) }
        }
    }

    private func keepSkillSelectionInsideDisplayedSkills() {
        guard displayedSkills.isEmpty == false else {
            store.selectedSkillID = nil
            return
        }

        if let selectedSkillID = store.selectedSkillID,
           displayedSkills.contains(where: { $0.id == selectedSkillID }) {
            return
        }

        store.selectedSkillID = displayedSkills.first?.id
    }
}
