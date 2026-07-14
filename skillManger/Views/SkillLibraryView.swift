//
//  SkillLibraryView.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case library
    case favorites
    case recents
    case settings

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        switch self {
        case .library: L10n.string("Library", locale: locale)
        case .favorites: L10n.string("Favorites", locale: locale)
        case .recents: L10n.string("Recents", locale: locale)
        case .settings: L10n.string("Settings", locale: locale)
        }
    }

    var systemImage: String {
        switch self {
        case .library: "books.vertical"
        case .favorites: "star"
        case .recents: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct SkillLibraryView: View {
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var languageSettings: AppLanguageSettings
    @State private var selectedSection: LibrarySection = .library

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
            .navigationTitle("Skills")
            .frame(minWidth: 190)
        } content: {
            if selectedSection == .settings {
                SettingsView(store: store, languageSettings: languageSettings)
            } else {
                skillList
            }
        } detail: {
            if selectedSection == .settings {
                EmptyStateView(title: L10n.string("Settings", locale: languageSettings.locale), message: L10n.string("Manage roots, templates, and indexing from the middle panel.", locale: languageSettings.locale), systemImage: "gearshape")
            } else {
                SkillDetailView(store: store, skill: store.selectedSkill)
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

            if store.visibleSkills.isEmpty {
                EmptyStateView(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: store.skills.isEmpty ? "tray" : "magnifyingglass"
                )
            } else {
                List(selection: $store.selectedSkillID) {
                    ForEach(store.visibleSkills) { skill in
                        SkillRowView(skill: skill, isFavorite: store.favoriteSkillIDs.contains(skill.id))
                            .tag(skill.id)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(selectedSection.title(locale: languageSettings.locale))
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search name, tag, use case, or path", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search skills")

                Picker("Sort", selection: $store.sortMode) {
                    ForEach(SkillSortMode.allCases) { mode in
                        Text(L10n.string(mode.localizationKey, locale: languageSettings.locale)).tag(mode)
                    }
                }
                .labelsHidden()

                Button {
                    try? store.refresh()
                } label: {
                    Label("Re-index", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
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
        store.skills.isEmpty ? L10n.string("No skills indexed", locale: languageSettings.locale) : L10n.string("No matching skills", locale: languageSettings.locale)
    }

    private var emptyMessage: String {
        store.skills.isEmpty
        ? L10n.string("Add a skill root in Settings or check that local skill folders are readable.", locale: languageSettings.locale)
        : L10n.string("Try another search term or switch filters.", locale: languageSettings.locale)
    }

    private func applySection(_ section: LibrarySection) {
        switch section {
        case .library: store.selectedFilter = .all
        case .favorites: store.selectedFilter = .favorites
        case .recents: store.selectedFilter = .recent
        case .settings: break
        }
    }

    private func section(for filter: SkillLibraryFilter) -> LibrarySection {
        switch filter {
        case .favorites: .favorites
        case .recent: .recents
        default: .library
        }
    }
}
