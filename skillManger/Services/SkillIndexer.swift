//
//  SkillIndexer.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation
import OSLog

struct SkillIndexer {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func index(rootURLs: [URL]) throws -> [Skill] {
        let startedAt = PerformanceDiagnostics.start()
        let indexedAt = Date()
        var skills: [Skill] = []
        var indexedPaths = Set<String>()

        for rootURL in rootURLs where fileManager.fileExists(atPath: rootURL.path) {
            let rootStartedAt = PerformanceDiagnostics.start()
            let files = skillFiles(in: rootURL)
            var indexedFromRoot = 0
            for skillFile in files {
                let canonicalPath = skillFile.resolvingSymlinksInPath().standardizedFileURL.path
                guard indexedPaths.insert(canonicalPath).inserted else { continue }
                let skill = parseSkill(fileURL: skillFile, rootURL: rootURL, indexedAt: indexedAt)
                skills.append(skill)
                indexedFromRoot += 1
            }
            PerformanceDiagnostics.finish(
                "index_root",
                startedAt: rootStartedAt,
                logger: PerformanceDiagnostics.indexing,
                itemCount: indexedFromRoot,
                details: "discovered=\(files.count) source=\(sourceType(for: rootURL, fileURL: rootURL).rawValue)",
                slowThresholdMS: 50
            )
        }

        let duplicateNames = Dictionary(grouping: skills, by: { $0.name.lowercased() })
            .filter { $0.value.count > 1 }
            .map(\.key)

        guard duplicateNames.isEmpty == false else {
            let result = skills.sortedForLibrary()
            PerformanceDiagnostics.finish(
                "index_all_roots",
                startedAt: startedAt,
                logger: PerformanceDiagnostics.indexing,
                itemCount: result.count,
                details: "roots=\(rootURLs.count) duplicates=0",
                slowThresholdMS: 100
            )
            return result
        }

        let result = skills.map { skill in
            guard duplicateNames.contains(skill.name.lowercased()) else { return skill }
            var duplicate = skill
            duplicate.healthStatus = .duplicateName
            return duplicate
        }
        .sortedForLibrary()
        PerformanceDiagnostics.finish(
            "index_all_roots",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.indexing,
            itemCount: result.count,
            details: "roots=\(rootURLs.count) duplicate_names=\(duplicateNames.count)",
            slowThresholdMS: 100
        )
        return result
    }

    private func skillFiles(in rootURL: URL) -> [URL] {
        var files: [URL] = []

        if fileManager.fileExists(atPath: rootURL.appendingPathComponent("SKILL.md").path) {
            files.append(rootURL.appendingPathComponent("SKILL.md"))
        }

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: []
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
        let provenance = parseProvenance(for: fileURL)

        return Skill(
            id: fileURL.path,
            name: name,
            description: description,
            sourceType: sourceType(for: rootURL, fileURL: fileURL),
            sourcePath: fileURL.path,
            pluginURI: pluginURI(for: fileURL),
            rootPath: rootURL.path,
            tags: tags(for: name, description: description),
            provenance: provenance,
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
            tags: [],
            provenance: parseProvenance(for: fileURL),
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

    private func parseProvenance(for skillFileURL: URL) -> SkillProvenance? {
        let directoryURL = skillFileURL.deletingLastPathComponent()
        let sourceURL = ["SOURCE.md", "source.md", "souce.md"]
            .map(directoryURL.appendingPathComponent)
            .first { fileManager.fileExists(atPath: $0.path) }
        guard let sourceURL,
              let contents = try? String(contentsOf: sourceURL, encoding: .utf8) else {
            return nil
        }

        var fields: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("- "), let colon = trimmed.firstIndex(of: ":") else { continue }
            let keyStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
            let key = trimmed[keyStart..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = trimmed[trimmed.index(after: colon)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "`\"'"))
            if value.isEmpty == false {
                fields[key] = value
            }
        }

        guard let origin = fields["origin"] else { return nil }
        return SkillProvenance(
            origin: origin,
            group: fields["group"]?.nilIfBlank,
            groupPrefix: fields["group prefix"]?.nilIfBlank,
            creator: fields["creator"]?.nilIfBlank,
            authorMetadata: fields["author metadata"]?.nilIfBlank,
            repository: fields["repository"]?.nilIfBlank,
            sourceFilePath: sourceURL.path
        )
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
        if path.contains("/.codex/plugins/") { return .plugin }
        if path.contains("/plugins/cache/") { return .plugin }
        if path.contains("/.system/") { return .system }
        if rootURL.path.contains(".codex/skills") { return .local }
        return .project
    }

    private func pluginURI(for fileURL: URL) -> String? {
        let path = fileURL.path
        guard path.contains("/.codex/plugins/") || path.contains("/plugins/cache/") else { return nil }
        let components = fileURL.pathComponents
        if let cacheIndex = components.firstIndex(of: "cache"), components.indices.contains(cacheIndex + 1) {
            return "plugin://\(components[cacheIndex + 1])"
        }

        guard let pluginsIndex = components.firstIndex(of: "plugins"), components.indices.contains(pluginsIndex + 1) else { return nil }
        return "plugin://\(components[pluginsIndex + 1])"
    }

    private func tags(for name: String, description skillDescription: String) -> [String] {
        var tags = Set<String>()
        let searchableText = "\(name) \(skillDescription)".lowercased()
        for tokenSlice in searchableText.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let token = String(tokenSlice)
            if ["swiftui", "ios", "debug", "design", "frontend", "dependency", "testing"].contains(token) {
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
