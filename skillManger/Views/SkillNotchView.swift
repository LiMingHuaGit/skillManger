//
//  SkillNotchView.swift
//  skillManger
//
//  Created by Codex on 2026/8/24.
//

import AppKit
import SwiftUI

private enum NotchSkillScope: String, CaseIterable, Identifiable {
    case all
    case standalone
    case plugin

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        switch self {
        case .all: L10n.string("All", locale: locale)
        case .standalone: L10n.string("Standalone Skills", locale: locale)
        case .plugin: L10n.string("Plugin Skills", locale: locale)
        }
    }
}

struct SkillNotchView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: SkillLibraryStore
    @ObservedObject var languageSettings: AppLanguageSettings
    @ObservedObject var notchState: SkillNotchState

    let openLibrary: () -> Void
    let refresh: () -> Void

    @State private var scope: NotchSkillScope = .all
    @State private var searchText = ""
    @State private var collapseTask: Task<Void, Never>?
    @State private var toast: String?
    @FocusState private var isSearchFocused: Bool

    private let openAnimation = Animation.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0)

    var body: some View {
        ZStack(alignment: .top) {
            notchSurface
        }
        .frame(
            width: SkillNotchState.Layout.windowSize.width,
            height: SkillNotchState.Layout.windowSize.height,
            alignment: .top
        )
        .preferredColorScheme(.dark)
        .environment(\.locale, languageSettings.locale)
        .animation(openAnimation, value: notchState.isExpanded)
        .onChange(of: searchText) { _, _ in
            updateInteractionPin()
        }
        .onDisappear {
            notchState.setInteractionPinned(false)
        }
    }

    private var notchSurface: some View {
        VStack(spacing: 0) {
            if notchState.isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .frame(width: notchState.currentSize.width, height: notchState.currentSize.height, alignment: .top)
        .background(.black, in: SkillNotchShape(topCornerRadius: 7, bottomCornerRadius: notchState.isExpanded ? 28 : 18))
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.black)
                .frame(height: 1)
                .padding(.horizontal, 7)
        }
        .overlay {
            SkillNotchShape(topCornerRadius: 7, bottomCornerRadius: notchState.isExpanded ? 28 : 18)
                .stroke(.white.opacity(notchState.isExpanded ? 0.10 : 0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(notchState.isExpanded ? 0.50 : 0.20), radius: notchState.isExpanded ? 20 : 8, y: notchState.isExpanded ? 10 : 3)
        .onHover(perform: handleHover)
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
        VStack(alignment: .leading, spacing: 14) {
            header
            searchAndScope

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
                VStack(spacing: 8) {
                    ForEach(filteredSkills.prefix(5)) { skill in
                        NotchSkillRow(
                            skill: skill,
                            isFavorite: store.favoriteSkillIDs.contains(skill.id),
                            copyAction: { copy(skill) }
                        )
                    }
                }
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("Skill Quick Access", locale: locale))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
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

            Button(action: openLibrary) {
                Image(systemName: "rectangle.grid.2x2")
            }
            .help(L10n.string("Open Library", locale: locale))

            Button(action: { notchState.collapse() }) {
                Image(systemName: "chevron.up")
            }
            .help(L10n.string("Collapse", locale: locale))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.72))
    }

    private var searchAndScope: some View {
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

            Picker("", selection: $scope) {
                ForEach(NotchSkillScope.allCases) { scope in
                    Text(scope.title(locale: locale)).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
    }

    private var summaryText: String {
        L10n.format(
            "%d skills, %d plugin skills",
            locale: locale,
            store.standaloneSkills.count,
            store.pluginSkills.count
        )
    }

    private var scopedSkills: [Skill] {
        switch scope {
        case .all: store.visibleSkills
        case .standalone: store.standaloneSkills
        case .plugin: store.pluginSkills
        }
    }

    private var filteredSkills: [Skill] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return scopedSkills }

        return scopedSkills.filter { skill in
            ([skill.name, skill.description, skill.sourcePath] + skill.tags)
                .contains { $0.lowercased().contains(query) }
        }
    }

    private func handleHover(_ hovering: Bool) {
        collapseTask?.cancel()

        if hovering {
            notchState.expand()
        } else {
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                notchState.collapse()
            }
        }
    }

    private func updateInteractionPin() {
        notchState.setInteractionPinned(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
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

            Text(skill.sourceType == .plugin ? L10n.string("Plugin", locale: locale) : L10n.string("Skill", locale: locale))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.white.opacity(0.10), in: Capsule())

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
        openLibrary: {},
        refresh: {}
    )
}
