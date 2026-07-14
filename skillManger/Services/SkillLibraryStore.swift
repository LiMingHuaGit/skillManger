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

    init(
        preferences: SkillPreferencesStoring = UserDefaultsSkillPreferences(),
        indexer: SkillIndexer = SkillIndexer(),
        initialSkills: [Skill] = [],
        roots: [SkillRoot]? = nil
    ) {
        self.preferences = preferences
        self.indexer = indexer
        self.skills = initialSkills
        self.roots = roots ?? (preferences.roots.isEmpty ? Self.defaultRoots() : preferences.roots)
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
        }
    }

    var showPluginSkills: Bool {
        get { preferences.showPluginSkills }
        set {
            objectWillChange.send()
            preferences.showPluginSkills = newValue
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
        var candidates = skills

        if showSystemSkills == false {
            candidates = candidates.filter { $0.sourceType != .system }
        }

        if showPluginSkills == false {
            candidates = candidates.filter { $0.sourceType != .plugin }
        }

        switch selectedFilter {
        case .all:
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

        return sort(candidates)
    }

    func refresh() throws {
        let enabledRoots = roots.filter(\.enabled).map { URL(fileURLWithPath: NSString(string: $0.path).expandingTildeInPath) }
        skills = try indexer.index(rootURLs: enabledRoots)
        selectedSkillID = selectedSkillID ?? skills.first?.id
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

    static func defaultRoots(homeDirectory: String = NSHomeDirectory()) -> [SkillRoot] {
        [
            SkillRoot(path: "\(homeDirectory)/.codex/skills", enabled: true, sourceType: .local, lastIndexedAt: nil, lastError: nil),
            SkillRoot(path: "\(homeDirectory)/.codex/skills/.system", enabled: true, sourceType: .system, lastIndexedAt: nil, lastError: nil),
            SkillRoot(path: "\(homeDirectory)/.codex/plugins/cache", enabled: true, sourceType: .plugin, lastIndexedAt: nil, lastError: nil)
        ]
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
