//
//  PluginViews.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import AppKit
import SwiftUI

struct PluginRowView: View {
    @Environment(\.locale) private var locale
    let package: PluginPackage

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .foregroundStyle(SkillManagerTheme.accent)
                    Text(package.name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(skillCountText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(package.marketplaceID)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(SkillManagerTheme.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(SkillManagerTheme.accentSoft, in: Capsule())

                if let version = package.version {
                    Text(version)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Text(package.rootPath)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var skillCountText: String {
        "\(package.skillCount) \(L10n.string("Skills", locale: locale))"
    }
}

struct PluginDetailView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: SkillLibraryStore
    let package: PluginPackage?

    var body: some View {
        Group {
            if let package {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(for: package)
                        metadataPanel(for: package)
                        skillsPanel(for: package)
                    }
                    .padding(28)
                    .frame(maxWidth: 920, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .background(SkillManagerTheme.canvas)
                .navigationTitle(package.name)
            } else {
                EmptyStateView(
                    title: L10n.string("Select a plugin", locale: locale),
                    message: L10n.string("Choose a plugin package to see its root and included skills.", locale: locale),
                    systemImage: "puzzlepiece.extension"
                )
            }
        }
    }

    private func header(for package: PluginPackage) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(SkillManagerTheme.accent)
                .frame(width: 44, height: 44)
                .background(SkillManagerTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(package.name)
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(package.displayName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(package.marketplaceID)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SkillManagerTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(SkillManagerTheme.accentSoft, in: Capsule())

                    if let version = package.version {
                        Text(version)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    copyToPasteboard(package.rootPath)
                    store.toastMessage = L10n.string("Plugin root copied", locale: locale)
                } label: {
                    Label(L10n.string("Copy plugin root", locale: locale), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    revealInFinder(package.rootPath)
                } label: {
                    Label(L10n.string("Reveal in Finder", locale: locale), systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func metadataPanel(for package: PluginPackage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelSectionTitle(title: pluginDetailsTitle, systemImage: "info.circle")
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow { Text(L10n.string("Marketplace", locale: locale)).foregroundStyle(.secondary); Text(package.marketplaceID).textSelection(.enabled) }
                GridRow { Text(L10n.string("Version", locale: locale)).foregroundStyle(.secondary); Text(package.version ?? "-").textSelection(.enabled) }
                GridRow { Text(L10n.string("Skills", locale: locale)).foregroundStyle(.secondary); Text("\(package.skillCount)") }
                GridRow { Text(L10n.string("Plugin root", locale: locale)).foregroundStyle(.secondary); Text(package.rootPath).font(.system(.callout, design: .monospaced)).textSelection(.enabled) }
            }
            .font(.callout)

            if let toast = store.toastMessage {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(SkillManagerTheme.accent)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 2)
    }

    private var pluginDetailsTitle: String {
        locale.identifier.lowercased().hasPrefix("zh") ? "插件详情" : "Plugin details"
    }

    private func skillsPanel(for package: PluginPackage) -> some View {
        let skills = store.skills(forPluginID: package.id)

        return VStack(alignment: .leading, spacing: 12) {
            PanelSectionTitle(
                title: L10n.string("Skills in this plugin", locale: locale),
                systemImage: "square.stack.3d.up",
                detail: "\(skills.count)"
            )

            VStack(alignment: .leading, spacing: 0) {
                ForEach(skills) { skill in
                    PluginSkillSummaryRow(skill: skill) {
                        copyToPasteboard(skill.referencePath)
                        store.toastMessage = L10n.string("Source path copied", locale: locale)
                    }

                    if skill.id != skills.last?.id {
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

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func revealInFinder(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

private struct PluginSkillSummaryRow: View {
    let skill: Skill
    let copySource: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(skill.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(skill.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(skill.sourcePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Button(action: copySource) {
                Label("Copy source", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}
