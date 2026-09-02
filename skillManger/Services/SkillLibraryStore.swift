//
//  SkillLibraryStore.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation
import Combine
import OSLog

protocol SkillPreferencesStoring: AnyObject {
    var favoriteSkillIDs: [String] { get set }
    var usageEvents: [UsageEvent] { get set }
    var templates: [PlatformTemplate] { get set }
    var roots: [SkillRoot] { get set }
    var defaultTemplateID: String { get set }
    var showSystemSkills: Bool { get set }
}

final class InMemorySkillPreferences: SkillPreferencesStoring {
    var favoriteSkillIDs: [String] = []
    var usageEvents: [UsageEvent] = []
    var templates: [PlatformTemplate] = PlatformTemplate.builtIns
    var roots: [SkillRoot] = []
    var defaultTemplateID: String = PlatformTemplate.codexLocalSkill.id
    var showSystemSkills: Bool = true
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
    @Published var selectedCategory: SkillCategory?
    @Published var selectedFilter: SkillLibraryFilter = .all
    @Published var sortMode: SkillSortMode = .relevance
    @Published var selectedSkillID: Skill.ID?
    @Published var lastCopiedText: String?
    @Published var toastMessage: String?
    @Published var codexSessions: [CodexSessionContext] = []
    @Published var selectedCodexSessionID: CodexSessionContext.ID?
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
        let startedAt = PerformanceDiagnostics.start()
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
        case .needsReview:
            candidates = candidates.filter(\.isNeedsReview)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let selectedCategory {
            candidates = candidates.filter { $0.category == selectedCategory }
        }

