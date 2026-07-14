//
//  ContentView.swift
//  skillManger
//
//  Created by ming on 2026/7/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = SkillLibraryStore()
    @StateObject private var languageSettings = AppLanguageSettings()

    var body: some View {
        SkillLibraryView(store: store, languageSettings: languageSettings)
            .environment(\.locale, languageSettings.locale)
            .frame(minWidth: 1120, minHeight: 720)
            .task {
                try? store.refresh()
            }
    }
}

#Preview {
    ContentView()
}
