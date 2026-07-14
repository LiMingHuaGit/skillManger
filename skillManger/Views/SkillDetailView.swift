//
//  SkillDetailView.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import SwiftUI

struct SkillDetailView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: SkillLibraryStore
    let skill: Skill?

    @State private var selectedTemplateID: String = PlatformTemplate.codexLocalSkill.id
    @State private var useCase: String = ""

    var body: some View {
        Group {
            if let skill {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(for: skill)
                        copyPanel(for: skill)
                        metadataPanel(for: skill)
                        excerptPanel(for: skill)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(skill.name)
                .onAppear {
                    selectedTemplateID = store.defaultTemplateID
                }
            } else {
                EmptyStateView(title: L10n.string("Select a skill", locale: locale), message: L10n.string("Choose a skill to see when to use it and copy a platform reference.", locale: locale), systemImage: "text.book.closed")
            }
        }
    }

    private func header(for skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(skill.name)
                        .font(.largeTitle.weight(.semibold))
                    Text(skill.description)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    store.toggleFavorite(skillID: skill.id)
                } label: {
                    Label(store.favoriteSkillIDs.contains(skill.id) ? L10n.string("Favorited", locale: locale) : L10n.string("Favorite", locale: locale), systemImage: store.favoriteSkillIDs.contains(skill.id) ? "star.fill" : "star")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                SourceBadge(sourceType: skill.sourceType)
                HealthBadge(status: skill.healthStatus)
                ForEach(skill.tags.prefix(4), id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.45), in: Capsule())
                }
            }
        }
    }

    private func copyPanel(for skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chat handoff")
                .font(.headline)

            Picker("Platform", selection: $selectedTemplateID) {
                ForEach(store.templates) { template in
                    Text("\(template.platformName) - \(template.templateType)").tag(template.id)
                }
            }
            .pickerStyle(.menu)

            if selectedTemplate?.body.contains("$use_case") == true {
                TextField("Use case for Codex instruction", text: $useCase)
                    .textFieldStyle(.roundedBorder)
            }

            Text(previewText(for: skill))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Button {
                    copyRenderedText(for: skill)
                } label: {
                    Label("Copy prompt", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)

                Button {
                    copyToPasteboard(skill.referencePath)
                    store.toastMessage = L10n.string("Source path copied", locale: locale)
                } label: {
                    Label("Copy source", systemImage: "link")
                }
                .buttonStyle(.bordered)

                if let toast = store.toastMessage {
                    Text(toast)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func metadataPanel(for skill: Skill) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow { Text("Source").foregroundStyle(.secondary); Text(L10n.string(skill.sourceType.localizationKey, locale: locale)) }
            GridRow { Text("Path").foregroundStyle(.secondary); Text(skill.sourcePath).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
            GridRow { Text("Indexed").foregroundStyle(.secondary); Text(skill.lastIndexedAt, style: .relative) }
            GridRow { Text("Modified").foregroundStyle(.secondary); Text(skill.lastModifiedAt, style: .date) }
        }
        .font(.callout)
    }

    private func excerptPanel(for skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKILL.md preview")
                .font(.headline)
            Text(skill.excerpt.isEmpty ? L10n.string("No preview available.", locale: locale) : skill.excerpt)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var selectedTemplate: PlatformTemplate? {
        store.templates.first { $0.id == selectedTemplateID }
    }

    private func previewText(for skill: Skill) -> String {
        guard let selectedTemplate else { return "" }
        return (try? CopyTemplateEngine.render(template: selectedTemplate, skill: skill, useCase: useCase.nilIfBlank ?? skill.description)) ?? L10n.string("Template needs a use case.", locale: locale)
    }

    private func copyRenderedText(for skill: Skill) {
        guard let selectedTemplate else { return }
        do {
            let text = try store.copyText(for: skill, template: selectedTemplate, useCase: useCase.nilIfBlank ?? skill.description)
            copyToPasteboard(text)
            store.toastMessage = L10n.format("Copied for %@", locale: locale, selectedTemplate.platformName)
        } catch {
            store.toastMessage = L10n.format("Copy failed: %@", locale: locale, error.localizedDescription)
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
