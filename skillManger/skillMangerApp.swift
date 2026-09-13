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
    @StateObject private var launchAtLoginSettings = SkillManagerAppState.shared.launchAtLoginSettings

    var body: some Scene {
        MenuBarExtra {
            Button {
                SkillNotchPanelController.shared.createNote()
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button {
                SkillNotchPanelController.shared.expand(animated: true, activate: true)
            } label: {
                Label("Show Notch", systemImage: "rectangle.topthird.inset.filled")
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

            Toggle(isOn: Binding(
                get: { launchAtLoginSettings.isEnabled },
                set: { launchAtLoginSettings.setEnabled($0) }
            )) {
                Label(L10n.string("Launch at Login", locale: languageSettings.locale), systemImage: "power")
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
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    SkillNotchPanelController.shared.createNote()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .textEditing) {
                Button("Find…") {
                    FindCommand.perform(.showFindInterface)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    FindCommand.perform(.nextMatch)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    FindCommand.perform(.previousMatch)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            CommandMenu("Notch") {
                Button("Show") {
                    SkillNotchPanelController.shared.expand(animated: true, activate: true)
                }
                Button("Hide") {
                    SkillNotchPanelController.shared.collapse(animated: true)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
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

    func applicationWillTerminate(_ notification: Notification) {
        SkillNotchPanelController.shared.flush()
    }
}

private enum FindCommand {
    @MainActor
    static func perform(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: sender)
    }
}
