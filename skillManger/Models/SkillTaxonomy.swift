//
//  SkillTaxonomy.swift
//  skillManger
//
//  Created by Codex on 2026/9/2.
//

import Foundation

enum SkillOrigin: String, CaseIterable, Identifiable {
    case official
    case userInstalled

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        localized(locale: locale, english: englishTitle, chinese: chineseTitle)
    }

    var systemImage: String {
        switch self {
        case .official: "checkmark.seal.fill"
        case .userInstalled: "person.crop.circle.badge.checkmark"
        }
    }

    fileprivate var englishTitle: String {
        switch self {
        case .official: "Official"
        case .userInstalled: "User installed"
        }
    }

    fileprivate var chineseTitle: String {
        switch self {
        case .official: "官方内置"
        case .userInstalled: "用户安装"
        }
    }
}

enum SkillCategory: String, CaseIterable, Identifiable {
    case uiDesign
    case codeDevelopment
    case softwareOperations
    case imageMedia
    case documentsOffice
    case dataAnalysis
    case communication
    case other

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        localized(locale: locale, english: englishTitle, chinese: chineseTitle)
    }

    var systemImage: String {
        switch self {
        case .uiDesign: "paintbrush.pointed"
        case .codeDevelopment: "chevron.left.forwardslash.chevron.right"
        case .softwareOperations: "cursorarrow.click.2"
        case .imageMedia: "photo.on.rectangle.angled"
        case .documentsOffice: "doc.text"
        case .dataAnalysis: "chart.xyaxis.line"
        case .communication: "bubble.left.and.bubble.right"
        case .other: "square.grid.2x2"
        }
    }

    fileprivate var englishTitle: String {
        switch self {
        case .uiDesign: "UI Design"
        case .codeDevelopment: "Code Development"
        case .softwareOperations: "Software Operations"
        case .imageMedia: "Image & Media"
        case .documentsOffice: "Documents & Office"
        case .dataAnalysis: "Data Analysis"
        case .communication: "Communication"
        case .other: "Other"
        }
    }

    fileprivate var chineseTitle: String {
        switch self {
        case .uiDesign: "UI 设计"
        case .codeDevelopment: "代码开发"
        case .softwareOperations: "软件操作"
        case .imageMedia: "图像与媒体"
        case .documentsOffice: "文档办公"
        case .dataAnalysis: "数据分析"
        case .communication: "沟通协作"
        case .other: "其他"
        }
    }
}

enum SkillClassifier {
    static func origin(for skill: Skill) -> SkillOrigin {
        let path = skill.sourcePath.lowercased()
        let officialPathMarkers = [
            "/.codex/skills/.system/",
            "/plugins/cache/openai-api-curated/",
            "/plugins/cache/openai-curated/",
            "/plugins/cache/openai-bundled/"
        ]

        if skill.sourceType == .system || officialPathMarkers.contains(where: path.contains) {
            return .official
        }
        return .userInstalled
    }

    static func category(for skill: Skill) -> SkillCategory {
        let text = normalizedText(
            ([skill.name, skill.description, skill.excerpt] + skill.tags)
                .joined(separator: " ")
        )
        let tokens = Set(text.split(separator: " ").map(String.init))

        let scores = SkillCategory.allCases.map { category in
            (category, score(for: category, text: text, tokens: tokens))
        }
        guard let best = scores.max(by: { lhs, rhs in lhs.1 < rhs.1 }), best.1 > 0 else {
            return .other
        }
        return best.0
    }

    static func searchTerms(for skill: Skill) -> [String] {
        let origin = origin(for: skill)
        let category = category(for: skill)
        return [
            origin.rawValue,
            origin.englishTitle,
            origin.chineseTitle,
            category.rawValue,
            category.englishTitle,
            category.chineseTitle
        ]
    }

    private static func score(for category: SkillCategory, text: String, tokens: Set<String>) -> Int {
        patterns(for: category).reduce(into: 0) { result, pattern in
            if matches(pattern.term, text: text, tokens: tokens) {
                result += pattern.weight
            }
        }
    }

