//
//  SharedViews.swift
//  skillManger
//
//  Created by Codex on 2026/7/14.
//

import SwiftUI

struct SourceBadge: View {
    @Environment(\.locale) private var locale
    let sourceType: SkillSourceType

    var body: some View {
        Text(L10n.string(sourceType.localizationKey, locale: locale))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(sourceColor.opacity(0.55), in: Capsule())
            .accessibilityLabel(L10n.format("Source: %@", locale: locale, L10n.string(sourceType.localizationKey, locale: locale)))
    }

    private var sourceColor: Color {
        switch sourceType {
        case .local: Color(red: 0.86, green: 0.93, blue: 0.69)
        case .system: Color(red: 0.95, green: 0.79, blue: 0.71)
        case .plugin: Color(red: 0.77, green: 0.69, blue: 0.96)
        case .project: Color(red: 0.78, green: 0.90, blue: 0.80)
        }
    }
}

struct HealthBadge: View {
    @Environment(\.locale) private var locale
    let status: SkillHealthStatus

    var body: some View {
        Label(L10n.string(status.localizationKey, locale: locale), systemImage: status == .healthy ? "checkmark.circle" : "exclamationmark.triangle")
            .font(.caption.weight(.medium))
            .foregroundStyle(status == .healthy ? Color.secondary : Color.orange)
            .accessibilityLabel(L10n.format("Health: %@", locale: locale, L10n.string(status.localizationKey, locale: locale)))
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SkillRowView: View {
    let skill: Skill
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(skill.name)
                    .font(.headline)
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                HealthBadge(status: skill.healthStatus)
                Spacer()
                Text(skill.sourcePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct RecommendedSkillRowView: View {
    @Environment(\.locale) private var locale
    let recommendation: SkillRecommendation
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(recommendation.skill.name)
                    .font(.headline)
                    .lineLimit(1)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel(String(localized: "Favorite"))
                }
                Spacer(minLength: 8)
                Label("\(Int(recommendation.score.rounded()))", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                SourceBadge(sourceType: recommendation.skill.sourceType)
            }

            Text(recommendation.skill.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
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
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
