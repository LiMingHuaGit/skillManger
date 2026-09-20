//
//  ContentView.swift
//  skillManger
//
//  Created by ming on 2026/7/14.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var languageSettings: AppLanguageSettings
    @ObservedObject var launchAtLoginSettings: LaunchAtLoginSettings
    @ObservedObject var notchSettings: NotchWorkspaceSettings

    init(
        store: SkillLibraryStore = SkillManagerAppState.shared.store,
        languageSettings: AppLanguageSettings = SkillManagerAppState.shared.languageSettings,
        launchAtLoginSettings: LaunchAtLoginSettings = SkillManagerAppState.shared.launchAtLoginSettings,
        notchSettings: NotchWorkspaceSettings = SkillManagerAppState.shared.notchSettings
    ) {
        self.store = store
        self.languageSettings = languageSettings
        self.launchAtLoginSettings = launchAtLoginSettings
        self.notchSettings = notchSettings
    }

    var body: some View {
        SkillLibraryView(
            store: store,
            languageSettings: languageSettings,
            launchAtLoginSettings: launchAtLoginSettings,
            notchSettings: notchSettings
        )
            .environment(\.locale, languageSettings.locale)
            .frame(minWidth: 1120, minHeight: 720)
    }
}

#Preview {
    ContentView()
}