    private static func matches(_ term: String, text: String, tokens: Set<String>) -> Bool {
        let normalizedTerm = normalizedText(term)
        if normalizedTerm.contains(" ") || normalizedTerm.unicodeScalars.contains(where: { $0.value > 127 }) {
            return text.contains(normalizedTerm)
        }
        return tokens.contains(normalizedTerm)
    }

    private static func normalizedText(_ value: String) -> String {
        String(value.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
            .split(separator: " ")
            .map(String.init)
            .joined(separator: " ")
    }

    private static func patterns(for category: SkillCategory) -> [(term: String, weight: Int)] {
        switch category {
        case .uiDesign:
            [
                ("ui design", 7), ("ux design", 7), ("user interface", 6), ("design system", 6),
                ("frontend design", 5), ("visual design", 5), ("product design", 5),
                ("typography", 3), ("layout", 3), ("figma", 4), ("canva", 4),
                ("brand", 3), ("ui", 2), ("ux", 2), ("design", 1),
                ("界面设计", 7), ("交互设计", 7), ("视觉设计", 5), ("排版", 3), ("设计", 1)
            ]
        case .codeDevelopment:
            [
                ("software development", 6), ("code", 4), ("coding", 4), ("developer", 3),
                ("swiftui", 5), ("appkit", 5), ("swift", 4), ("ios", 4), ("macos", 4),
                ("react", 4), ("next js", 4), ("typescript", 4), ("javascript", 4),
                ("python", 4), ("api", 3), ("backend", 4), ("frontend", 3),
                ("debug", 3), ("testing", 3), ("github", 3), ("git", 2),
                ("开发", 5), ("代码", 5), ("编程", 5), ("调试", 4), ("测试", 3)
            ]
        case .softwareOperations:
            [
                ("computer use", 7), ("browser control", 7), ("control chrome", 7),
                ("software operation", 6), ("automation", 4), ("browser", 4), ("chrome", 4),
                ("click", 3), ("terminal", 3), ("shell", 3), ("command", 2),
                ("install", 3), ("dependency", 3), ("workflow", 2),
                ("软件操作", 7), ("浏览器", 5), ("自动化", 5), ("终端", 4),
                ("命令行", 4), ("安装", 3), ("依赖", 3)
            ]
        case .imageMedia:
            [
                ("image generation", 7), ("image", 4), ("video", 4), ("audio", 4),
                ("blender", 5), ("3d", 4), ("render", 4), ("animation", 4),
                ("photo", 4), ("icon", 3), ("media", 3), ("illustration", 3),
                ("图像生成", 7), ("图像", 5), ("图片", 5), ("视频", 5),
                ("音频", 5), ("动画", 4), ("渲染", 4), ("图标", 3)
            ]
        case .documentsOffice:
            [
                ("document", 4), ("docx", 6), ("pdf", 6), ("pptx", 6),
                ("spreadsheet", 5), ("xlsx", 6), ("slides", 5), ("presentation", 5),
                ("markdown", 3), ("office", 4), ("word", 3),
                ("文档", 5), ("表格", 5), ("幻灯片", 5), ("演示文稿", 5), ("办公", 4)
            ]
        case .dataAnalysis:
            [
                ("data visualization", 7), ("data analysis", 7), ("analytics", 5),
                ("database", 4), ("sql", 4), ("chart", 4), ("dashboard", 3),
                ("reporting", 3), ("csv", 4), ("statistics", 4),
                ("数据分析", 7), ("数据可视化", 7), ("数据库", 5), ("图表", 4), ("报表", 4)
            ]
        case .communication:
            [
                ("lark", 5), ("feishu", 5), ("calendar", 4), ("meeting", 4),
                ("email", 4), ("mail", 3), ("message", 3), ("contact", 3),
                ("collaboration", 4), ("approval", 3), ("okr", 3),
                ("飞书", 6), ("日历", 4), ("会议", 4), ("邮件", 4),
                ("消息", 3), ("通讯录", 3), ("协作", 4), ("审批", 3)
            ]
        case .other:
            []
        }
    }
}

extension Skill {
    var origin: SkillOrigin {
        SkillClassifier.origin(for: self)
    }

    var category: SkillCategory {
        SkillClassifier.category(for: self)
    }
}

private func localized(locale: Locale, english: String, chinese: String) -> String {
    locale.identifier.lowercased().hasPrefix("zh") ? chinese : english
}
