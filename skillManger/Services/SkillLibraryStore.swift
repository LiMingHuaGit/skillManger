//
//  SkillLibraryStore.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation
import Combine

protocol SkillPreferencesStoring: AnyObject {
    var favoriteSkillIDs: [String] { get set }
    var usageEvents: [UsageEvent] { get set }
    var templates: [PlatformTemplate] { get set }
    var roots: [SkillRoot] { get set }
    var defaultTemplateID: String { get set }
    var showSystemSkills: Bool { get set }
    var showPluginSkills: Bool { get set }
}

final class InMemorySkillPreferences: SkillPreferencesStoring {
    var favoriteSkillIDs: [String] = []
    var usageEvents: [UsageEvent] = []
    var templates: [PlatformTemplate] = PlatformTemplate.builtIns
    var roots: [SkillRoot] = []
    var defaultTemplateID: String = PlatformTemplate.codexLocalSkill.id
    var showSystemSkills: Bool = true
    var showPluginSkills: Bool = true
}

final class UserDefaultsSkillPreferences: SkillPreferencesStoring {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var favoriteSkillIDs: [String] {
        get { defaults.stringArray(forKey: "favoriteSkillIDs") ?? [] }
        set { defaults.set(newValue, forKey: "favoriteSkillIDs") }
    }

    var usageEvents: [UsageEvent] {
        get { decode([UsageEvent].self, key: "usageEvents") ?? [] }
        set { encode(newValue, key: "usageEvents") }
    }

    var templates: [PlatformTemplate] {
        get { decode([PlatformTemplate].self, key: "templates") ?? PlatformTemplate.builtIns }
        set { encode(newValue, key: "templates") }
    }

    var roots: [SkillRoot] {
        get { decode([SkillRoot].self, key: "roots") ?? [] }
        set { encode(newValue, key: "roots") }
    }

    var defaultTemplateID: String {
        get { defaults.string(forKey: "defaultTemplateID") ?? PlatformTemplate.codexLocalSkill.id }
        set { defaults.set(newValue, forKey: "defaultTemplateID") }
    }