        let sortedCandidates = selectedFilter == .recommended
            ? rankRecommendationsFirst(candidates)
            : sort(candidates)
        let result = searchResults(in: sortedCandidates, query: query)
        PerformanceDiagnostics.finish(
            "visible_skills",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            details: "source=\(skills.count) filter=\(selectedFilter.rawValue) search=\(!query.isEmpty) category=\(selectedCategory?.rawValue ?? "all")",
            slowThresholdMS: 12
        )
        return result
    }

    var recommendationRankedSkills: [Skill] {
        let startedAt = PerformanceDiagnostics.start()
        let result = rankRecommendationsFirst(visibleSkillCandidates)
        PerformanceDiagnostics.finish(
            "recommendation_ranked_skills",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            slowThresholdMS: 12
        )
        return result
    }

    var selectedCodexSession: CodexSessionContext? {
        guard let selectedCodexSessionID else { return codexSessions.first }
        return codexSessions.first { $0.id == selectedCodexSessionID } ?? codexSessions.first
    }

    var recommendedSkills: [Skill] {
        skillRecommendations.map(\.skill)
    }

    var standaloneSkills: [Skill] {
        let startedAt = PerformanceDiagnostics.start()
        let result = sort(skills.filter { $0.sourceType != .plugin })
        PerformanceDiagnostics.finish(
            "standalone_skills",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            slowThresholdMS: 12
        )
        return result
    }

    var pluginSkills: [Skill] {
        let startedAt = PerformanceDiagnostics.start()
        let result = sort(skills.filter { $0.sourceType == .plugin })
        PerformanceDiagnostics.finish(
            "plugin_skills",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            slowThresholdMS: 12
        )
        return result
    }

    var pluginPackages: [PluginPackage] {
        let startedAt = PerformanceDiagnostics.start()
        let grouped = Dictionary(grouping: pluginSkills.compactMap { skill -> (PluginPackageIdentity, Skill)? in
            guard let identity = PluginPackageIdentity(skill: skill) else { return nil }
            return (identity, skill)
        }, by: { $0.0 })

        let result: [PluginPackage] = grouped.map { identity, entries in
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
        PerformanceDiagnostics.finish(
            "plugin_packages",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            details: "plugin_skills=\(grouped.values.reduce(0) { $0 + $1.count })",
            slowThresholdMS: 12
        )
        return result
    }

    func skills(forPluginID pluginID: PluginPackage.ID) -> [Skill] {
        guard let package = pluginPackages.first(where: { $0.id == pluginID }) else { return [] }
        let ids = Set(package.skillIDs)
        return sort(pluginSkills.filter { ids.contains($0.id) })
    }

    func duplicateSkills(for skill: Skill) -> [Skill] {
        let startedAt = PerformanceDiagnostics.start()
        let candidates = skills.filter { $0.sourceType != .plugin }
        let result = candidates
            .filter { candidate in
                candidate.name.caseInsensitiveCompare(skill.name) == .orderedSame && candidate.sourcePath != skill.sourcePath
            }
            .sorted { lhs, rhs in
                lhs.sourcePath.localizedCaseInsensitiveCompare(rhs.sourcePath) == .orderedAscending
            }
        PerformanceDiagnostics.finish(
            "duplicate_lookup",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.library,
            itemCount: result.count,
            details: "source=\(candidates.count)",
            slowThresholdMS: 8
        )
        return result
    }

    func refresh() throws {
        let startedAt = PerformanceDiagnostics.start()
        let enabledRoots = roots.filter(\.enabled).map { URL(fileURLWithPath: NSString(string: $0.path).expandingTildeInPath) }
        PerformanceDiagnostics.indexing.info("refresh_started roots=\(enabledRoots.count) existing_skills=\(self.skills.count)")
        skills = try indexer.index(rootURLs: enabledRoots)
        selectedSkillID = selectedSkillID ?? skills.first?.id
        skillRecommendations = []
        PerformanceDiagnostics.finish(
            "library_refresh",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.indexing,
            itemCount: skills.count,
            details: "roots=\(enabledRoots.count)",
            slowThresholdMS: 100
        )
    }

    func refreshRecommendations() {
        let startedAt = PerformanceDiagnostics.start()
        PerformanceDiagnostics.recommendations.info("recommendation_refresh_started skills=\(self.skills.count)")
        do {
            let sessions = try codexSessionReader.recentContexts()
            codexSessions = sessions
            if selectedCodexSessionID == nil || sessions.contains(where: { $0.id == selectedCodexSessionID }) == false {
                selectedCodexSessionID = sessions.first?.id
            }
            updateSkillRecommendations()
            recommendationError = nil
            PerformanceDiagnostics.finish(
                "recommendation_refresh",
                startedAt: startedAt,
                logger: PerformanceDiagnostics.recommendations,
                itemCount: skillRecommendations.count,
                details: "sessions=\(sessions.count)",
                slowThresholdMS: 50
            )
        } catch {
            codexSessions = []
            skillRecommendations = []
            recommendationError = error.localizedDescription
            PerformanceDiagnostics.recommendations.error("recommendation_refresh_failed duration_ms=\(PerformanceDiagnostics.milliseconds(since: startedAt), format: .fixed(precision: 2)) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    func recommendation(for skillID: Skill.ID) -> SkillRecommendation? {
        skillRecommendations.first { $0.skill.id == skillID }
    }

    func matchesSearchAndCategory(_ skill: Skill) -> Bool {
        if let selectedCategory, skill.category != selectedCategory {
            return false
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return true }
        return searchScore(for: skill, query: query) > 0
    }

    func searchResults(in skills: [Skill], query: String? = nil) -> [Skill] {
        let query = query ?? searchText
        let normalizedQuery = Self.normalizedSearchText(query)
        guard normalizedQuery.isEmpty == false else { return skills }

        let tieBreakOrder = Dictionary(uniqueKeysWithValues: skills.enumerated().map { ($0.element.id, $0.offset) })
        return skills
            .compactMap { skill -> (skill: Skill, score: Int)? in
                let score = searchScore(for: skill, query: normalizedQuery)
                return score > 0 ? (skill, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return (tieBreakOrder[lhs.skill.id] ?? Int.max) < (tieBreakOrder[rhs.skill.id] ?? Int.max)
            }
            .map(\.skill)
    }

    private func updateSkillRecommendations() {
        let startedAt = PerformanceDiagnostics.start()
        guard let selectedCodexSession else {
            skillRecommendations = []
            PerformanceDiagnostics.finish(
                "recommendation_match",
                startedAt: startedAt,
                logger: PerformanceDiagnostics.recommendations,
                itemCount: 0,
                details: "no_session",
                slowThresholdMS: 20
            )
            return
        }

        var candidates = skills.filter { $0.sourceType != .plugin }
        if showSystemSkills == false {
            candidates = candidates.filter { $0.sourceType != .system }
        }

        skillRecommendations = recommender.recommendations(for: selectedCodexSession, skills: candidates)
        PerformanceDiagnostics.finish(
            "recommendation_match",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.recommendations,
            itemCount: skillRecommendations.count,
            details: "candidates=\(candidates.count)",
            slowThresholdMS: 20
        )
    }

    private func searchScore(for skill: Skill, query: String) -> Int {
        let normalizedQuery = Self.normalizedSearchText(query)
        let queryTokens = Self.searchTokens(normalizedQuery)
        guard queryTokens.isEmpty == false else { return 0 }

        let name = Self.normalizedSearchText(skill.name)
        let nameTokens = Self.searchTokens(name)
        let tags = skill.tags.map { Self.normalizedSearchText($0) }
        let description = Self.normalizedSearchText(skill.description)
        let path = Self.normalizedSearchText(skill.sourcePath)
        let classifierTerms = SkillClassifier.searchTerms(for: skill).map { Self.normalizedSearchText($0) }

        func tokenScore(_ token: String) -> Int {
            if nameTokens.contains(token) { return 1_000 }
            if nameTokens.contains(where: { $0.hasPrefix(token) }) { return 850 }
            if name.contains(token) { return 700 }
            if tags.contains(token) { return 650 }
            if tags.contains(where: { $0.hasPrefix(token) }) { return 500 }
            if tags.contains(where: { $0.contains(token) }) { return 350 }
            if description.contains(token) { return 150 }
            if path.contains(token) { return 75 }
            if classifierTerms.contains(where: { $0.contains(token) }) { return 20 }
            return 0
        }

        let tokenScores = queryTokens.map(tokenScore)
        guard tokenScores.allSatisfy({ $0 > 0 }) else { return 0 }

        let phraseBonus: Int
        if name == normalizedQuery {
            phraseBonus = 5_000
        } else if name.hasPrefix(normalizedQuery) {
            phraseBonus = 4_000
        } else if name.contains(normalizedQuery) {
            phraseBonus = 3_000
        } else if tags.contains(normalizedQuery) {
            phraseBonus = 2_000
        } else if tags.contains(where: { $0.hasPrefix(normalizedQuery) }) {
            phraseBonus = 1_500
        } else {
            phraseBonus = 0
        }

        return phraseBonus + tokenScores.reduce(0, +)
    }

    private static func normalizedSearchText(_ value: String) -> String {
        String(value.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ")
            .map(String.init)
            .joined(separator: " ")
    }

    private static func searchTokens(_ value: String) -> [String] {
        normalizedSearchText(value).split(separator: " ").map(String.init)
    }

    private var visibleSkillCandidates: [Skill] {
        var candidates = skills.filter { $0.sourceType != .plugin }

        if showSystemSkills == false {
            candidates = candidates.filter { $0.sourceType != .system }
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
