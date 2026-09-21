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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: SkillLibraryStore
    let skill: Skill?

    @State private var selectedTemplateID: String = PlatformTemplate.codexLocalSkill.id
    @State private var useCase: String = ""
    @State private var activeAlert: SkillDetailAlert?

    var body: some View {
        Group {
            if let skill {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(for: skill)
                        copyPanel(for: skill)
                        metadataPanel(for: skill)
                        duplicatePanel(for: skill)
                        excerptPanel(for: skill)
                    }
                    .padding(28)
                    .frame(maxWidth: 920, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .background(SkillManagerTheme.canvas)
                .navigationTitle(skill.name)
                .onAppear {
                    selectedTemplateID = store.defaultTemplateID
                }
            } else {
                EmptyStateView(title: L10n.string("Select a skill", locale: locale), message: L10n.string("Choose a skill to see when to use it and copy a platform reference.", locale: locale), systemImage: "text.book.closed")
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .delete(let skill):
                Alert(
                    title: Text(deleteTitle(for: skill)),
                    message: Text(deleteMessage(for: skill)),
                    primaryButton: .destructive(Text(deleteButtonTitle)) {
                        delete(skill)
                    },
                    secondaryButton: .cancel(Text(cancelButtonTitle))
                )
            case .error(let message):
                Alert(
                    title: Text(deletionFailedTitle),
                    message: Text(message),
                    dismissButton: .default(Text(confirmButtonTitle))
                )
            }
        }
    }

    private func header(for skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SkillManagerTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(SkillManagerTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(skill.name)
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(skill.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                Spacer()
                if store.canDelete(skill) {
                    Button(role: .destructive) {
                        activeAlert = .delete(skill)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.red)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)
                    .help(deleteSkillTitle)
                }
                Button {
                    store.toggleFavorite(skillID: skill.id)
                } label: {
                    Image(systemName: store.favoriteSkillIDs.contains(skill.id) ? "star.fill" : "star")
                        .foregroundStyle(store.favoriteSkillIDs.contains(skill.id) ? Color.yellow : Color.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .help(store.favoriteSkillIDs.contains(skill.id) ? L10n.string("Favorited", locale: locale) : L10n.string("Favorite", locale: locale))
                .animation(reduceMotion ? nil : SkillManagerTheme.responsiveSpring, value: store.favoriteSkillIDs.contains(skill.id))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    OriginBadge(origin: skill.origin)
                    if let group = skill.group {
                        SkillGroupBadge(group: group)
                    }
                    CategoryBadge(category: skill.category)
                    HealthBadge(status: skill.healthStatus)
                    ForEach(skill.tags.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(SkillManagerTheme.quietFill, in: Capsule())
                    }
                }
            }
        }
    }

    private func copyPanel(for skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelSectionTitle(title: "Chat handoff", systemImage: "bubble.left.and.text.bubble.right")

            HStack(spacing: 12) {
                Text("Platform")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .leading)
                Picker("Platform", selection: $selectedTemplateID) {
                    ForEach(store.templates) { template in
                        Text("\(template.platformName) - \(template.templateType)").tag(template.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 320)
            }

            if selectedTemplate?.body.contains("$use_case") == true {
                TextField("Use case for Codex instruction", text: $useCase)
                    .textFieldStyle(.roundedBorder)
            }

            Text(previewText(for: skill))
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SkillManagerTheme.surface, in: RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous)
                        .stroke(SkillManagerTheme.subtleBorder)
                }

            HStack {
                Button {
                    copyRenderedText(for: skill)
                } label: {
                    Label("Copy prompt", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .tint(SkillManagerTheme.accent)

                Button {
                    copyToPasteboard(skill.referencePath)
                    store.toastMessage = L10n.string("Source path copied", locale: locale)
                } label: {
                    Label("Copy source", systemImage: "link")
                }
                .buttonStyle(.bordered)

                if let toast = store.toastMessage {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SkillManagerTheme.accent)
                        .transition(.opacity)
                }
            }
        }
        .padding(16)
        .panelSurface(emphasized: true)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: store.toastMessage)
    }

    private func metadataPanel(for skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelSectionTitle(title: "Details", systemImage: "info.circle")
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow { Text("Source").foregroundStyle(.secondary); Text(L10n.string(skill.sourceType.localizationKey, locale: locale)) }
                GridRow { Text(originLabel).foregroundStyle(.secondary); Text(skill.origin.title(locale: locale)) }
                if let group = skill.group {
                    GridRow { Text(groupLabel).foregroundStyle(.secondary); Text(group).textSelection(.enabled) }
                }
                if let repository = skill.provenance?.repository {
                    GridRow { Text(repositoryLabel).foregroundStyle(.secondary); Text(repository).textSelection(.enabled) }
                }
                if let sourceFilePath = skill.provenance?.sourceFilePath {
                    GridRow { Text(sourceRecordLabel).foregroundStyle(.secondary); Text(sourceFilePath).font(.system(.callout, design: .monospaced)).textSelection(.enabled) }
                }
                GridRow { Text("Path").foregroundStyle(.secondary); Text(skill.sourcePath).font(.system(.callout, design: .monospaced)).textSelection(.enabled) }
                GridRow { Text("Indexed").foregroundStyle(.secondary); Text(skill.lastIndexedAt, style: .relative) }
                GridRow { Text("Modified").foregroundStyle(.secondary); Text(skill.lastModifiedAt, style: .date) }
            }
            .font(.callout)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func duplicatePanel(for skill: Skill) -> some View {
        let duplicates = store.duplicateSkills(for: skill)
        if duplicates.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    PanelSectionTitle(title: "Duplicate skills", systemImage: "square.on.square")
                    Spacer()
                    Button {
                        copyDuplicateReport(for: skill, duplicates: duplicates)
                    } label: {
                        Label("Copy duplicate report", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }

                Text("These skills share the same name. Reveal or copy paths to decide which one to keep, rename, or remove.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(duplicates, id: \.sourcePath) { duplicate in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                SourceBadge(sourceType: duplicate.sourceType)
                                Text(duplicate.rootPath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    copyToPasteboard(duplicate.sourcePath)
                                    store.toastMessage = L10n.string("Duplicate path copied", locale: locale)
                                } label: {
                                    Label("Copy path", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    revealInFinder(duplicate.sourcePath)
                                } label: {
                                    Label("Reveal in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.borderless)
                            }

                            Text(duplicate.sourcePath)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 10)

                        if duplicate.sourcePath != duplicates.last?.sourcePath {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(SkillManagerTheme.surface, in: RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous))
            }
            .padding(16)
            .panelSurface(emphasized: true)
        }
    }

    private func excerptPanel(for skill: Skill) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelSectionTitle(title: "SKILL.md preview", systemImage: "doc.plaintext")
            Text(skill.excerpt.isEmpty ? L10n.string("No preview available.", locale: locale) : skill.excerpt)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .lineSpacing(3)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SkillManagerTheme.surface, in: RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: SkillManagerTheme.controlRadius, style: .continuous)
                        .stroke(SkillManagerTheme.subtleBorder)
                }
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

    private func copyDuplicateReport(for skill: Skill, duplicates: [Skill]) {
        let report = ([skill] + duplicates)
            .map { duplicate in
                "\(duplicate.name)\n\(duplicate.sourcePath)"
            }
            .joined(separator: "\n\n")
        copyToPasteboard(report)
        store.toastMessage = L10n.string("Duplicate report copied", locale: locale)
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func delete(_ skill: Skill) {
        do {
            try store.deleteSkill(skill)
            store.toastMessage = skillDeletedMessage
        } catch {
            activeAlert = .error(localizedDeletionError(error))
        }
    }

    private var isChinese: Bool {
        locale.identifier.lowercased().hasPrefix("zh")
    }

    private var deleteSkillTitle: String { isChinese ? "删除 Skill" : "Delete Skill" }
    private var deleteButtonTitle: String { isChinese ? "删除" : "Delete" }
    private var cancelButtonTitle: String { isChinese ? "取消" : "Cancel" }
    private var confirmButtonTitle: String { isChinese ? "确定" : "OK" }
    private var deletionFailedTitle: String { isChinese ? "删除失败" : "Deletion Failed" }
    private var skillDeletedMessage: String { isChinese ? "Skill 已删除" : "Skill deleted" }
    private var originLabel: String { isChinese ? "来源" : "Origin" }
    private var groupLabel: String { isChinese ? "Skill 组" : "Skill Group" }
    private var repositoryLabel: String { isChinese ? "仓库" : "Repository" }
    private var sourceRecordLabel: String { isChinese ? "来源记录" : "Source Record" }

    private func deleteTitle(for skill: Skill) -> String {
        isChinese ? "删除“\(skill.name)”？" : "Delete “\(skill.name)”?"
    }

    private func deleteMessage(for skill: Skill) -> String {
        let targetPath = store.deletionTargetPath(for: skill)
        if isChinese {
            return "此操作无法撤销。\n\nSkill 路径：\n\(skill.sourcePath)\n\n将删除：\n\(targetPath)"
        }
        return "This action cannot be undone.\n\nSkill path:\n\(skill.sourcePath)\n\nItem to delete:\n\(targetPath)"
    }

    private func localizedDeletionError(_ error: Error) -> String {
        guard let deletionError = error as? SkillDeletionError else {
            return error.localizedDescription
        }
        if isChinese {
            switch deletionError {
            case .readOnlySource:
                return "系统 Skill 和插件 Skill 由对应安装器管理，无法在这里删除。"
            case .sourceNotFound:
                return "Skill 路径已不存在，请刷新库后重试。"
            case .invalidSourcePath:
                return "所选项目没有指向有效的 SKILL.md 文件。"
            }
        }
        return deletionError.localizedDescription
    }
}

private enum SkillDetailAlert: Identifiable {
    case delete(Skill)
    case error(String)

    var id: String {
        switch self {
        case .delete(let skill): "delete-\(skill.id)"
        case .error(let message): "error-\(message)"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
