//
//  CodexSessionModels.swift
//  skillManger
//
//  Created by Codex on 2026/8/24.
//

import Foundation

struct CodexSessionContext: Identifiable, Hashable {
    var id: String
    var title: String
    var preview: String
    var cwd: String
    var updatedAt: Date
    var recentUserMessages: [String]

    var displayTitle: String {
        let sessionTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "Untitled Codex chat"
        guard let projectName else { return sessionTitle }
        return "\(projectName) / \(sessionTitle)"
    }

    var projectName: String? {
        let trimmedCWD = cwd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCWD.isEmpty == false else { return nil }
        return URL(fileURLWithPath: trimmedCWD).lastPathComponent.nilIfBlank
    }

    var contextText: String {
        ([title, preview, cwd] + recentUserMessages)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }
}

struct SkillRecommendation: Identifiable, Hashable {
    var id: Skill.ID { skill.id }
    var skill: Skill
    var score: Double
    var matchedTerms: [String]

    var reason: String {
        guard matchedTerms.isEmpty == false else { return "" }
        return matchedTerms.prefix(4).joined(separator: ", ")
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
