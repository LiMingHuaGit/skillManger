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
    let noteStore: NoteStore
    let notchSettings: NotchWorkspaceSettings
    let imageStore: LocalImageStore
    let fileShelfStore: FileShelfStore
    let notebookWorkspaceState: NotebookWorkspaceState
    let editorInteractionState: EditorInteractionState
    let notchNavigation: NotchWorkspaceNavigation

    private init() {
        store = SkillLibraryStore()
        languageSettings = AppLanguageSettings()
        launchAtLoginSettings = LaunchAtLoginSettings()
        noteStore = NoteStore()
        notchSettings = NotchWorkspaceSettings()
        imageStore = LocalImageStore()
        fileShelfStore = FileShelfStore()
        notebookWorkspaceState = NotebookWorkspaceState()
        editorInteractionState = EditorInteractionState()
        notchNavigation = NotchWorkspaceNavigation()
    }

    @MainActor
    func refreshIfNeeded() {
        if store.skills.isEmpty {
            try? store.refresh()
        }
    }
}
