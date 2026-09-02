//
//  SkillRecommender.swift
//  skillManger
//
//  Created by Codex on 2026/8/24.
//

import Foundation

struct SkillRecommender {
    private static let maximumWeightedTerms = 64
    private static let maximumTokensPerText = 256

    func recommendations(for context: CodexSessionContext, skills: [Skill], limit: Int = 12) -> [SkillRecommendation] {
        let startedAt = PerformanceDiagnostics.start()
        let weightedTerms = Self.weightedTerms(for: context)
        guard weightedTerms.isEmpty == false else { return [] }

        let results: [SkillRecommendation] = skills.compactMap { skill in
            let score = score(skill: skill, weightedTerms: weightedTerms)
            guard score.value >= 4 else { return nil }
            return SkillRecommendation(skill: skill, score: score.value, matchedTerms: score.matches)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.skill.name.localizedCaseInsensitiveCompare(rhs.skill.name) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
        .prefix(limit)
        .map { $0 }
        PerformanceDiagnostics.finish(
            "recommendation_scoring",
            startedAt: startedAt,
            logger: PerformanceDiagnostics.recommendations,
            itemCount: results.count,
            details: "skills=\(skills.count) terms=\(weightedTerms.count)",
            slowThresholdMS: 20
        )
        return results
    }

    private func score(skill: Skill, weightedTerms: [String: Double]) -> (value: Double, matches: [String]) {
        let name = skill.name.lowercased()
        let description = skill.description.lowercased()
        let tags = skill.tags.joined(separator: " ").lowercased()
        let sourcePath = skill.sourcePath.lowercased()
        let pluginURI = skill.pluginURI?.lowercased() ?? ""

        var score = 0.0
        var matchedTerms: [String] = []

        for (term, weight) in weightedTerms {
            var termScore = 0.0

            if name == term {
                termScore += 22
            } else if name.contains(term) {
                termScore += 12
            }

            if tags.contains(term) {
                termScore += 8
            }

            if description.contains(term) {
                termScore += 5
            }

            if sourcePath.contains(term) || pluginURI.contains(term) {
                termScore += 2
            }

            if termScore > 0 {
                score += termScore * weight
                matchedTerms.append(term)
            }
        }

        return (score, Array(matchedTerms.sorted { lhs, rhs in
            (weightedTerms[lhs] ?? 0) > (weightedTerms[rhs] ?? 0)
        }.prefix(6)))
    }

    private static func weightedTerms(for context: CodexSessionContext) -> [String: Double] {
        var terms: [String: Double] = [:]
        addTokens(from: context.title, weight: 3.0, characterLimit: 160, to: &terms)
        addTokens(from: context.preview, weight: 2.0, characterLimit: 400, to: &terms)
        addTokens(from: context.cwd, weight: 1.4, characterLimit: 300, to: &terms)
        for message in context.recentUserMessages {
            addTokens(from: message, weight: 1.0, characterLimit: 600, to: &terms)
        }

        return Dictionary(uniqueKeysWithValues: terms
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                if lhs.key.count != rhs.key.count { return lhs.key.count > rhs.key.count }
                return lhs.key < rhs.key
            }
            .prefix(maximumWeightedTerms)
            .map { ($0.key, $0.value) })
    }

    private static func addTokens(from text: String, weight: Double, characterLimit: Int, to terms: inout [String: Double]) {
        for token in tokenize(String(text.prefix(characterLimit))) {
            terms[token, default: 0] += weight
        }
    }

    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentKind: TokenKind?

        func flush() {
            guard current.isEmpty == false else { return }
            if currentKind == .cjk {
                tokens.append(contentsOf: cjkTokens(current))
            } else if current.count >= 2, stopWords.contains(current) == false {
                tokens.append(current)
            }
            current = ""
            currentKind = nil
        }

        for scalar in text.lowercased().unicodeScalars {
            let kind: TokenKind?
            if isCJK(scalar) {
                kind = .cjk
            } else if CharacterSet.alphanumerics.contains(scalar) {
                kind = .latin
            } else {
                kind = nil
            }

            guard let kind else {
                flush()
                continue
            }

            if currentKind != nil, currentKind != kind {
                flush()
            }
            currentKind = kind
            current.unicodeScalars.append(scalar)
        }
        flush()

        var seen = Set<String>()
        return tokens.filter { seen.insert($0).inserted }.prefix(maximumTokensPerText).map { $0 }
    }

    private static func cjkTokens(_ text: String) -> [String] {
        let characters = Array(text)
        guard characters.count >= 2 else { return [] }

        var tokens = Set<String>()
        if characters.count <= 8 {
            tokens.insert(text)
        }

        for size in 2...min(4, characters.count) {
            for start in 0...(characters.count - size) {
                let token = String(characters[start..<(start + size)])
                if stopWords.contains(token) == false {
                    tokens.insert(token)
                }
            }
        }
        return Array(tokens)
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        (0x4E00...0x9FFF).contains(Int(scalar.value))
    }

    private enum TokenKind {
        case latin
        case cjk
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "into", "your", "you", "use", "using", "user", "users", "app", "apps", "project", "file", "files", "path", "code", "codex", "skill", "skills", "plugin", "plugins",
        "帮我", "当前", "这个", "一个", "可以", "是否", "进行", "使用", "用户", "项目", "文件", "代码", "实现", "查看", "分析", "修改", "功能", "需要"
    ]
}
