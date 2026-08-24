//
//  skillMangerApp.swift
//  skillManger
//
//  Created by ming on 2026/7/14.
//

import AppKit
import SwiftUI

@main
struct skillMangerApp: App {
    @NSApplicationDelegateAdaptor(SkillManagerAppDelegate.self) private var appDelegate
    @StateObject private var languageSettings = SkillManagerAppState.shared.languageSettings

    var body: some Scene {
        MenuBarExtra("Skill Manager", systemImage: "sparkle.magnifyingglass") {
            Button {
                SkillNotchPanelController.shared.toggleNotchVisibility()
            } label: {
                Label(L10n.string("Show or Hide Notch", locale: languageSettings.locale), systemImage: "rectangle.topthird.inset.filled")
            }

            Button {
                SkillNotchPanelController.shared.showLibraryWindow()
            } label: {
                Label(L10n.string("Open Library", locale: languageSettings.locale), systemImage: "rectangle.grid.2x2")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button {
                SkillNotchPanelController.shared.refreshLibrary()
            } label: {
                Label(L10n.string("Re-index", locale: languageSettings.locale), systemImage: "arrow.clockwise")
            }

            Divider()

            Picker(L10n.string("Language", locale: languageSettings.locale), selection: $languageSettings.selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(L10n.string(language.displayNameKey, locale: languageSettings.locale)).tag(language)
                }
            }

            Divider()

            Button(L10n.string("Quit", locale: languageSettings.locale), role: .destructive) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

final class SkillManagerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        SkillNotchPanelController.shared.showNotch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
