import Combine
import Foundation

enum NotchTriggerMode: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hover:
            return "Hover"
        case .click:
            return "Click"
        }
    }

    func title(locale: Locale) -> String {
        guard locale.identifier.lowercased().hasPrefix("zh") else { return title }
        switch self {
        case .hover: return "悬停"
        case .click: return "点击"
        }
    }

    var systemImage: String {
        switch self {
        case .hover:
            return "cursorarrow.motionlines"
        case .click:
            return "cursorarrow.click.2"
        }
    }
}

enum ShelfDragCompletionBehavior: String, CaseIterable, Identifiable {
    case keep
    case remove

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        let isChinese = locale.identifier.lowercased().hasPrefix("zh")
        switch self {
        case .keep:
            return isChinese ? "拖出后保留" : "Keep after drag"
        case .remove:
            return isChinese ? "拖出后自动移除" : "Remove after drag"
        }
    }
}

enum ShelfFileTransferMode: String, CaseIterable, Identifiable {
    case copy
    case move

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        let isChinese = locale.identifier.lowercased().hasPrefix("zh")
        switch self {
        case .copy:
            return isChinese ? "复制模式" : "Copy files"
        case .move:
            return isChinese ? "剪切模式" : "Move files"
        }
    }

    var systemImage: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .move: return "scissors"
        }
    }
}

