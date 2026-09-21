//
//  CopyTemplateEngine.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation

enum CopyTemplateError: Error, Equatable {
    case missingUseCase
}

struct CopyTemplateEngine {
    static func render(template: PlatformTemplate, skill: Skill, useCase: String? = nil) throws -> String {
        if template.body.contains("$use_case"), useCase?.isEmpty != false {
            throw CopyTemplateError.missingUseCase
        }

        let pluginID = skill.pluginURI?
            .replacingOccurrences(of: "plugin://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? skill.name

        return template.body
            .replacingOccurrences(of: "$skill_name", with: skill.name)
            .replacingOccurrences(of: "$skill_path", with: skill.referencePath)
            .replacingOccurrences(of: "$plugin_name", with: skill.name)
            .replacingOccurrences(of: "$plugin_id", with: pluginID)
            .replacingOccurrences(of: "$description", with: skill.description)
            .replacingOccurrences(of: "$use_case", with: useCase ?? skill.description)
    }
}