    var showSystemSkills: Bool {
        get { defaults.object(forKey: "showSystemSkills") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showSystemSkills") }
    }

    var showPluginSkills: Bool {
        get { defaults.object(forKey: "showPluginSkills") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showPluginSkills") }
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

final class SkillLibraryStore: ObservableObject {
    private let preferences: SkillPreferencesStoring
    private let indexer: SkillIndexer
    private let codexSessionReader: CodexSessionContextReader
    private let recommender: SkillRecommender

    @Published var skills: [Skill]
    @Published var roots: [SkillRoot] {
        didSet { preferences.roots = roots }
    }
    @Published var searchText: String = ""
    @Published var selectedFilter: SkillLibraryFilter = .all
    @Published var sortMode: SkillSortMode = .relevance
    @Published var selectedSkillID: Skill.ID?
    @Published var lastCopiedText: String?
    @Published var toastMessage: String?
    @Published var codexSessions: [CodexSessionContext] = []
    @Published var selectedCodexSessionID: CodexSessionContext.ID? {
        didSet {
            guard selectedCodexSessionID != oldValue else { return }
            updateSkillRecommendations()
        }
    }
    @Published var skillRecommendations: [SkillRecommendation] = []
    @Published var recommendationError: String?

    init(
        preferences: SkillPreferencesStoring = UserDefaultsSkillPreferences(),
        indexer: SkillIndexer = SkillIndexer(),
        codexSessionReader: CodexSessionContextReader = CodexSessionContextReader(),
        recommender: SkillRecommender = SkillRecommender(),
        initialSkills: [Skill] = [],
        roots: [SkillRoot]? = nil,
        codexConfigURL: URL? = nil,
        homeDirectory: String = NSHomeDirectory()
    ) {
        self.preferences = preferences
        self.indexer = indexer
        self.codexSessionReader = codexSessionReader
        self.recommender = recommender
        let resolvedConfigURL = codexConfigURL ?? URL(fileURLWithPath: homeDirectory).appendingPathComponent(".codex/config.toml")
        self.skills = initialSkills
        self.roots = roots ?? Self.preferredRoots(from: preferences.roots, homeDirectory: homeDirectory, codexConfigURL: resolvedConfigURL)
        self.preferences.roots = self.roots
        selectedSkillID = initialSkills.first?.id
    }

    var templates: [PlatformTemplate] {
        get { preferences.templates }
        set {
            objectWillChange.send()
            preferences.templates = newValue
        }
    }

    var defaultTemplateID: String {
        get { preferences.defaultTemplateID }
        set {
            objectWillChange.send()
            preferences.defaultTemplateID = newValue
        }
    }

    var defaultTemplate: PlatformTemplate {
        templates.first { $0.id == defaultTemplateID } ?? PlatformTemplate.codexLocalSkill
    }

    var showSystemSkills: Bool {
        get { preferences.showSystemSkills }
        set {
            objectWillChange.send()
            preferences.showSystemSkills = newValue
            updateSkillRecommendations()
        }
    }

    var showPluginSkills: Bool {
        get { preferences.showPluginSkills }
        set {
            objectWillChange.send()
            preferences.showPluginSkills = newValue
            updateSkillRecommendations()
        }
    }

    var selectedSkill: Skill? {
        guard let selectedSkillID else { return visibleSkills.first }
        return skills.first { $0.id == selectedSkillID } ?? visibleSkills.first
    }

    var favoriteSkillIDs: Set<String> {
        Set(preferences.favoriteSkillIDs)
    }

    var recentSkillIDs: [String] {
        var seen = Set<String>()
        return preferences.usageEvents
            .sorted { $0.copiedAt > $1.copiedAt }
            .compactMap { event in
                guard seen.contains(event.skillID) == false else { return nil }
                seen.insert(event.skillID)
                return event.skillID
            }
    }

    var visibleSkills: [Skill] {
        var candidates = visibleSkillCandidates

        switch selectedFilter {
        case .all:
            break
        case .recommended:
            break
        case .favorites:
            candidates = candidates.filter { favoriteSkillIDs.contains($0.id) }
        case .recent:
            let recent = Set(recentSkillIDs)
            candidates = candidates.filter { recent.contains($0.id) }
        case .local:
            candidates = candidates.filter { $0.sourceType == .local }
        case .plugin:
            candidates = candidates.filter { $0.sourceType == .plugin }
        case .needsReview:
            candidates = candidates.filter(\.isNeedsReview)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty == false {
            candidates = candidates.filter { skill in
                ([skill.name, skill.description, skill.sourcePath] + skill.tags)
                    .contains { $0.lowercased().contains(query) }
            }
        }

        if selectedFilter == .recommended {
            return rankRecommendationsFirst(candidates)
        }

        return sort(candidates)
    }

    var recommendationRankedSkills: [Skill] {
        rankRecommendationsFirst(visibleSkillCandidates)
    }

    var selectedCodexSession: CodexSessionContext? {
        guard let selectedCodexSessionID else { return codexSessions.first }
        return codexSessions.first { $0.id == selectedCodexSessionID } ?? codexSessions.first
    }

    var recommendedSkills: [Skill] {
        skillRecommendations.map(\.skill)
    }

    var standaloneSkills: [Skill] {
        sort(skills.filter { $0.sourceType != .plugin })
    }

    var pluginSkills: [Skill] {
        sort(skills.filter { $0.sourceType == .plugin })
    }

    var pluginPackages: [PluginPackage] {
        let grouped = Dictionary(grouping: pluginSkills.compactMap { skill -> (PluginPackageIdentity, Skill)? in
            guard let identity = PluginPackageIdentity(skill: skill) else { return nil }
            return (identity, skill)
        }, by: { $0.0 })

        return grouped.map { identity, entries in
            let packageSkills = sort(entries.map(\.1))
            return PluginPackage(
                id: identity.id,
                name: identity.name,
                marketplaceID: identity.marketplaceID,
                version: identity.version,
                rootPath: identity.rootPath,
                skillCount: packageSkills.count,
                skillIDs: packageSkills.map(\.id)
            )
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func skills(forPluginID pluginID: PluginPackage.ID) -> [Skill] {
        guard let package = pluginPackages.first(where: { $0.id == pluginID }) else { return [] }
        let ids = Set(package.skillIDs)
        return sort(pluginSkills.filter { ids.contains($0.id) })
    }

    func duplicateSkills(for skill: Skill) -> [Skill] {
        skills
            .filter { candidate in
                candidate.name.caseInsensitiveCompare(skill.name) == .orderedSame && candidate.sourcePath != skill.sourcePath
            }
            .sorted { lhs, rhs in
                lhs.sourcePath.localizedCaseInsensitiveCompare(rhs.sourcePath) == .orderedAscending
            }
    }

    func refresh() throws {
        let enabledRoots = roots.filter(\.enabled).map { URL(fileURLWithPath: NSString(string: $0.path).expandingTildeInPath) }
        skills = try indexer.index(rootURLs: enabledRoots)
        selectedSkillID = selectedSkillID ?? skills.first?.id
        refreshRecommendations()
    }

    func refreshRecommendations() {
        do {
            let sessions = try codexSessionReader.recentContexts()
            codexSessions = sessions
            if selectedCodexSessionID == nil || sessions.contains(where: { $0.id == selectedCodexSessionID }) == false {
                selectedCodexSessionID = sessions.first?.id
            } else {
                updateSkillRecommendations()
            }
            recommendationError = nil
        } catch {
            codexSessions = []
            skillRecommendations = []
            recommendationError = error.localizedDescription
        }
    }

    func recommendation(for skillID: Skill.ID) -> SkillRecommendation? {
        skillRecommendations.first { $0.skill.id == skillID }
    }

    private func updateSkillRecommendations() {
        guard let selectedCodexSession else {
            skillRecommendations = []
            return
        }

        var candidates = skills
        if showSystemSkills == false {
            candidates = candidates.filter { $0.sourceType != .system }
        }
        if showPluginSkills == false {
            candidates = candidates.filter { $0.sourceType != .plugin }
        }

        skillRecommendations = recommender.recommendations(for: selectedCodexSession, skills: candidates)
    }

    private var visibleSkillCandidates: [Skill] {
        var candidates = skills

        if showSystemSkills == false {
            candidates = candidates.filter { $0.sourceType != .system }
        }

        if showPluginSkills == false {
            candidates = candidates.filter { $0.sourceType != .plugin }
        }

        return candidates
    }

    private func rankRecommendationsFirst(_ candidates: [Skill]) -> [Skill] {
        guard skillRecommendations.isEmpty == false else { return sort(candidates) }

        let recommendationRanks = Dictionary(uniqueKeysWithValues: skillRecommendations.enumerated().map { index, recommendation in
            (recommendation.skill.id, index)
        })

        let recommended = candidates
            .filter { recommendationRanks[$0.id] != nil }
            .sorted { lhs, rhs in
                (recommendationRanks[lhs.id] ?? Int.max) < (recommendationRanks[rhs.id] ?? Int.max)
            }
        let others = sort(candidates.filter { recommendationRanks[$0.id] == nil })

        return recommended + others
    }

    func toggleFavorite(skillID: Skill.ID) {
        objectWillChange.send()
        var ids = preferences.favoriteSkillIDs
        if ids.contains(skillID) {
            ids.removeAll { $0 == skillID }
        } else {
            ids.append(skillID)
        }
        preferences.favoriteSkillIDs = ids
    }

    func recordCopy(skillID: Skill.ID, templateID: String, copyType: String = "prompt") throws {
        objectWillChange.send()
        let event = UsageEvent(id: UUID(), skillID: skillID, platformTemplateID: templateID, copiedAt: Date(), copyType: copyType)
        preferences.usageEvents.append(event)
    }

    func copyText(for skill: Skill, template: PlatformTemplate, useCase: String? = nil) throws -> String {
        let text = try CopyTemplateEngine.render(template: template, skill: skill, useCase: useCase)
        try recordCopy(skillID: skill.id, templateID: template.id, copyType: template.templateType)
        defaultTemplateID = template.id
        lastCopiedText = text
        toastMessage = String(format: String(localized: "Copied for %@"), template.platformName)
        return text
    }

    func resetTemplates() {
        objectWillChange.send()
        templates = PlatformTemplate.builtIns
        defaultTemplateID = PlatformTemplate.codexLocalSkill.id
    }

    func updateTemplate(id: String, platformName: String, body: String) {
        objectWillChange.send()
        preferences.templates = templates.map { template in
            guard template.id == id else { return template }
            var updated = template
            updated.platformName = platformName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? template.platformName
            updated.body = body.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? template.body
            return updated
        }
    }

    func addCustomTemplate(named name: String, basedOn template: PlatformTemplate) {
        objectWillChange.send()
        var custom = template
        custom.id = "custom.\(UUID().uuidString)"
        custom.platformName = name
        custom.isBuiltIn = false
        custom.isDefault = false
        preferences.templates.append(custom)
    }

    private func sort(_ skills: [Skill]) -> [Skill] {
        switch sortMode {
        case .relevance, .name:
            return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .recentlyModified:
            return skills.sorted { $0.lastModifiedAt > $1.lastModifiedAt }
        case .recentlyUsed:
            let order = Dictionary(uniqueKeysWithValues: recentSkillIDs.enumerated().map { ($0.element, $0.offset) })
            return skills.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
        }
    }

    static func defaultRoots(homeDirectory: String = NSHomeDirectory(), codexConfigURL: URL? = nil) -> [SkillRoot] {
        let resolvedConfigURL = codexConfigURL ?? URL(fileURLWithPath: homeDirectory).appendingPathComponent(".codex/config.toml")
        let pluginRoots = CodexConfigPluginResolver()
            .activePluginRootURLs(configURL: resolvedConfigURL, homeDirectory: homeDirectory)
            .map { SkillRoot(path: $0.path, enabled: true, sourceType: .plugin, lastIndexedAt: nil, lastError: nil) }
        let fallbackPluginRoots = pluginRoots.isEmpty ? [SkillRoot(path: "\(homeDirectory)/.codex/plugins/cache", enabled: true, sourceType: .plugin, lastIndexedAt: nil, lastError: nil)] : pluginRoots

        return [
            SkillRoot(path: "\(homeDirectory)/.codex/skills", enabled: true, sourceType: .local, lastIndexedAt: nil, lastError: nil),
            SkillRoot(path: "\(homeDirectory)/.codex/skills/.system", enabled: true, sourceType: .system, lastIndexedAt: nil, lastError: nil)
        ] + fallbackPluginRoots
    }

    private static func preferredRoots(from persistedRoots: [SkillRoot], homeDirectory: String = NSHomeDirectory(), codexConfigURL: URL? = nil) -> [SkillRoot] {
        guard persistedRoots.isEmpty == false else { return defaultRoots(homeDirectory: homeDirectory, codexConfigURL: codexConfigURL) }

        let codexPluginPath = "\(homeDirectory)/.codex/plugins"
        let legacyPluginCachePath = "\(homeDirectory)/.codex/plugins/cache"
        var roots = persistedRoots.filter { $0.path != legacyPluginCachePath }
        roots.removeAll { $0.path == codexPluginPath }

        let pluginRoots = defaultRoots(homeDirectory: homeDirectory, codexConfigURL: codexConfigURL)
            .filter { $0.sourceType == .plugin }
        for pluginRoot in pluginRoots where roots.contains(where: { $0.path == pluginRoot.path }) == false {
            roots.append(pluginRoot)
        }

        return roots
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}

private struct PluginPackageIdentity: Hashable {
    var name: String
    var marketplaceID: String
    var version: String?
    var rootPath: String

    var id: String { "\(name)@\(marketplaceID)" }

    init?(skill: Skill) {
        guard skill.sourceType == .plugin else { return nil }
        let components = URL(fileURLWithPath: skill.sourcePath).pathComponents

        if let cacheIndex = components.firstIndex(of: "cache"), components.indices.contains(cacheIndex + 3) {
            marketplaceID = components[cacheIndex + 1]
            name = components[cacheIndex + 2]
            version = components[cacheIndex + 3]
            rootPath = components[0...cacheIndex + 3].joined(separator: "/").replacingOccurrences(of: "//", with: "/")
            return
        }

        if let pluginsIndex = components.firstIndex(of: "plugins"), components.indices.contains(pluginsIndex + 3), components[pluginsIndex + 2] == "plugins" {
            marketplaceID = components[pluginsIndex + 1]
            name = components[pluginsIndex + 3]
            version = nil
            rootPath = components[0...pluginsIndex + 3].joined(separator: "/").replacingOccurrences(of: "//", with: "/")
            return
        }

        return nil
    }
}