@MainActor
final class NotchWorkspaceSettings: ObservableObject {
    @Published var triggerMode: NotchTriggerMode {
        didSet {
            defaults.set(triggerMode.rawValue, forKey: Self.triggerModeKey)
        }
    }
    @Published var shelfDragCompletionBehavior: ShelfDragCompletionBehavior {
        didSet {
            defaults.set(shelfDragCompletionBehavior.rawValue, forKey: Self.shelfDragCompletionBehaviorKey)
        }
    }
    @Published var shelfFileTransferMode: ShelfFileTransferMode {
        didSet {
            defaults.set(shelfFileTransferMode.rawValue, forKey: Self.shelfFileTransferModeKey)
        }
    }
    @Published var appearanceMode: NotchAppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: Self.appearanceModeKey)
        }
    }
    @Published var panelOpacity: Double {
        didSet {
            let clampedOpacity = Self.clampedPanelOpacity(panelOpacity)
            guard panelOpacity == clampedOpacity else {
                panelOpacity = clampedOpacity
                return
            }
            defaults.set(panelOpacity, forKey: Self.panelOpacityKey)
        }
    }
    @Published private(set) var preferredExpandedSize: CGSize?
    @Published private(set) var isKeepingAwake = false
    @Published private(set) var isChangingKeepAwake = false
    @Published private(set) var keepAwakeErrorMessage: String?

    private static let triggerModeKey = "skillManager.notch.triggerMode"
    private static let shelfDragCompletionBehaviorKey = "skillManager.shelf.dragCompletionBehavior"
    private static let shelfFileTransferModeKey = "skillManager.shelf.fileTransferMode"
    private static let appearanceModeKey = "skillManager.notch.appearanceMode"
    private static let panelOpacityKey = "skillManager.notch.panelOpacity"
    private static let expandedWidthKey = "skillManager.notch.expandedWidth"
    private static let expandedHeightKey = "skillManager.notch.expandedHeight"
    private static let ownsSleepDisabledKey = "skillManager.notch.ownsSleepDisabled"
    private static let completedSleepGuardMigrationKey = "skillManager.notch.completedSleepGuardRecoveryV1"
    private let defaults: UserDefaults
    private let systemSleepGuard: any SystemSleepGuardControlling
    private let sleepDisabledState: () -> Bool
    private let caffeinateLauncher: () -> Process?
    private var caffeinateProcess: Process?
    private var keepAwakeTask: Task<Void, Never>?
    private var needsSleepRecoveryAfterLaunch = false

    init(
        defaults: UserDefaults = .standard,
        systemSleepGuard: (any SystemSleepGuardControlling)? = nil,
        sleepDisabledState: (() -> Bool)? = nil,
        caffeinateLauncher: (() -> Process?)? = nil
    ) {
        self.defaults = defaults
        self.systemSleepGuard = systemSleepGuard ?? SystemSleepGuard()
        self.sleepDisabledState = sleepDisabledState ?? { SystemSleepGuard.isSleepDisabled() }
        self.caffeinateLauncher = caffeinateLauncher ?? Self.launchCaffeinate

        let rawMode = defaults.string(forKey: Self.triggerModeKey)
        triggerMode = rawMode.flatMap(NotchTriggerMode.init(rawValue:)) ?? .hover
        let rawShelfBehavior = defaults.string(forKey: Self.shelfDragCompletionBehaviorKey)
        shelfDragCompletionBehavior = rawShelfBehavior
            .flatMap(ShelfDragCompletionBehavior.init(rawValue:)) ?? .keep
        let rawTransferMode = defaults.string(forKey: Self.shelfFileTransferModeKey)
        shelfFileTransferMode = rawTransferMode
            .flatMap(ShelfFileTransferMode.init(rawValue:)) ?? .copy
        let rawAppearanceMode = defaults.string(forKey: Self.appearanceModeKey)
        appearanceMode = rawAppearanceMode
            .flatMap(NotchAppearanceMode.init(rawValue:)) ?? .system
        let savedOpacity = defaults.object(forKey: Self.panelOpacityKey) as? Double
        panelOpacity = Self.clampedPanelOpacity(savedOpacity ?? 1)

        let savedWidth = defaults.double(forKey: Self.expandedWidthKey)
        let savedHeight = defaults.double(forKey: Self.expandedHeightKey)
        preferredExpandedSize = savedWidth > 0 && savedHeight > 0
            ? CGSize(width: savedWidth, height: savedHeight)
            : nil

        let needsOwnedStateRecovery = defaults.bool(forKey: Self.ownsSleepDisabledKey)
        let needsLegacyRecovery = !defaults.bool(forKey: Self.completedSleepGuardMigrationKey)
            && self.sleepDisabledState()

        if needsOwnedStateRecovery || needsLegacyRecovery {
            isKeepingAwake = self.sleepDisabledState()
            needsSleepRecoveryAfterLaunch = true
        } else {
            defaults.set(true, forKey: Self.completedSleepGuardMigrationKey)
            defaults.set(false, forKey: Self.ownsSleepDisabledKey)
        }
    }

    func recoverSleepAfterLaunchIfNeeded() {
        guard needsSleepRecoveryAfterLaunch, keepAwakeTask == nil else { return }

        needsSleepRecoveryAfterLaunch = false
        isChangingKeepAwake = true
        keepAwakeTask = Task { [weak self] in
            await self?.recoverSleepAfterUnexpectedExit()
        }
    }

    func toggleKeepAwake() {
        guard !isChangingKeepAwake else { return }

        if isKeepingAwake {
            stopKeepingAwake()
        } else {
            requestKeepAwake()
        }
    }

    func stopKeepingAwake() {
        keepAwakeTask?.cancel()
        keepAwakeTask = nil
        systemSleepGuard.requestStop()
        isChangingKeepAwake = true

        let process = caffeinateProcess
        caffeinateProcess = nil

        if let process, process.isRunning {
            process.terminate()
        }

        keepAwakeTask = Task { [weak self] in
            guard let self else { return }
            let didStop = await self.systemSleepGuard.resetSleepIfNeeded()
            guard !Task.isCancelled else { return }

            let remainsDisabled = !didStop && self.sleepDisabledState()
            self.setOwnsSleepDisabled(remainsDisabled)
            self.isKeepingAwake = remainsDisabled
            self.isChangingKeepAwake = false
            if !didStop {
                self.keepAwakeErrorMessage = "Administrator permission is required to restore normal sleep."
            }
            self.keepAwakeTask = nil
        }
    }

    func dismissKeepAwakeError() {
        keepAwakeErrorMessage = nil
    }

    func saveExpandedSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        preferredExpandedSize = size
        defaults.set(size.width, forKey: Self.expandedWidthKey)
        defaults.set(size.height, forKey: Self.expandedHeightKey)
    }

    private static func clampedPanelOpacity(_ opacity: Double) -> Double {
        min(max(opacity, 0.60), 1)
    }

    private func requestKeepAwake() {
        guard caffeinateProcess == nil, !systemSleepGuard.isRunning else { return }

        isChangingKeepAwake = true
        keepAwakeErrorMessage = nil

        do {
            try systemSleepGuard.start()
        } catch {
            setOwnsSleepDisabled(false)
            isChangingKeepAwake = false
            keepAwakeErrorMessage = "The macOS authorization prompt couldn’t open. Please try again."
            return
        }

        keepAwakeTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.systemSleepGuard.waitUntilReady()
            } catch is CancellationError {
                return
            } catch {
                let didReset = await self.systemSleepGuard.resetSleepIfNeeded()
                let remainsDisabled = !didReset && self.sleepDisabledState()
                self.setOwnsSleepDisabled(remainsDisabled)
                self.isKeepingAwake = remainsDisabled
                self.isChangingKeepAwake = false
                if let sleepGuardError = error as? SystemSleepGuardError {
                    self.keepAwakeErrorMessage = sleepGuardError.userMessage
                } else {
                    self.keepAwakeErrorMessage = "The keep-awake helper couldn’t start. Please try again."
                }
                self.keepAwakeTask = nil
                return
            }

            guard !Task.isCancelled else { return }

            self.setOwnsSleepDisabled(true)

            guard self.startCaffeinate() else {
                let didReset = await self.systemSleepGuard.resetSleepIfNeeded()
                let remainsDisabled = !didReset && self.sleepDisabledState()
                self.setOwnsSleepDisabled(remainsDisabled)
                self.isKeepingAwake = remainsDisabled
                self.isChangingKeepAwake = false
                self.keepAwakeErrorMessage = "macOS enabled closed-lid mode, but the idle-sleep helper couldn’t start."
                self.keepAwakeTask = nil
                return
            }

            self.isKeepingAwake = true
            self.isChangingKeepAwake = false
            self.keepAwakeTask = nil
        }
    }

    private func startCaffeinate() -> Bool {
        guard caffeinateProcess == nil else { return true }

        guard let process = caffeinateLauncher() else {
            return false
        }

        caffeinateProcess = process
        return true
    }

    nonisolated private static func launchCaffeinate() -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = [
            "-dims",
            "-w",
            String(ProcessInfo.processInfo.processIdentifier)
        ]

        do {
            try process.run()
            return process
        } catch {
            return nil
        }
    }

    private func recoverSleepAfterUnexpectedExit() async {
        let didReset = await systemSleepGuard.resetSleepIfNeeded()
        guard !Task.isCancelled else { return }

        let remainsDisabled = !didReset && sleepDisabledState()
        setOwnsSleepDisabled(remainsDisabled)
        if didReset {
            defaults.set(true, forKey: Self.completedSleepGuardMigrationKey)
        }
        isKeepingAwake = remainsDisabled
        isChangingKeepAwake = false
        if !didReset {
            keepAwakeErrorMessage = "Administrator permission is required to restore normal sleep."
        }
        keepAwakeTask = nil
    }

    private func setOwnsSleepDisabled(_ ownsSleepDisabled: Bool) {
        defaults.set(ownsSleepDisabled, forKey: Self.ownsSleepDisabledKey)
    }
}
