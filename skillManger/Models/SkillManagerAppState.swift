//
//  SkillManagerAppState.swift
//  skillManger
//
//  Created by Codex on 2026/8/24.
//

import Foundation
import Combine

final class SkillManagerAppState: ObservableObject {
    static let shared = SkillManagerAppState()

    let store: SkillLibraryStore
    let languageSettings: AppLanguageSettings
    let launchAtLoginSettings: LaunchAtLoginSettings

    private init() {
        store = SkillLibraryStore()
        languageSettings = AppLanguageSettings()
        launchAtLoginSettings = LaunchAtLoginSettings()
    }

    @MainActor
    func refreshIfNeeded() {
        if store.skills.isEmpty {
            try? store.refresh()
        } else {
            store.refreshRecommendations()
        }
    }
}
