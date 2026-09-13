//
//  SkillNotchView.swift
//  skillManger
//
//  Created by Codex on 2026/8/24.
//

import AppKit
import SwiftUI

struct SkillNotchView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var languageSettings: AppLanguageSettings
    @ObservedObject var notchState: SkillNotchState
    @ObservedObject var navigation: NotchWorkspaceNavigation
    @ObservedObject var noteStore: NoteStore
    @ObservedObject var notchSettings: NotchWorkspaceSettings
    let imageStore: LocalImageStore
    @ObservedObject var fileShelfStore: FileShelfStore
    @ObservedObject var notebookWorkspaceState: NotebookWorkspaceState
    let editorInteractionState: EditorInteractionState

    let openLibrary: () -> Void
    let refresh: () -> Void
    let collapsePanel: () -> Void
    let resizePanel: (CGSize, Bool) -> Void

    @State private var searchText = ""
    @State private var toast: String?
    @FocusState private var isSearchFocused: Bool

    private let openAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0)

    var body: some View {
        ZStack(alignment: .top) {
            notchSurface
        }
        .frame(
            width: notchState.windowSize.width,
            height: notchState.windowSize.height,
            alignment: .top
        )
        .preferredColorScheme(.dark)
        .environment(\.locale, languageSettings.locale)
        .animation(openAnimation, value: notchState.isExpanded)
    }

    private var notchSurface: some View {
        let shape = SkillNotchShape(topCornerRadius: 7, bottomCornerRadius: notchState.isExpanded ? 28 : 18)

        return VStack(spacing: 0) {
            if notchState.isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .frame(width: notchState.currentSize.width, height: notchState.currentSize.height, alignment: .top)
        .clipShape(shape)
        .background {
            shape
                .fill(.black)
                .shadow(
                    color: .black.opacity(notchState.isExpanded ? 0.20 : 0.14),
                    radius: notchState.isExpanded ? 26 : 7,
                    y: notchState.isExpanded ? 12 : 3
                )
                .shadow(
                    color: .black.opacity(notchState.isExpanded ? 0.10 : 0.06),
                    radius: notchState.isExpanded ? 9 : 3,
                    y: notchState.isExpanded ? 4 : 1
                )
        }
        .contentShape(shape)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, 7)
        }
        .overlay {
            shape.stroke(.white.opacity(notchState.isExpanded ? 0.10 : 0.06), lineWidth: 1)
        }
        .onTapGesture {
            if notchState.isExpanded == false {
                notchState.expand()
            }
        }
    }

    private var collapsedContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(L10n.string("Skill Quick Access", locale: locale))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            Text("\(store.skills.count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.86), in: Capsule())
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            workspacePicker

            Group {
                switch navigation.selection {
                case .skills:
                    skillsWorkspace
                case .notes:
                    NotchNotebookPane(
                        store: noteStore,
                        settingsStore: notchSettings,
                        imageStore: imageStore,
                        fileShelfStore: fileShelfStore,
                        workspaceState: notebookWorkspaceState,
                        editorInteractionState: editorInteractionState,
                        panelSize: notchState.openSize,
                        resizePanel: resizePanel
                    )
                case .shelf:
                    NotchFileShelfPane(
                        store: fileShelfStore,
                        workspaceState: notebookWorkspaceState,
                        settingsStore: notchSettings
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var skillsWorkspace: some View {
        VStack(spacing: 12) {
            searchBar

            if filteredSkills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.35))
                    Text(L10n.string("No matching skills", locale: locale))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                skillResults
            }
        }
    }

    private var skillResults: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 8) {
                ForEach(filteredSkills) { skill in
                    NotchSkillRow(
                        skill: skill,
                        isFavorite: store.favoriteSkillIDs.contains(skill.id),
                        recommendation: store.recommendation(for: skill.id),
                        copyAction: { copy(skill) }
                    )
                }
            }
            .padding(.bottom, 2)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(navigation.selection == .skills
                     ? L10n.string("Skill Quick Access", locale: locale)
                     : navigation.selection.title(locale: locale))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                workspaceSummary
            }

            Spacer()

            if let toast {
                Text(toast)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green.opacity(0.9))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
            }
            .help(L10n.string("Re-index", locale: locale))
            .opacity(navigation.selection == .skills ? 1 : 0)
            .disabled(navigation.selection != .skills)

            Menu {
                Picker("Trigger", selection: $notchSettings.triggerMode) {
                    ForEach(NotchTriggerMode.allCases) { mode in
                        Label(mode.title(locale: locale), systemImage: mode.systemImage).tag(mode)
                    }
                }

                Divider()

                Picker("Shelf", selection: $notchSettings.shelfDragCompletionBehavior) {
                    ForEach(ShelfDragCompletionBehavior.allCases) { behavior in
                        Text(behavior.title(locale: locale)).tag(behavior)
                    }
                }
            } label: {
                Image(systemName: notchSettings.triggerMode.systemImage)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help(notchTriggerHelp)

            Button {
                notchSettings.toggleKeepAwake()
            } label: {
                Image(systemName: notchSettings.isKeepingAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
            }
            .disabled(notchSettings.isChangingKeepAwake)
            .help(notchSettings.isKeepingAwake ? "Stop keeping Mac awake" : "Keep Mac awake")

            Button(action: openLibrary) {
                Image(systemName: "rectangle.grid.2x2")
            }
            .help(L10n.string("Open Library", locale: locale))

            Button(action: collapsePanel) {
                Image(systemName: "chevron.up")
            }
            .help(L10n.string("Collapse", locale: locale))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.72))
        .alert(
            "Couldn’t Keep Mac Awake",
            isPresented: Binding(
                get: { notchSettings.keepAwakeErrorMessage != nil },
                set: { if !$0 { notchSettings.dismissKeepAwakeError() } }
            )
        ) {
            Button("OK") { notchSettings.dismissKeepAwakeError() }
        } message: {
            Text(notchSettings.keepAwakeErrorMessage ?? "")
        }
    }

    private var workspacePicker: some View {
        HStack(spacing: 4) {
            ForEach(NotchWorkspaceSection.allCases) { section in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        navigation.selection = section
                    }
                } label: {
                    Label(section.title(locale: locale), systemImage: section.systemImage)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(navigation.selection == section ? Color.black : Color.white.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(navigation.selection == section ? Color.white.opacity(0.92) : Color.clear)
                )
            }
        }
        .padding(3)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.45))
                TextField(L10n.string("Search name, tag, use case, or path", locale: locale), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Label(L10n.string("Recommended", locale: locale), systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor, in: Capsule())
        }
    }

    @ViewBuilder
    private var summaryView: some View {
        if let session = store.selectedCodexSession {
            HStack(spacing: 6) {
                CodexSessionTitleView(session: session, font: .caption.weight(.semibold), iconSize: 10)
                Text(verbatim: "·")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                Text(L10n.format("%d recommended skills", locale: locale, store.skillRecommendations.count))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
            }
            .lineLimit(1)
            .frame(maxWidth: 440, alignment: .leading)
        } else {
            Text(librarySummary)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.52))
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var workspaceSummary: some View {
        switch navigation.selection {
        case .skills:
            summaryView
        case .notes:
            Text(locale.identifier.lowercased().hasPrefix("zh")
                 ? "\(noteStore.tabs.count) 个标签页 · \(noteStore.title(for: noteStore.activeTabID))"
                 : "\(noteStore.tabs.count) tabs · \(noteStore.title(for: noteStore.activeTabID))")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
        case .shelf:
            Text(locale.identifier.lowercased().hasPrefix("zh")
                 ? "\(fileShelfStore.items.count) 个暂存文件"
                 : "\(fileShelfStore.items.count) shelf items")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    private var notchTriggerHelp: String {
        if locale.identifier.lowercased().hasPrefix("zh") {
            return "通过\(notchSettings.triggerMode.title(locale: locale))打开"
        }
        return "Open by \(notchSettings.triggerMode.title.lowercased())"
    }

    private var librarySummary: String {
        let skillCount = store.standaloneSkills.count
        let pluginCount = store.pluginPackages.count
        if locale.identifier.lowercased().hasPrefix("zh") {
            return "\(skillCount) 个技能，\(pluginCount) 个插件"
        }
        return "\(skillCount) skills, \(pluginCount) plugins"
    }

    private var filteredSkills: [Skill] {
        store.searchResults(in: store.recommendationRankedSkills, query: searchText)
    }

    private func copy(_ skill: Skill) {
        let template = skill.sourceType == .plugin ? PlatformTemplate.codexPluginSkill : store.defaultTemplate
        do {
            let text = try store.copyText(for: skill, template: template, useCase: skill.description)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            toast = L10n.format("Copied for %@", locale: locale, template.platformName)
        } catch {
            toast = L10n.format("Copy failed: %@", locale: locale, error.localizedDescription)
        }
    }
}

private struct NotchSkillRow: View {
    @Environment(\.locale) private var locale
    let skill: Skill
    let isFavorite: Bool
    let recommendation: SkillRecommendation?
    let copyAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if recommendation != nil {
                Label(L10n.string("Recommended", locale: locale), systemImage: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.90), in: Capsule())
            }

            Label(skill.origin.title(locale: locale), systemImage: skill.origin.systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(skill.origin == .selfCreated ? Color.cyan : Color.white.opacity(0.62))
                .labelStyle(.iconOnly)
                .padding(6)
                .background(.white.opacity(0.10), in: Circle())
                .help(skill.origin.title(locale: locale))

            Label(skill.category.title(locale: locale), systemImage: skill.category.systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.66))
                .labelStyle(.iconOnly)
                .padding(6)
                .background(.white.opacity(0.10), in: Circle())
                .help(skill.category.title(locale: locale))

            Button(action: copyAction) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.82))
            .help(L10n.string("Copy prompt", locale: locale))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

struct SkillCompactNotchView: View {
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var settings: NotchWorkspaceSettings
    let size: CGSize
    let onExpand: () -> Void
    let onDropFiles: ([URL]) -> Bool

    var body: some View {
        Color.clear
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture(perform: onExpand)
        .dropDestination(for: URL.self) { urls, _ in
            _ = onDropFiles(urls)
        }
    }
}

struct SkillNotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    SkillNotchView(
        store: SkillLibraryStore(initialSkills: []),
        languageSettings: AppLanguageSettings(),
        notchState: SkillNotchState(),
        navigation: NotchWorkspaceNavigation(),
        noteStore: NoteStore(),
        notchSettings: NotchWorkspaceSettings(),
        imageStore: LocalImageStore(),
        fileShelfStore: FileShelfStore(),
        notebookWorkspaceState: NotebookWorkspaceState(),
        editorInteractionState: EditorInteractionState(),
        openLibrary: {},
        refresh: {},
        collapsePanel: {},
        resizePanel: { _, _ in }
    )
}
