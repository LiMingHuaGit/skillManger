//
//  CodexConfigPluginResolver.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation

struct CodexConfigPluginResolver {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func activePluginRootURLs(configURL: URL, homeDirectory: String) -> [URL] {
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else { return [] }
        let config = parseConfig(contents)
        let codexHome = URL(fileURLWithPath: homeDirectory).appendingPathComponent(".codex", isDirectory: true)

        var roots: [URL] = []
        for pluginRef in config.enabledPluginRefs.sorted() {
            let parts = pluginRef.split(separator: "@", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let pluginID = parts[0]
            let marketplaceID = parts[1]

            roots.append(contentsOf: cachedInstallRoots(codexHome: codexHome, marketplaceID: marketplaceID, pluginID: pluginID))
            if roots.contains(where: { $0.path.contains("/\(marketplaceID)/\(pluginID)/") || $0.path.hasSuffix("/\(marketplaceID)/\(pluginID)") }) == false,
               let source = config.marketplaceSources[marketplaceID] {
                roots.append(contentsOf: sourcePluginRoots(source: source, pluginID: pluginID))
            }
        }

        return uniqueExistingDirectories(roots)
    }

    private func parseConfig(_ contents: String) -> ParsedCodexConfig {
        var config = ParsedCodexConfig()
        var currentMarketplaceID: String?
        var currentPluginRef: String?

        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.isEmpty == false, line.hasPrefix("#") == false else { continue }

            if line.hasPrefix("["), line.hasSuffix("]") {
                let table = String(line.dropFirst().dropLast())
                currentMarketplaceID = tableName(in: table, prefix: "marketplaces.")
                currentPluginRef = tableName(in: table, prefix: "plugins.")
                continue
            }

            if let marketplaceID = currentMarketplaceID,
               keyName(in: line) == "source",
               let source = quotedValue(in: line) {
                config.marketplaceSources[marketplaceID] = URL(fileURLWithPath: NSString(string: source).expandingTildeInPath)
            }

            if let pluginRef = currentPluginRef,
               keyName(in: line) == "enabled",
               boolValue(in: line) == true {
                config.enabledPluginRefs.insert(pluginRef)
            }
        }

        return config
    }

    private func cachedInstallRoots(codexHome: URL, marketplaceID: String, pluginID: String) -> [URL] {
        let pluginDirectory = codexHome
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent(marketplaceID, isDirectory: true)
            .appendingPathComponent(pluginID, isDirectory: true)

        return newestSkillBearingChildren(in: pluginDirectory) ?? (containsSkill(in: pluginDirectory) ? [pluginDirectory] : [])
    }

    private func sourcePluginRoots(source: URL, pluginID: String) -> [URL] {
        let candidates = [
            source.appendingPathComponent("plugins", isDirectory: true).appendingPathComponent(pluginID, isDirectory: true),
            source.appendingPathComponent(pluginID, isDirectory: true)
        ]

        return candidates.filter { containsSkill(in: $0) }
    }

    private func newestSkillBearingChildren(in directory: URL) -> [URL]? {
        guard let children = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey]) else {
            return nil
        }

        let skillBearingChildren = children.filter { child in
            (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && containsSkill(in: child)
        }
        guard skillBearingChildren.isEmpty == false else { return nil }

        let sorted = skillBearingChildren.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedDescending
            }
            return lhsDate > rhsDate
        }
        return Array(sorted.prefix(1))
    }

    private func containsSkill(in directory: URL) -> Bool {
        guard fileManager.fileExists(atPath: directory.path),
              let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: []) else {
            return false
        }

        for case let url as URL in enumerator where url.lastPathComponent == "SKILL.md" {
            return true
        }
        return false
    }

    private func uniqueExistingDirectories(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.compactMap { url in
            let path = url.standardizedFileURL.path
            guard fileManager.fileExists(atPath: path), seen.insert(path).inserted else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    private func tableName(in table: String, prefix: String) -> String? {
        guard table.hasPrefix(prefix) else { return nil }
        let rawName = String(table.dropFirst(prefix.count))
        return rawName.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    private func quotedValue(in line: String) -> String? {
        guard let equals = line.firstIndex(of: "=") else { return nil }
        let rawValue = line[line.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard rawValue.hasPrefix("\"") else { return nil }
        var value = ""
        var isEscaped = false
        for character in rawValue.dropFirst() {
            if isEscaped {
                value.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                return value
            } else {
                value.append(character)
            }
        }
        return nil
    }

    private func keyName(in line: String) -> String? {
        guard let equals = line.firstIndex(of: "=") else { return nil }
        return line[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func boolValue(in line: String) -> Bool? {
        guard let equals = line.firstIndex(of: "=") else { return nil }
        let rawValue = line[line.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if rawValue.hasPrefix("true") { return true }
        if rawValue.hasPrefix("false") { return false }
        return nil
    }
}

private struct ParsedCodexConfig {
    var marketplaceSources: [String: URL] = [:]
    var enabledPluginRefs = Set<String>()
}
