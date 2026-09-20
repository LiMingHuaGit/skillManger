import AppKit
import SwiftUI

enum NotchAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func title(locale: Locale) -> String {
        let isChinese = locale.identifier.lowercased().hasPrefix("zh")
        switch self {
        case .system: return isChinese ? "跟随系统" : "System"
        case .light: return isChinese ? "白天" : "Light"
        case .dark: return isChinese ? "黑夜" : "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }
}

struct NotchThemePalette {
    let colorScheme: ColorScheme

    private var isDark: Bool { colorScheme == .dark }

    var panelBackground: Color {
        isDark ? Color(red: 0.018, green: 0.018, blue: 0.022) : Color(white: 0.965)
    }

    var editorBackground: Color {
        isDark ? Color(red: 0.055, green: 0.055, blue: 0.065) : Color(white: 0.985)
    }

    var toolbarBackground: Color {
        isDark ? Color(red: 0.05, green: 0.05, blue: 0.06) : Color(white: 0.94)
    }

    var primaryText: Color { isDark ? .white.opacity(0.94) : .black.opacity(0.88) }
    var secondaryText: Color { isDark ? .white.opacity(0.62) : .black.opacity(0.58) }
    var tertiaryText: Color { isDark ? .white.opacity(0.38) : .black.opacity(0.40) }
    var subtleFill: Color { isDark ? .white.opacity(0.075) : .black.opacity(0.055) }
    var strongerFill: Color { isDark ? .white.opacity(0.11) : .black.opacity(0.085) }
    var border: Color { isDark ? .white.opacity(0.09) : .black.opacity(0.10) }
    var selectedFill: Color { isDark ? .white.opacity(0.92) : .black.opacity(0.84) }
    var selectedText: Color { isDark ? .black : .white }
    var shadow: Color { .black.opacity(isDark ? 0.22 : 0.13) }

    var editorBodyText: NSColor { isDark ? NSColor(white: 0.92, alpha: 1) : NSColor(white: 0.12, alpha: 1) }
    var editorMutedText: NSColor { isDark ? NSColor(white: 0.58, alpha: 1) : NSColor(white: 0.42, alpha: 1) }
    var editorDisabledText: NSColor { isDark ? NSColor(white: 0.38, alpha: 1) : NSColor(white: 0.62, alpha: 1) }
    var editorMarkerText: NSColor { isDark ? NSColor(white: 0.44, alpha: 1) : NSColor(white: 0.52, alpha: 1) }
}

private struct NotchThemeKey: EnvironmentKey {
    static let defaultValue = NotchThemePalette(colorScheme: .dark)
}

extension EnvironmentValues {
    var notchTheme: NotchThemePalette {
        get { self[NotchThemeKey.self] }
        set { self[NotchThemeKey.self] = newValue }
    }
}

struct NotchAppearanceMenuContent: View {
    @Environment(\.locale) private var locale
    @ObservedObject var settingsStore: NotchWorkspaceSettings

    private let opacityOptions = [0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00]

    var body: some View {
        Picker(
            locale.identifier.lowercased().hasPrefix("zh") ? "主题" : "Theme",
            selection: $settingsStore.appearanceMode
        ) {
            ForEach(NotchAppearanceMode.allCases) { mode in
                Label(mode.title(locale: locale), systemImage: mode.systemImage).tag(mode)
            }
        }

        Picker(
            locale.identifier.lowercased().hasPrefix("zh") ? "透明度" : "Opacity",
            selection: $settingsStore.panelOpacity
        ) {
            ForEach(opacityOptions, id: \.self) { opacity in
                Text("\(Int(opacity * 100))%").tag(opacity)
            }
        }
    }
}

struct NotchSettingsMenuContent: View {
    @Environment(\.locale) private var locale
    @ObservedObject var settingsStore: NotchWorkspaceSettings

    var body: some View {
        Picker(triggerTitle, selection: $settingsStore.triggerMode) {
            ForEach(NotchTriggerMode.allCases) { mode in
                Label(mode.title(locale: locale), systemImage: mode.systemImage).tag(mode)
            }
        }

        Divider()

        Picker(fileOperationTitle, selection: $settingsStore.shelfFileTransferMode) {
            ForEach(ShelfFileTransferMode.allCases) { mode in
                Label(mode.title(locale: locale), systemImage: mode.systemImage).tag(mode)
            }
        }

        Divider()

        Picker(shelfTitle, selection: $settingsStore.shelfDragCompletionBehavior) {
            ForEach(ShelfDragCompletionBehavior.allCases) { behavior in
                Text(behavior.title(locale: locale)).tag(behavior)
            }
        }

        Divider()

        NotchAppearanceMenuContent(settingsStore: settingsStore)
    }

    private var triggerTitle: String {
        locale.identifier.lowercased().hasPrefix("zh") ? "触发方式" : "Trigger"
    }

    private var fileOperationTitle: String {
        locale.identifier.lowercased().hasPrefix("zh") ? "文件操作" : "File operation"
    }

    private var shelfTitle: String {
        locale.identifier.lowercased().hasPrefix("zh") ? "暂存架" : "Shelf"
    }
}
