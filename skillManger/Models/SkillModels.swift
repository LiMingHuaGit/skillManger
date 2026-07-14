//
//  SkillModels.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation

enum SkillSourceType: String, CaseIterable, Codable, Hashable, Identifiable {
    case local
    case system
    case plugin
    case project

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .local: "Local"
        case .system: "System"
        case .plugin: "Plugin"
        case .project: "Project"
        }
    }

    var label: String {
        String(localized: String.LocalizationValue(localizationKey))
    }
}

enum SkillHealthStatus: String, CaseIterable, Codable, Hashable, Identifiable {
    case healthy
    case missingMetadata
    case missingFile
    case duplicateName
    case unreadable

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .healthy: "Healthy"
        case .missingMetadata: "Missing metadata"
        case .missingFile: "Missing file"
        case .duplicateName: "Duplicate name"
        case .unreadable: "Unreadable"
        }
    }

    var label: String {
        String(localized: String.LocalizationValue(localizationKey))
    }

    var needsReview: Bool { self != .healthy }
}

struct Skill: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var description: String
    var sourceType: SkillSourceType
    var sourcePath: String
    var pluginURI: String?
    var rootPath: String
    var tags: [String]
    var lastModifiedAt: Date
    var lastIndexedAt: Date
    var healthStatus: SkillHealthStatus
    var excerpt: String

    var referencePath: String {
        pluginURI ?? sourcePath
    }

    var isNeedsReview: Bool {
        healthStatus.needsReview
    }
}

enum SkillLibraryFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recent
    case local
    case plugin
    case needsReview

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .all: "All"
        case .favorites: "Favorites"
        case .recent: "Recent"
        case .local: "Local"
        case .plugin: "Plugin"
        case .needsReview: "Needs Review"
        }
    }

    var label: String {
        String(localized: String.LocalizationValue(localizationKey))
    }
}

enum SkillSortMode: String, CaseIterable, Identifiable {
    case relevance
    case recentlyUsed
    case recentlyModified
    case name

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .relevance: "Relevance"
        case .recentlyUsed: "Recently used"
        case .recentlyModified: "Recently modified"
        case .name: "Name"
        }
    }

    var label: String {
        String(localized: String.LocalizationValue(localizationKey))
    }
}

struct SkillRoot: Identifiable, Codable, Hashable {
    var id: String { path }
    var path: String
    var enabled: Bool
    var sourceType: SkillSourceType
    var lastIndexedAt: Date?
    var lastError: String?
}

struct UsageEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var skillID: String
    var platformTemplateID: String
    var copiedAt: Date
    var copyType: String
}

struct PlatformTemplate: Identifiable, Codable, Hashable {
    var id: String
    var platformName: String
    var templateType: String
    var body: String
    var isBuiltIn: Bool
    var isDefault: Bool

    static let codexLocalSkill = PlatformTemplate(
        id: "codex.localSkill",
        platformName: "Codex",
        templateType: "mention",
        body: "[$skill_name]($skill_path)",
        isBuiltIn: true,
        isDefault: true
    )

    static let codexPluginSkill = PlatformTemplate(
        id: "codex.pluginSkill",
        platformName: "Codex",
        templateType: "mention",
        body: "[@$plugin_name](plugin://$plugin_id)",
        isBuiltIn: true,
        isDefault: false
    )

    static let codexInstructionBlock = PlatformTemplate(
        id: "codex.instructionBlock",
        platformName: "Codex",
        templateType: "prompt",
        body: "在需要处理「$use_case」时，配合 skill：[$skill_name]($skill_path)",
        isBuiltIn: true,
        isDefault: false
    )

    static let claudeInstruction = PlatformTemplate(
        id: "claude.instruction",
        platformName: "Claude",
        templateType: "prompt",
        body: "Use the \"$skill_name\" skill for this task.\nSkill path: $skill_path\nWhen to use it: $description",
        isBuiltIn: true,
        isDefault: false
    )

    static let chatGPTInstruction = PlatformTemplate(
        id: "chatgpt.instruction",
        platformName: "ChatGPT",
        templateType: "prompt",
        body: "Please use the following skill guidance for this task:\nSkill: $skill_name\nWhen to use it: $description\nSource: $skill_path",
        isBuiltIn: true,
        isDefault: false
    )

    static let cursorInstruction = PlatformTemplate(
        id: "cursor.instruction",
        platformName: "Cursor",
        templateType: "prompt",
        body: "Use this skill context while working in the codebase:\n$skill_name - $description\nSource: $skill_path",
        isBuiltIn: true,
        isDefault: false
    )

    static let genericMarkdown = PlatformTemplate(
        id: "generic.markdown",
        platformName: "Generic Markdown",
        templateType: "prompt",
        body: "**Skill:** [$skill_name]($skill_path)\n**Use when:** $description",
        isBuiltIn: true,
        isDefault: false
    )

    static let plainText = PlatformTemplate(
        id: "plain.text",
        platformName: "Plain Text",
        templateType: "prompt",
        body: "Skill: $skill_name\nPath: $skill_path\nUse when: $description",
        isBuiltIn: true,
        isDefault: false
    )

    static let builtIns: [PlatformTemplate] = [
        .codexLocalSkill,
        .codexPluginSkill,
        .codexInstructionBlock,
        .claudeInstruction,
        .chatGPTInstruction,
        .cursorInstruction,
        .genericMarkdown,
        .plainText
    ]
}
