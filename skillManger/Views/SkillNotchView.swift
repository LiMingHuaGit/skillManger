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

    let openLibrary: () -> Void
    let refresh: () -> Void

    @State private var searchText = ""
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
                    color: .black.opacity(notchState.isExpanded ? 0.42 : 0.18),
                    radius: notchState.isExpanded ? 18 : 7,
                    y: notchState.isExpanded ? 9 : 3
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
        VStack(alignment: .leading, spacing: 14) {
            header
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
        .padding(.top, 16)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
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
                Text(L10n.string("Skill Quick Access", locale: locale))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                summaryView
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

    private var librarySummary: String {
        let skillCount = store.standaloneSkills.count
        let pluginCount = store.pluginPackages.count
        if locale.identifier.lowercased().hasPrefix("zh") {
            return "\(skillCount) 个技能，\(pluginCount) 个插件"
        }
        return "\(skillCount) skills, \(pluginCount) plugins"
    }

    private var filteredSkills: [Skill] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return store.recommendationRankedSkills }

        return store.recommendationRankedSkills.filter { skill in
            ([skill.name, skill.description, skill.sourcePath] + skill.tags + SkillClassifier.searchTerms(for: skill))
                .contains { $0.lowercased().contains(query) }
        }
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
                .foregroundStyle(skill.origin == .official ? Color.cyan : Color.white.opacity(0.62))
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
