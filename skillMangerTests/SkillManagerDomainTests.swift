//
//  SkillManagerDomainTests.swift
//  skillMangerTests
//
//  Created by Codex on 2026/7/14.
//

import Foundation
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
}
