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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(package.name, systemImage: "puzzlepiece.extension")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(skillCountText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(package.marketplaceID)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.45), in: Capsule())

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
        .padding(.vertical, 6)
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
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
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
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(package.name)
                    .font(.largeTitle.weight(.semibold))
                Text(package.displayName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(package.marketplaceID)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.45), in: Capsule())

                    if let version = package.version {
                        Text(version)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
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

                if let toast = store.toastMessage {
                    Text(toast)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metadataPanel(for package: PluginPackage) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow { Text(L10n.string("Marketplace", locale: locale)).foregroundStyle(.secondary); Text(package.marketplaceID).textSelection(.enabled) }
            GridRow { Text(L10n.string("Version", locale: locale)).foregroundStyle(.secondary); Text(package.version ?? "-").textSelection(.enabled) }
            GridRow { Text(L10n.string("Skills", locale: locale)).foregroundStyle(.secondary); Text("\(package.skillCount)") }
            GridRow { Text(L10n.string("Plugin root", locale: locale)).foregroundStyle(.secondary); Text(package.rootPath).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
        }
        .font(.callout)
    }

    private func skillsPanel(for package: PluginPackage) -> some View {
        let skills = store.skills(forPluginID: package.id)

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("Skills in this plugin", locale: locale))
                .font(.headline)

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
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
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
