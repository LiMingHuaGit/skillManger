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
        MenuBarExtra {
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
        } label: {
            SkillMenuBarLabel()
        }
    }
}

private struct SkillMenuBarLabel: View {
    var body: some View {
        Label {
            Text(verbatim: "skills")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        } icon: {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .symbolRenderingMode(.hierarchical)
        }
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .help("Skill Manager")
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
