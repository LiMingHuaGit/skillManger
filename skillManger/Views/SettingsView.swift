//
//  SettingsView.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var languageSettings: AppLanguageSettings
    @ObservedObject var launchAtLoginSettings: LaunchAtLoginSettings
    @State private var customTemplateName: String = String(localized: "Custom Platform")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                languageSection
                launchSection
                rootsSection
                templatesSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Settings")
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language")
                .font(.title2.weight(.semibold))

            Picker("App language", selection: $languageSettings.selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(L10n.string(language.displayNameKey, locale: locale)).tag(language)
                }
            }
            .pickerStyle(.segmented)

            Text("Language changes apply immediately in the app. The Dock name follows this choice the next time the app launches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("Launch", locale: locale))
                .font(.title2.weight(.semibold))

            Toggle(isOn: Binding(
                get: { launchAtLoginSettings.isEnabled },
                set: { launchAtLoginSettings.setEnabled($0) }
            )) {
                Label(L10n.string("Launch at Login", locale: locale), systemImage: "power")
            }

            if launchAtLoginSettings.needsApproval {
                Text(L10n.string("Launch at login may need approval in System Settings.", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let errorMessage = launchAtLoginSettings.errorMessage {
                Text(L10n.format("Launch at login failed: %@", locale: locale, errorMessage))
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(L10n.string("Start Skill Manager automatically when you sign in.", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private var rootsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skill roots")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    addRootWithPanel()
                } label: {
                    Label("Add root", systemImage: "folder.badge.plus")
                }
                Button {
                    try? store.refresh()
                } label: {
                    Label("Re-index", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
            }

            HStack(spacing: 24) {
                Toggle("Show system skills", isOn: Binding(
                    get: { store.showSystemSkills },
                    set: { store.showSystemSkills = $0 }
                ))
                Toggle("Show plugin skills", isOn: Binding(
                    get: { store.showPluginSkills },
                    set: { store.showPluginSkills = $0 }
                ))
            }

            ForEach($store.roots) { $root in
                HStack(alignment: .firstTextBaseline) {
                    Toggle("", isOn: $root.enabled)
                        .labelsHidden()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(root.path)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(L10n.string(root.sourceType.localizationKey, locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        store.roots.removeAll { $0.id == root.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "Remove root"))
                }
                .padding(10)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Copy templates")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Reset templates") {
                    store.resetTemplates()
                }
            }

            Picker("Default platform", selection: Binding(
                get: { store.defaultTemplateID },
                set: { store.defaultTemplateID = $0 }
            )) {
                ForEach(store.templates) { template in
                    Text("\(template.platformName) - \(template.templateType)").tag(template.id)
                }
            }
            .pickerStyle(.menu)

            HStack {
                TextField("Custom platform name", text: $customTemplateName)
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.addCustomTemplate(named: customTemplateName, basedOn: store.defaultTemplate)
                } label: {
                    Label("Add custom", systemImage: "plus")
                }
            }

            ForEach(store.templates) { template in
                TemplateEditorRow(store: store, template: template)
            }
        }
    }

    private func addRootWithPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Add Root")

        if panel.runModal() == .OK, let url = panel.url {
            let root = SkillRoot(path: url.path, enabled: true, sourceType: .project, lastIndexedAt: nil, lastError: nil)
            if store.roots.contains(where: { $0.path == root.path }) == false {
                store.roots.append(root)
            }
        }
    }
}

private struct TemplateEditorRow: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: SkillLibraryStore
    let templateID: String
    let templateType: String
    let isBuiltIn: Bool

    @State private var platformName: String
    @State private var templateBody: String

    init(store: SkillLibraryStore, template: PlatformTemplate) {
        self.store = store
        templateID = template.id
        templateType = template.templateType
        isBuiltIn = template.isBuiltIn
        _platformName = State(initialValue: template.platformName)
        _templateBody = State(initialValue: template.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Platform name", text: $platformName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Text(templateType)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.45), in: Capsule())
                if isBuiltIn {
                    Text("Built-in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.updateTemplate(id: templateID, platformName: platformName, body: templateBody)
                    store.toastMessage = L10n.string("Template saved", locale: locale)
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: $templateBody)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 76)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

            Text("Variables: $skill_name, $skill_path, $plugin_name, $plugin_id, $description, $use_case")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
}
