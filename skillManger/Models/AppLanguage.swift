//
//  AppLanguage.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .system: "Follow System"
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english: Locale(identifier: "en")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        }
    }

    var appleLanguages: [String]? {
        switch self {
        case .system: nil
        case .english: ["en"]
        case .simplifiedChinese: ["zh-Hans"]
        }
    }
}

final class AppLanguageSettings: ObservableObject {
    private let defaults: UserDefaults
    private let languageKey = "appLanguage"

    @Published var selection: AppLanguage {
        didSet { persistSelection() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawValue = defaults.string(forKey: languageKey) ?? AppLanguage.system.rawValue
        selection = AppLanguage(rawValue: rawValue) ?? .system
    }

    var locale: Locale { selection.locale }

    private func persistSelection() {
        defaults.set(selection.rawValue, forKey: languageKey)
        if let appleLanguages = selection.appleLanguages {
            defaults.set(appleLanguages, forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}

enum L10n {
    static func string(_ key: String, locale: Locale) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        String(format: string(key, locale: locale), locale: locale, arguments: arguments)
    }
}
