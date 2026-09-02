//
//  SharedViews.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import SwiftUI

enum SkillManagerTheme {
    static let accent = Color(red: 0.08, green: 0.48, blue: 0.45)
    static let accentSoft = accent.opacity(0.12)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevatedSurface = Color(nsColor: .textBackgroundColor)
    static let subtleBorder = Color.primary.opacity(0.08)
    static let quietFill = Color.primary.opacity(0.055)
    static let selectionFill = accent.opacity(0.13)

    static let panelRadius: CGFloat = 8
    static let controlRadius: CGFloat = 7

    static var responsiveSpring: Animation {
        .spring(response: 0.32, dampingFraction: 0.86)
    }
}

private struct PanelSurfaceModifier: ViewModifier {
    let emphasized: Bool

    func body(content: Content) -> some View {
        content
            .background(
                emphasized ? SkillManagerTheme.elevatedSurface : SkillManagerTheme.surface,
                in: RoundedRectangle(cornerRadius: SkillManagerTheme.panelRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: SkillManagerTheme.panelRadius, style: .continuous)
                    .stroke(SkillManagerTheme.subtleBorder, lineWidth: 1)
            }
    }
}

extension View {
    func panelSurface(emphasized: Bool = false) -> some View {
        modifier(PanelSurfaceModifier(emphasized: emphasized))
    }
}

struct PanelSectionTitle: View {
    let title: String
    let systemImage: String
    var detail: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SkillManagerTheme.accent)
                .frame(width: 20, height: 20)

            Text(title)
                .font(.headline)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SourceBadge: View {
    @Environment(\.locale) private var locale
    let sourceType: SkillSourceType

    var body: some View {
        Text(L10n.string(sourceType.localizationKey, locale: locale))
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(sourceColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(sourceColor.opacity(0.11), in: Capsule())
            .accessibilityLabel(L10n.format("Source: %@", locale: locale, L10n.string(sourceType.localizationKey, locale: locale)))
    }

    private var sourceColor: Color {
        switch sourceType {
        case .local: SkillManagerTheme.accent
        case .system: Color.orange
        case .plugin: Color.indigo
        case .project: Color.blue
        }
    }
}

struct HealthBadge: View {
    @Environment(\.locale) private var locale
    let status: SkillHealthStatus

    var body: some View {
        Label(L10n.string(status.localizationKey, locale: locale), systemImage: status == .healthy ? "checkmark.circle" : "exclamationmark.triangle")
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(status == .healthy ? Color.secondary : Color.orange)
            .accessibilityLabel(L10n.format("Health: %@", locale: locale, L10n.string(status.localizationKey, locale: locale)))
    }
}

struct OriginBadge: View {
    @Environment(\.locale) private var locale
    let origin: SkillOrigin
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: origin.systemImage)
            Text(compact ? origin.compactTitle(locale: locale) : origin.title(locale: locale))
        }
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(origin == .official ? SkillManagerTheme.accent : Color.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background((origin == .official ? SkillManagerTheme.accent : Color.secondary).opacity(0.09), in: Capsule())
            .help(origin.title(locale: locale))
            .accessibilityLabel(origin.title(locale: locale))
    }
}

struct CategoryBadge: View {
    @Environment(\.locale) private var locale
    let category: SkillCategory
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
            Text(compact ? category.compactTitle(locale: locale) : category.title(locale: locale))
        }
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(SkillManagerTheme.quietFill, in: Capsule())
            .help(category.title(locale: locale))
            .accessibilityLabel(category.title(locale: locale))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
    }
}

struct SkillRowView: View {
    let skill: Skill
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(skill.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel(String(localized: "Favorite"))
                }
                Spacer(minLength: 8)
                SourceBadge(sourceType: skill.sourceType)
            }

            Text(skill.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                HealthBadge(status: skill.healthStatus)
                OriginBadge(origin: skill.origin, compact: true)
                CategoryBadge(category: skill.category, compact: true)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct RecommendedSkillRowView: View {
    @Environment(\.locale) private var locale
    let recommendation: SkillRecommendation
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(recommendation.skill.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel(String(localized: "Favorite"))
                }
                Spacer(minLength: 8)
                Label("\(Int(recommendation.score.rounded()))", systemImage: "sparkles")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SkillManagerTheme.accent)
                SourceBadge(sourceType: recommendation.skill.sourceType)
            }

            Text(recommendation.skill.description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                OriginBadge(origin: recommendation.skill.origin, compact: true)
                CategoryBadge(category: recommendation.skill.category, compact: true)
                Text(L10n.string("Matched", locale: locale))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(recommendation.reason.isEmpty ? L10n.string("Context terms", locale: locale) : recommendation.reason)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct CodexSessionTitleView: View {
    let session: CodexSessionContext
    var font: Font = .caption.weight(.semibold)
    var iconSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: iconSize, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(SkillManagerTheme.accent)

            Text(session.displayTitle)
                .font(font)
                .foregroundStyle(SkillManagerTheme.accent)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityLabel(Text(verbatim: "Codex \(session.displayTitle)"))
    }
}
