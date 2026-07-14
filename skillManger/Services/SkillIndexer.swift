//
//  SkillIndexer.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation

struct SkillIndexer {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func index(rootURLs: [URL]) throws -> [Skill] {
        let indexedAt = Date()
        var skills: [Skill] = []

        for rootURL in rootURLs where fileManager.fileExists(atPath: rootURL.path) {
            for skillFile in skillFiles(in: rootURL) {
                let skill = parseSkill(fileURL: skillFile, rootURL: rootURL, indexedAt: indexedAt)
                skills.append(skill)
            }
        }

        let duplicateNames = Dictionary(grouping: skills, by: { $0.name.lowercased() })
            .filter { $0.value.count > 1 }
            .map(\.key)

        guard duplicateNames.isEmpty == false else { return skills.sortedForLibrary() }

        return skills.map { skill in
            guard duplicateNames.contains(skill.name.lowercased()) else { return skill }
            var duplicate = skill
            duplicate.healthStatus = .duplicateName
            return duplicate
        }
        .sortedForLibrary()
    }

    private func skillFiles(in rootURL: URL) -> [URL] {
        var files: [URL] = []

        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("SKILL.md").path) {
            files.append(rootURL.appendingPathComponent("SKILL.md"))
        }

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return files
        }

        for case let url as URL in enumerator where url.lastPathComponent == "SKILL.md" {
            if files.contains(url) == false {
                files.append(url)
            }
        }

        return files
    }

    private func parseSkill(fileURL: URL, rootURL: URL, indexedAt: Date) -> Skill {
        let contents: String
        do {
            contents = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return fallbackSkill(fileURL: fileURL, rootURL: rootURL, indexedAt: indexedAt, health: .unreadable)
        }

        let frontMatter = parseFrontMatter(from: contents)
        let inferredName = fileURL.deletingLastPathComponent().lastPathComponent
        let name = frontMatter["name"]?.nilIfBlank ?? inferredName
        let description = frontMatter["description"]?.nilIfBlank ?? firstMeaningfulParagraph(in: contents) ?? String(localized: "No description provided.")
        let health: SkillHealthStatus = frontMatter["name"] == nil || frontMatter["description"] == nil ? .missingMetadata : .healthy
        let modifiedAt = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? indexedAt

        return Skill(
            id: fileURL.path,
            name: name,
            description: description,
            sourceType: sourceType(for: rootURL, fileURL: fileURL),
            sourcePath: fileURL.path,
            pluginURI: pluginURI(for: fileURL),
            rootPath: rootURL.path,
            tags: tags(for: name, description: description, rootURL: rootURL),
            lastModifiedAt: modifiedAt,
            lastIndexedAt: indexedAt,
            healthStatus: health,
            excerpt: excerpt(from: contents)
        )
    }

    private func fallbackSkill(fileURL: URL, rootURL: URL, indexedAt: Date, health: SkillHealthStatus) -> Skill {
        let name = fileURL.deletingLastPathComponent().lastPathComponent
        return Skill(
            id: fileURL.path,
            name: name,
            description: String(localized: "No description available."),
            sourceType: sourceType(for: rootURL, fileURL: fileURL),
            sourcePath: fileURL.path,
            pluginURI: pluginURI(for: fileURL),
            rootPath: rootURL.path,
            tags: [sourceType(for: rootURL, fileURL: fileURL).rawValue],
            lastModifiedAt: indexedAt,
            lastIndexedAt: indexedAt,
            healthStatus: health,
            excerpt: ""
        )
    }

    private func parseFrontMatter(from contents: String) -> [String: String] {
        let lines = contents.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return [:] }

        var values: [String: String] = [:]
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" { break }
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = trimmed[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        return values
    }

    private func firstMeaningfulParagraph(in contents: String) -> String? {
        let withoutFrontMatter = removeFrontMatter(from: contents)
        return withoutFrontMatter
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                line.isEmpty == false && line.hasPrefix("#") == false && line.hasPrefix("---") == false
            }
    }

    private func excerpt(from contents: String) -> String {
        removeFrontMatter(from: contents)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .prefix(6)
            .joined(separator: "\n")
    }

    private func removeFrontMatter(from contents: String) -> String {
        let lines = contents.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return contents }

        var foundClosingFence = false
        let remainder = lines.dropFirst().drop { line in
            if foundClosingFence { return false }
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                foundClosingFence = true
            }
            return true
        }
        return remainder.joined(separator: "\n")
    }

    private func sourceType(for rootURL: URL, fileURL: URL) -> SkillSourceType {
        let path = fileURL.path.lowercased()
        if path.contains("/plugins/cache/") { return .plugin }
        if path.contains("/.system/") { return .system }
        if rootURL.path.contains(".codex/skills") { return .local }
        return .project
    }

    private func pluginURI(for fileURL: URL) -> String? {
        let path = fileURL.path
        guard path.contains("/plugins/cache/") else { return nil }
        let components = fileURL.pathComponents
        guard let cacheIndex = components.firstIndex(of: "cache"), components.indices.contains(cacheIndex + 1) else { return nil }
        return "plugin://\(components[cacheIndex + 1])"
    }

    private func tags(for name: String, description skillDescription: String, rootURL: URL) -> [String] {
        var tags = Set<String>()
        tags.insert(sourceType(for: rootURL, fileURL: rootURL).rawValue)
        let searchableText = "\(name) \(skillDescription)".lowercased()
        for tokenSlice in searchableText.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let token = String(tokenSlice)
            if ["swiftui", "ios", "debug", "design", "frontend", "local", "dependency", "testing"].contains(token) {
                tags.insert(token)
            }
        }
        return Array(tags).sorted()
    }
}

private extension Array where Element == Skill {
    func sortedForLibrary() -> [Skill] {
        sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
