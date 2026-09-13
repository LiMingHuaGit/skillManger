import Combine
import Foundation

enum NotchWorkspaceSection: String, CaseIterable, Identifiable {
    case skills
    case notes
    case shelf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skills: return "Skills"
        case .notes: return "Notes"
        case .shelf: return "Shelf"
        }
    }

    func title(locale: Locale) -> String {
        guard locale.identifier.lowercased().hasPrefix("zh") else { return title }
        switch self {
        case .skills: return "技能"
        case .notes: return "笔记"
        case .shelf: return "暂存架"
        }
    }

    var systemImage: String {
        switch self {
        case .skills: "sparkles"
        case .notes: "note.text"
        case .shelf: "tray.full"
        }
    }
}

@MainActor
final class NotchWorkspaceNavigation: ObservableObject {
    @Published var selection: NotchWorkspaceSection = .skills
}
