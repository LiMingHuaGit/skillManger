//
//  SkillLibraryView.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import SwiftUI
import OSLog

enum LibrarySection: String, CaseIterable, Identifiable {
    case library
    case recommendations
    case plugins
    case favorites
    case recents
    case settings

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        switch self {
        case .library: L10n.string("Library", locale: locale)
        case .recommendations: L10n.string("Recommended", locale: locale)
        case .plugins: L10n.string("Plugins", locale: locale)
        case .favorites: L10n.string("Favorites", locale: locale)
        case .recents: L10n.string("Recents", locale: locale)
        case .settings: L10n.string("Settings", locale: locale)
        }
    }

    var systemImage: String {
        switch self {
        case .library: "books.vertical"
        case .recommendations: "sparkles"
        case .plugins: "puzzlepiece.extension"
        case .favorites: "star"
        case .recents: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct SkillLibraryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var languageSettings: AppLanguageSettings
    @ObservedObject var launchAtLoginSettings: LaunchAtLoginSettings
    @State private var selectedSection: LibrarySection = .library
    @State private var selectedPluginID: PluginPackage.ID?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                sidebarHeader

                List(selection: $selectedSection) {
                    ForEach(LibrarySection.allCases) { section in
                        HStack(spacing: 10) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selectedSection == section ? SkillManagerTheme.accent : Color.secondary)
                                .frame(width: 18)
                            Text(section.title(locale: languageSettings.locale))
                                .font(.callout.weight(selectedSection == section ? .semibold : .regular))
                            Spacer()
                            if let count = sidebarCount(for: section) {
                                Text("\(count)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 3)
                            .tag(section)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .background(.thinMaterial)
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
            Group {
                if selectedSection == .settings {
                    EmptyStateView(title: L10n.string("Settings", locale: languageSettings.locale), message: L10n.string("Manage roots, templates, and indexing from the middle panel.", locale: languageSettings.locale), systemImage: "gearshape")
                } else if selectedSection == .plugins {
                    PluginDetailView(store: store, package: selectedPlugin)
                } else {
                    SkillDetailView(store: store, skill: selectedDisplayedSkill)
                }
            }
            .id(detailIdentity)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
        .tint(SkillManagerTheme.accent)
        .animation(interfaceAnimation, value: detailIdentity)
        .onChange(of: selectedSection) { _, newValue in
            let startedAt = PerformanceDiagnostics.start()
            PerformanceDiagnostics.library.info("section_change_started section=\(newValue.rawValue, privacy: .public) skills=\(store.skills.count)")
            applySection(newValue)
            PerformanceDiagnostics.finish(
                "section_change_sync",
                startedAt: startedAt,
                logger: PerformanceDiagnostics.library,
                itemCount: store.skills.count,
                details: "section=\(newValue.rawValue)",
                slowThresholdMS: 16
            )
            logNextMainQueueTurn(operation: "section_change_settled", startedAt: startedAt, details: "section=\(newValue.rawValue)")
        }
        .onChange(of: store.selectedSkillID) { oldValue, newValue in
            guard oldValue != newValue else { return }
            let startedAt = PerformanceDiagnostics.start()
            PerformanceDiagnostics.library.info("skill_selection_changed has_selection=\(newValue != nil) skills=\(store.skills.count)")
            logNextMainQueueTurn(operation: "skill_selection_settled", startedAt: startedAt, details: "has_selection=\(newValue != nil)")
        }
        .background(LibrarySplitViewAutosaveBridge())
    }

    private var skillList: some View {
        VStack(spacing: 0) {
            contentHeader(count: displayedSkills.count)
            toolbar
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
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
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 14, bottom: 1, trailing: 14))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(SkillManagerTheme.canvas)
                .animation(interfaceAnimation, value: displayedSkills.map(\.id))
            }
        }
        .background(SkillManagerTheme.canvas)
        .onAppear(perform: keepSkillSelectionInsideDisplayedSkills)
        .onChange(of: displayedSkills.map(\.id)) { _, _ in
            keepSkillSelectionInsideDisplayedSkills()
        }
    }

    private var pluginList: some View {
        VStack(spacing: 0) {
            contentHeader(count: displayedPlugins.count)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField(L10n.string("Search plugin name, marketplace, version, or path", locale: languageSettings.locale), text: $store.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(SkillManagerTheme.quietFill, in: RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous))
                    .accessibilityLabel(L10n.string("Search plugins", locale: languageSettings.locale))

                Button {
                    try? store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help(L10n.string("Re-index", locale: languageSettings.locale))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
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
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 14, bottom: 2, trailing: 14))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(SkillManagerTheme.canvas)
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
        .background(SkillManagerTheme.canvas)
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField(L10n.string("Search name, tag, use case, or path", locale: languageSettings.locale), text: $store.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(SkillManagerTheme.quietFill, in: RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous))
                    .accessibilityLabel(L10n.string("Search skills", locale: languageSettings.locale))

                Button {
                    try? store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help(L10n.string("Re-index", locale: languageSettings.locale))
            }

            if selectedSection == .recommendations {
                recommendationToolbar
            }

            HStack(spacing: 8) {
                Picker(categoryPickerTitle, selection: $store.selectedCategory) {
                    Text(allCategoriesTitle).tag(nil as SkillCategory?)
                    ForEach(SkillCategory.allCases) { category in
                        Label(category.title(locale: languageSettings.locale), systemImage: category.systemImage)
                            .tag(Optional(category))
                    }
                }
                .frame(width: 156)

                Picker(L10n.string("Sort", locale: languageSettings.locale), selection: $store.sortMode) {
                    ForEach(SkillSortMode.allCases) { mode in
                        Text(L10n.string(mode.localizationKey, locale: languageSettings.locale)).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 112)

                Picker(filterPickerTitle, selection: Binding(
                    get: { store.selectedFilter },
                    set: { filter in
                        store.selectedFilter = filter
                        selectedSection = section(for: filter)
                    }
                )) {
                    ForEach(SkillLibraryFilter.allCases) { filter in
                        Text(L10n.string(filter.localizationKey, locale: languageSettings.locale)).tag(filter)
                    }
                }
                .labelsHidden()
                .frame(width: 112)
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
        .padding(12)
        .background(SkillManagerTheme.accentSoft, in: RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous)
                .stroke(SkillManagerTheme.accent.opacity(0.16))
        }
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(SkillManagerTheme.accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Skill Manager")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Text(libraryInventoryText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func contentHeader(count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(selectedSection.title(locale: languageSettings.locale))
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
                .contentTransition(.numericText())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var libraryInventoryText: String {
        if languageSettings.locale.identifier.lowercased().hasPrefix("zh") {
            return "\(store.standaloneSkills.count) 个技能 · \(store.pluginPackages.count) 个插件"
        }
        return "\(store.standaloneSkills.count) skills · \(store.pluginPackages.count) plugins"
    }

    private func sidebarCount(for section: LibrarySection) -> Int? {
        switch section {
        case .library: store.standaloneSkills.count
        case .recommendations: store.skillRecommendations.count
        case .plugins: store.pluginPackages.count
        case .favorites: store.favoriteSkillIDs.count
        case .recents: store.recentSkillIDs.count
        case .settings: nil
        }
    }

    private var detailIdentity: String {
        if selectedSection == .settings {
            return "settings"
        }
        if selectedSection == .plugins {
            return "plugin:\(selectedPlugin?.id ?? "none")"
        }
        return "skill:\(selectedDisplayedSkill?.id ?? "none")"
    }

    private var interfaceAnimation: Animation? {
        reduceMotion ? nil : SkillManagerTheme.responsiveSpring
    }

    private func applySection(_ section: LibrarySection) {
        switch section {
        case .library: store.selectedFilter = .all
        case .recommendations: store.selectedFilter = .recommended
        case .plugins: store.selectedFilter = .all
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
        default: .library
        }
    }

    private var selectedPlugin: PluginPackage? {
        let plugins = displayedPlugins
        guard let selectedPluginID else { return plugins.first }
        return plugins.first { $0.id == selectedPluginID } ?? plugins.first
    }

    private var selectedDisplayedSkill: Skill? {
        let skills = displayedSkills
        guard let selectedSkillID = store.selectedSkillID else { return skills.first }
        return skills.first { $0.id == selectedSkillID } ?? skills.first
    }

    private var displayedSkills: [Skill] {
        let startedAt = PerformanceDiagnostics.start()
        let result: [Skill] = switch selectedSection {
        case .recommendations:
            filtered(store.recommendationRankedSkills)
        default:
            store.visibleSkills
        }
        PerformanceDiagnostics.finish(
            "displayed_skills",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            details: "section=\(selectedSection.rawValue)",
            slowThresholdMS: 12
        )
        return result
    }

    private var displayedPlugins: [PluginPackage] {
        let startedAt = PerformanceDiagnostics.start()
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let packages = store.pluginPackages
        let result = query.isEmpty ? packages : packages.filter { package in
            [package.name, package.marketplaceID, package.version ?? "", package.rootPath, package.displayName]
                .contains { $0.lowercased().contains(query) }
        }
        PerformanceDiagnostics.finish(
            "displayed_plugins",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            details: "source=\(packages.count) search=\(!query.isEmpty)",
            slowThresholdMS: 12
        )
        return result
    }

    private func filtered(_ skills: [Skill]) -> [Skill] {
        skills.filter(store.matchesSearchAndCategory)
    }

    private var categoryPickerTitle: String {
        languageSettings.locale.identifier.lowercased().hasPrefix("zh") ? "分类" : "Category"
    }

    private var allCategoriesTitle: String {
        languageSettings.locale.identifier.lowercased().hasPrefix("zh") ? "全部分类" : "All Categories"
    }

    private var filterPickerTitle: String {
        languageSettings.locale.identifier.lowercased().hasPrefix("zh") ? "筛选" : "Filter"
    }

    private func keepSkillSelectionInsideDisplayedSkills() {
        let startedAt = PerformanceDiagnostics.start()
        let skills = displayedSkills
        defer {
            PerformanceDiagnostics.finish(
                "selection_validation",
                startedAt: startedAt,
                logger: PerformanceDiagnostics.library,
                itemCount: skills.count,
                details: "section=\(selectedSection.rawValue)",
                slowThresholdMS: 12
            )
        }
        guard skills.isEmpty == false else {
            store.selectedSkillID = nil
            return
        }

        if let selectedSkillID = store.selectedSkillID,
           skills.contains(where: { $0.id == selectedSkillID }) {
            return
        }

        store.selectedSkillID = skills.first?.id
    }

    private func logNextMainQueueTurn(operation: String, startedAt: UInt64, details: String) {
        DispatchQueue.main.async {
            PerformanceDiagnostics.finish(
                operation,
                startedAt: startedAt,
                logger: PerformanceDiagnostics.library,
                itemCount: store.skills.count,
                details: details,
                slowThresholdMS: 32
            )
        }
    }
}

private struct LibrarySplitViewAutosaveBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> LibrarySplitViewAutosaveView {
        LibrarySplitViewAutosaveView()
    }

    func updateNSView(_ nsView: LibrarySplitViewAutosaveView, context: Context) {
        nsView.configureSplitViews()
    }
}

private final class LibrarySplitViewAutosaveView: NSView {
    private static let autosaveName = "SkillManager.LibrarySplitView"
    private var isConfigured = false
    private var isConfigurationScheduled = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureSplitViews()
    }

    func configureSplitViews() {
        guard isConfigured == false, isConfigurationScheduled == false else { return }
        isConfigurationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isConfigurationScheduled = false
            guard let contentView = window?.contentView else { return }
            let splitViews = Self.findSplitViews(in: contentView)
            for (index, splitView) in splitViews.enumerated() where splitView.autosaveName == nil {
                splitView.autosaveName = "\(Self.autosaveName).\(index)"
            }
            isConfigured = splitViews.isEmpty == false
        }
    }

    private static func findSplitViews(in view: NSView) -> [NSSplitView] {
        view.subviews.reduce(into: []) { result, subview in
            if let splitView = subview as? NSSplitView {
                result.append(splitView)
            }
            result.append(contentsOf: findSplitViews(in: subview))
        }
    }
}
