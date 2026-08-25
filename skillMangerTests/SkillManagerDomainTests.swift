//
//  SkillManagerDomainTests.swift
//  skillMangerTests
//
//  Created by Codex on 2026/7/14.
//

import Foundation
import SQLite3
import Testing
@testable import skillManger

struct SkillManagerDomainTests {
    @Test func codexAndClaudeTemplatesRenderSkillReferences() throws {
        let skill = Skill.fixture(
            name: "local-dependency-manager",
            description: "Use Ming's local zsh toolchain.",
            sourceType: .local,
            sourcePath: "/Users/ming/.codex/skills/local-dependency-manager/SKILL.md"
        )

        let codex = try CopyTemplateEngine.render(
            template: .codexInstructionBlock,
            skill: skill,
            useCase: "调用/安装/运行 shell 工具"
        )
        let claude = try CopyTemplateEngine.render(template: .claudeInstruction, skill: skill)
        let cursor = try CopyTemplateEngine.render(template: .cursorInstruction, skill: skill)

        #expect(codex == "在需要处理「调用/安装/运行 shell 工具」时，配合 skill：[$skill_name]($skill_path)"
            .replacingOccurrences(of: "$skill_name", with: skill.name)
            .replacingOccurrences(of: "$skill_path", with: skill.referencePath))
        #expect(claude.contains("Use the \"local-dependency-manager\" skill for this task."))
        #expect(claude.contains("Skill path: /Users/ming/.codex/skills/local-dependency-manager/SKILL.md"))
        #expect(cursor.contains("Use this skill context while working in the codebase:"))
    }

    @Test func skillIndexerReadsFrontMatterAndFallbackDescriptions() throws {
        let root = try TemporarySkillRoot()
        try root.writeSkill(
            folder: "local-dependency-manager",
            contents: """
            ---
            name: local-dependency-manager
            description: Prefer local zsh dependencies for shell work.
            ---

            # Local Dependency Manager
            Body text.
            """
        )
        try root.writeSkill(
            folder: "plain-skill",
            contents: """
            # Plain Skill

            Use when a skill file has no front matter but still has a meaningful paragraph.
            """
        )

        let skills = try SkillIndexer().index(rootURLs: [root.url])

        #expect(skills.count == 2)
        #expect(skills.first { $0.name == "local-dependency-manager" }?.description == "Prefer local zsh dependencies for shell work.")
        #expect(skills.first { $0.name == "plain-skill" }?.description == "Use when a skill file has no front matter but still has a meaningful paragraph.")
        #expect(skills.first { $0.name == "local-dependency-manager" }?.healthStatus == .healthy)
        #expect(skills.first { $0.name == "plain-skill" }?.healthStatus == .missingMetadata)
    }

    @Test func skillIndexerMarksDuplicateNamesForReview() throws {
        let root = try TemporarySkillRoot()
        try root.writeSkill(folder: "one", contents: "---\nname: duplicate\ndescription: First.\n---\n")
        try root.writeSkill(folder: "two", contents: "---\nname: duplicate\ndescription: Second.\n---\n")

        let skills = try SkillIndexer().index(rootURLs: [root.url])

        #expect(skills.count == 2)
        #expect(skills.allSatisfy { $0.healthStatus == .duplicateName })
    }

    @Test func skillIndexerDeduplicatesNestedRootsAndScansHiddenPluginAgentSkills() throws {
        let pluginRoot = try TemporarySkillRoot()
        try pluginRoot.writeSkill(
            folder: "openai-plugins-local/.agents/skills/plugin-creator",
            contents: "---\nname: plugin-creator\ndescription: Create Codex plugins.\n---\n"
        )

        let skills = try SkillIndexer().index(rootURLs: [pluginRoot.url, pluginRoot.url.appendingPathComponent("openai-plugins-local")])

        #expect(skills.map(\.sourcePath).count == Set(skills.map(\.sourcePath)).count)
        #expect(skills.count == 1)
        #expect(skills.first?.name == "plugin-creator")
    }

    @Test func storeFiltersFavoritesRecentsAndSearchResults() throws {
        let preferences = InMemorySkillPreferences()
        let store = SkillLibraryStore(
            preferences: preferences,
            indexer: SkillIndexer(),
            initialSkills: [
                .fixture(name: "swiftui-ui-patterns", description: "Build SwiftUI UI.", sourceType: .plugin),
                .fixture(name: "local-dependency-manager", description: "Use local shell tools.", sourceType: .local),
                .fixture(name: "systematic-debugging", description: "Debug failures methodically.", sourceType: .plugin)
            ]
        )

        store.toggleFavorite(skillID: "swiftui-ui-patterns")
        try store.recordCopy(skillID: "local-dependency-manager", templateID: PlatformTemplate.codexInstructionBlock.id)
        store.searchText = "shell"

        #expect(store.visibleSkills.map(\.name) == ["local-dependency-manager"])

        store.searchText = ""
        store.selectedFilter = .favorites
        #expect(store.visibleSkills.map(\.name) == ["swiftui-ui-patterns"])

        store.selectedFilter = .recent
        #expect(store.visibleSkills.map(\.name) == ["local-dependency-manager"])

        store.selectedFilter = .all
        store.showPluginSkills = false
        #expect(store.visibleSkills.map(\.name) == ["local-dependency-manager"])

        #expect(preferences.favoriteSkillIDs == ["swiftui-ui-patterns"])
        #expect(preferences.usageEvents.count == 1)
    }

    @Test func storeRecommendedFilterSearchesAllSkillsWithRecommendationsFirst() throws {
        let recommended = Skill.fixture(name: "window-management", description: "Position macOS panels.", sourceType: .plugin)
        let localMatch = Skill.fixture(name: "local-dependency-manager", description: "Use local shell tools.", sourceType: .local)
        let pluginMatch = Skill.fixture(name: "shell-debugger", description: "Debug shell failures.", sourceType: .plugin)
        let store = SkillLibraryStore(
            preferences: InMemorySkillPreferences(),
            initialSkills: [localMatch, pluginMatch, recommended]
        )

        store.skillRecommendations = [
            SkillRecommendation(skill: recommended, score: 18, matchedTerms: ["window"])
        ]
        store.selectedFilter = .recommended

        #expect(store.visibleSkills.map(\.name) == ["window-management", "local-dependency-manager", "shell-debugger"])

        store.searchText = "shell"

        #expect(store.visibleSkills.map(\.name) == ["local-dependency-manager", "shell-debugger"])
    }

    @Test func storeReportsDuplicateSkillsForDetailResolution() throws {
        let store = SkillLibraryStore(
            preferences: InMemorySkillPreferences(),
            initialSkills: [
                .fixture(name: "appkit-interop", description: "Bridge SwiftUI and AppKit.", sourceType: .plugin, sourcePath: "/Users/ming/.codex/plugins/cache/openai-curated/build-macos-apps/appkit-interop/SKILL.md"),
                .fixture(name: "appkit-interop", description: "Bridge SwiftUI and AppKit narrowly.", sourceType: .plugin, sourcePath: "/Users/ming/.codex/plugins/cache/openai-api-curated/build-macos-apps/appkit-interop/SKILL.md"),
                .fixture(name: "swiftui-patterns", description: "Build SwiftUI views.", sourceType: .plugin)
            ]
        )

        let selected = try #require(store.skills.first { $0.name == "appkit-interop" })
        let duplicates = store.duplicateSkills(for: selected)

        #expect(duplicates.map(\.sourcePath) == ["/Users/ming/.codex/plugins/cache/openai-api-curated/build-macos-apps/appkit-interop/SKILL.md"])
    }

    @Test func storeSeparatesStandaloneSkillsPluginsAndPluginSkills() throws {
        let store = SkillLibraryStore(
            preferences: InMemorySkillPreferences(),
            initialSkills: [
                .fixture(name: "local-dependency-manager", description: "Use local tools.", sourceType: .local, sourcePath: "/Users/ming/.codex/skills/local-dependency-manager/SKILL.md"),
                .fixture(name: "appkit-interop", description: "Bridge SwiftUI and AppKit.", sourceType: .plugin, sourcePath: "/Users/ming/.codex/plugins/cache/openai-curated/build-macos-apps/11c74d6b/skills/appkit-interop/SKILL.md"),
                .fixture(name: "swiftui-patterns", description: "Build SwiftUI views.", sourceType: .plugin, sourcePath: "/Users/ming/.codex/plugins/cache/openai-curated/build-macos-apps/11c74d6b/skills/swiftui-patterns/SKILL.md"),
                .fixture(name: "audit", description: "Audit product flows.", sourceType: .plugin, sourcePath: "/Users/ming/.codex/plugins/cache/role-specific-plugins/product-design/0.1.50/skills/audit/SKILL.md")
            ]
        )

        #expect(store.standaloneSkills.map(\.name) == ["local-dependency-manager"])
        #expect(store.pluginSkills.map(\.name) == ["appkit-interop", "audit", "swiftui-patterns"])
        #expect(store.pluginPackages.map(\.id) == ["build-macos-apps@openai-curated", "product-design@role-specific-plugins"])
        #expect(store.pluginPackages.first { $0.id == "build-macos-apps@openai-curated" }?.skillCount == 2)
        #expect(store.skills(forPluginID: "build-macos-apps@openai-curated").map(\.name) == ["appkit-interop", "swiftui-patterns"])
    }

    @Test func storePersistsRootsAndEditableTemplates() throws {
        let preferences = InMemorySkillPreferences()
        let customRoot = SkillRoot(
            path: "/Users/ming/.codex/skills",
            enabled: true,
            sourceType: .local,
            lastIndexedAt: nil,
            lastError: nil
        )
        let store = SkillLibraryStore(preferences: preferences, roots: [customRoot])

        store.roots[0].enabled = false
        store.updateTemplate(
            id: PlatformTemplate.plainText.id,
            platformName: "Plain Text Edited",
            body: "Skill $skill_name lives at $skill_path"
        )
        store.addCustomTemplate(named: "Raycast", basedOn: .plainText)

        #expect(preferences.roots == [SkillRoot(path: "/Users/ming/.codex/skills", enabled: false, sourceType: .local, lastIndexedAt: nil, lastError: nil)])
        #expect(preferences.templates.first { $0.id == PlatformTemplate.plainText.id }?.platformName == "Plain Text Edited")
        #expect(preferences.templates.first { $0.id == PlatformTemplate.plainText.id }?.body == "Skill $skill_name lives at $skill_path")
        #expect(preferences.templates.contains { $0.platformName == "Raycast" && $0.isBuiltIn == false })
    }

    @Test func storeUsesEnabledPluginsFromCodexConfigForDefaultRoots() throws {
        let codexHome = try TemporarySkillRoot()
        let enabledRoot = codexHome.url.appendingPathComponent(".codex/plugins/cache/openai-curated/build-macos-apps/11c74d6b/skills/appkit-interop", isDirectory: true)
        let disabledRoot = codexHome.url.appendingPathComponent(".codex/plugins/cache/openai-curated/build-web-apps/11c74d6b/skills/frontend", isDirectory: true)
        try FileManager.default.createDirectory(at: enabledRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: disabledRoot, withIntermediateDirectories: true)
        try "---\nname: appkit-interop\ndescription: Bridge AppKit.\n---\n".write(to: enabledRoot.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "---\nname: frontend\ndescription: Build frontend apps.\n---\n".write(to: disabledRoot.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        let configURL = try codexHome.writeCodexConfig("""
        [marketplaces.openai-curated]
        source_type = "local"
        source = "\(codexHome.url.path)/.codex/plugins/openai-curated"

        [plugins."build-macos-apps@openai-curated"]
        enabled = true

        [plugins."build-web-apps@openai-curated"]
        enabled = false
        """)

        let roots = SkillLibraryStore.defaultRoots(homeDirectory: codexHome.url.path, codexConfigURL: configURL)
        let rootPaths = roots.map(\.path)

        #expect(rootPaths.contains("\(codexHome.url.path)/.codex/plugins/cache/openai-curated/build-macos-apps/11c74d6b"))
        #expect(rootPaths.contains("\(codexHome.url.path)/.codex/plugins/cache/openai-curated/build-web-apps/11c74d6b") == false)
        #expect(rootPaths.contains("\(codexHome.url.path)/.codex/plugins") == false)
    }

    @Test func storeMigratesBroadPluginRootsToEnabledPluginRoots() throws {
        let codexHome = try TemporarySkillRoot()
        let enabledRoot = codexHome.url.appendingPathComponent(".codex/plugins/cache/openai-plugins-local/canva/1.0.2/skills/canva-translate-design", isDirectory: true)
        try FileManager.default.createDirectory(at: enabledRoot, withIntermediateDirectories: true)
        try "---\nname: canva-translate-design\ndescription: Translate Canva designs.\n---\n".write(to: enabledRoot.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        let configURL = try codexHome.writeCodexConfig("""
        [marketplaces.openai-plugins-local]
        source_type = "local"
        source = "\(codexHome.url.path)/.codex/plugins/openai-plugins-local"

        [plugins."canva@openai-plugins-local"]
        enabled = true
        """)

        let preferences = InMemorySkillPreferences()
        preferences.roots = [
            SkillRoot(path: "\(codexHome.url.path)/.codex/skills", enabled: true, sourceType: .local, lastIndexedAt: nil, lastError: nil),
            SkillRoot(path: "\(codexHome.url.path)/.codex/plugins", enabled: true, sourceType: .plugin, lastIndexedAt: nil, lastError: nil)
        ]

        let store = SkillLibraryStore(preferences: preferences, codexConfigURL: configURL, homeDirectory: codexHome.url.path)
        let rootPaths = store.roots.map(\.path)

        #expect(rootPaths.contains("\(codexHome.url.path)/.codex/plugins/cache/openai-plugins-local/canva/1.0.2"))
        #expect(rootPaths.contains("\(codexHome.url.path)/.codex/plugins") == false)
        #expect(rootPaths.contains("\(codexHome.url.path)/.codex/plugins/cache") == false)
    }

    @Test func recommenderMatchesCodexSessionContextToSkills() throws {
        let context = CodexSessionContext(
            id: "thread-1",
            title: "修复 macOS 刘海窗口 hover 收起和 SwiftUI 布局",
            preview: "窗口展开不居中，需要调整 NSPanel frame 和 SwiftUI view layout",
            cwd: "/Users/ming/myProductWorkspace/ios/skillManger",
            updatedAt: Date(timeIntervalSince1970: 1_784_000_000),
            recentUserMessages: ["参考 boring.notch 的 window management 实现"]
        )
        let skills: [Skill] = [
            .fixture(name: "window-management", description: "Customize macOS SwiftUI windows and panel placement.", sourceType: .plugin),
            .fixture(name: "lark-doc", description: "Read and edit Feishu docs.", sourceType: .local),
            .fixture(name: "stripe-best-practices", description: "Guide Stripe integration decisions.", sourceType: .plugin)
        ]

        let recommendations = SkillRecommender().recommendations(for: context, skills: skills)

        #expect(recommendations.first?.skill.name == "window-management")
        #expect(recommendations.first?.matchedTerms.contains("window") == true)
    }

    @Test func codexSessionReaderLoadsLatestSessionIndexEntries() throws {
        let codexHome = try TemporarySkillRoot()
        let codexDirectory = codexHome.url.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try """
        {"id":"older","thread_name":"旧会话","updated_at":"2026-08-23T01:00:00.000000Z"}
        {"id":"active","thread_name":"macOS skill 推荐","updated_at":"2026-08-24T01:00:00.000000Z"}
        {"id":"active","thread_name":"macOS skill 推荐更新","updated_at":"2026-08-24T02:00:00.000000Z"}
        """.write(to: codexDirectory.appendingPathComponent("session_index.jsonl"), atomically: true, encoding: .utf8)

        let contexts = try CodexSessionContextReader(codexHomeURL: codexDirectory).recentContexts(limit: 2)

        #expect(contexts.map(\.id) == ["active", "older"])
        #expect(contexts.first?.title == "macOS skill 推荐更新")
    }

    @Test func codexSessionDisplayTitleUsesProjectPrefix() throws {
        let context = CodexSessionContext(
            id: "thread-1",
            title: "后端",
            preview: "后端",
            cwd: "/Users/ming/xcmgWorkSpace/国内mes/code/new/mom-backend",
            updatedAt: Date(timeIntervalSince1970: 1_784_000_000),
            recentUserMessages: []
        )

        #expect(context.projectName == "mom-backend")
        #expect(context.displayTitle == "mom-backend / 后端")
    }

    @Test func codexSessionReaderLoadsWorkingDirectoryFromCommandHistory() throws {
        let codexHome = try TemporarySkillRoot()
        let codexDirectory = codexHome.url.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try """
        {"id":"thread-1","thread_name":"后端","updated_at":"2026-08-24T02:00:00.000000Z"}
        """.write(to: codexDirectory.appendingPathComponent("session_index.jsonl"), atomically: true, encoding: .utf8)

        let databaseURL = codexDirectory.appendingPathComponent("thread_history_1.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "SkillManagerTests", code: 1)
        }
        defer { sqlite3_close(database) }

        try executeSQL("""
        CREATE TABLE thread_items (
            thread_id TEXT NOT NULL,
            turn_id TEXT NOT NULL,
            item_id TEXT NOT NULL,
            rollout_ordinal INTEGER NOT NULL,
            created_at_ms INTEGER NOT NULL,
            item_json TEXT NOT NULL,
            item_type TEXT NOT NULL DEFAULT '',
            updated_at_ordinal INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (thread_id, turn_id, item_id)
        );
        """, database: database)
        try executeSQL("""
        INSERT INTO thread_items (thread_id, turn_id, item_id, rollout_ordinal, created_at_ms, item_json, item_type)
        VALUES ('thread-1', 'turn-1', 'cmd-1', 1, 1000, '{"type":"commandExecution","cwd":"/Users/ming/work/mom-backend"}', 'commandExecution');
        """, database: database)

        let contexts = try CodexSessionContextReader(codexHomeURL: codexDirectory).recentContexts(limit: 1)

        #expect(contexts.first?.cwd == "/Users/ming/work/mom-backend")
        #expect(contexts.first?.displayTitle == "mom-backend / 后端")
    }
}

private extension Skill {
    static func fixture(
        name: String,
        description: String,
        sourceType: SkillSourceType,
        sourcePath: String? = nil
    ) -> Skill {
        Skill(
            id: name,
            name: name,
            description: description,
            sourceType: sourceType,
            sourcePath: sourcePath ?? "/tmp/\(name)/SKILL.md",
            pluginURI: sourceType == .plugin ? "plugin://example/\(name)" : nil,
            rootPath: "/tmp",
            tags: [sourceType.rawValue],
            lastModifiedAt: Date(timeIntervalSince1970: 1_784_000_000),
            lastIndexedAt: Date(timeIntervalSince1970: 1_784_021_600),
            healthStatus: .healthy,
            excerpt: description
        )
    }
}

private final class TemporarySkillRoot {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillManagerTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func writeSkill(folder: String, contents: String) throws {
        let skillDirectory = url.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: skillDirectory, withIntermediateDirectories: true)
        try contents.write(to: skillDirectory.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    func writeCodexConfig(_ contents: String) throws -> URL {
        let configDirectory = url.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let configURL = configDirectory.appendingPathComponent("config.toml")
        try contents.write(to: configURL, atomically: true, encoding: .utf8)
        return configURL
    }
}

private func executeSQL(_ sql: String, database: OpaquePointer) throws {
    var errorMessage: UnsafeMutablePointer<CChar>?
    defer { sqlite3_free(errorMessage) }

    guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
        let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
        throw NSError(domain: "SkillManagerTests", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
