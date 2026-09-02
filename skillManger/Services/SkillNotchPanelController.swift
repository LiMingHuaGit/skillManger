//
//  SkillNotchPanelController.swift
//  skillManger
//
//  Created by Codex on 2026/8/24.
//

import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class SkillNotchState: ObservableObject {
    enum Layout {
        static let fallbackClosedSize = CGSize(width: 286, height: 38)
        static let openSize = CGSize(width: 720, height: 382)
        static let shadowPadding: CGFloat = 24
        static let windowSize = CGSize(width: openSize.width, height: openSize.height + shadowPadding)
    }

    @Published var isExpanded = false
    @Published private(set) var closedSize = Layout.fallbackClosedSize

    var currentSize: CGSize {
        isExpanded ? Self.Layout.openSize : closedSize
    }

    func updateClosedSize(_ size: CGSize) {
        guard closedSize != size else { return }
        closedSize = size
    }

    func expand() {
        isExpanded = true
    }

    func collapse() {
        isExpanded = false
    }

    func toggle() {
        isExpanded.toggle()
    }
}

@MainActor
final class SkillNotchPanelController: NSObject, NSWindowDelegate {
    static let shared = SkillNotchPanelController(appState: .shared)
    private static let libraryWindowAutosaveName = "SkillManager.LibraryWindow"

    private let appState: SkillManagerAppState
    private let notchState = SkillNotchState()
    private var notchWindow: SkillNotchPanel?
    private var libraryWindowController: NSWindowController?
    private var activeScreen: NSScreen?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var expandTask: Task<Void, Never>?
    private var collapseTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    private enum HoverBehavior {
        static let expandDelay: Duration = .milliseconds(1_000)
        static let collapseDelay: Duration = .milliseconds(150)
        static let closedTriggerPadding: CGFloat = 3
        static let expandedExitPadding: CGFloat = 8
    }

    init(appState: SkillManagerAppState) {
        self.appState = appState
        super.init()

        notchState.$isExpanded
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateNotchFrame(animated: true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.activeScreen = self?.targetScreen()
                self?.updateNotchFrame(animated: false)
            }
        }
    }

    deinit {
        expandTask?.cancel()
        collapseTask?.cancel()
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
    }

    func showNotch() {
        appState.refreshIfNeeded()
        let screen = activeScreen ?? targetScreen()
        activeScreen = screen
        notchState.updateClosedSize(closedSize(for: screen))

        if notchWindow == nil {
            let window = SkillNotchPanel(
                contentRect: frame(for: SkillNotchState.Layout.windowSize, on: screen),
                styleMask: [.borderless, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            window.ignoresMouseEvents = true
            window.onMouseExited = { [weak self] in
                self?.scheduleCollapseIfNeeded()
            }
            window.contentView = ClearHostingView(
                rootView: SkillNotchView(
                    store: appState.store,
                    languageSettings: appState.languageSettings,
                    notchState: notchState,
                    openLibrary: { [weak self] in self?.showLibraryWindow() },
                    refresh: { [weak self] in self?.refreshLibrary() }
                )
            )
            notchWindow = window
            installMouseMonitors()
        }

        updateNotchFrame(animated: false)
        notchWindow?.orderFrontRegardless()
    }

    func hideNotch() {
        cancelPendingExpansion()
        collapseTask?.cancel()
        notchWindow?.orderOut(nil)
    }

    func showLibraryWindow() {
        appState.refreshIfNeeded()

        if libraryWindowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Skill Manager"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(
                rootView: ContentView(
                    store: appState.store,
                    languageSettings: appState.languageSettings,
                    launchAtLoginSettings: appState.launchAtLoginSettings
                )
            )
            if window.setFrameUsingName(Self.libraryWindowAutosaveName) == false {
                window.center()
            }
            window.setFrameAutosaveName(Self.libraryWindowAutosaveName)
            libraryWindowController = NSWindowController(window: window)
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        libraryWindowController?.showWindow(nil)
        libraryWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === libraryWindowController?.window else { return }

        NSApp.setActivationPolicy(.accessory)
    }

    func refreshLibrary() {
        try? appState.store.refresh()
    }

    private func updateNotchFrame(animated: Bool) {
        guard let window = notchWindow else { return }
        let screen = activeScreen ?? targetScreen()
        activeScreen = screen
        notchState.updateClosedSize(closedSize(for: screen))
        let newFrame = frame(for: SkillNotchState.Layout.windowSize, on: screen).integral
        window.ignoresMouseEvents = notchState.isExpanded == false

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }
        window.contentView?.setFrameSize(newFrame.size)
    }

    private func installMouseMonitors() {
        guard globalMouseMonitor == nil, localMouseMonitor == nil else { return }

        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
        }

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
            return event
        }
    }

    private func handleMouseMoved() {
        if notchState.isExpanded == false {
            if isMouseInsideVisibleNotch(padding: HoverBehavior.closedTriggerPadding) {
                scheduleExpansionIfNeeded()
            } else {
                cancelPendingExpansion()
                notchWindow?.ignoresMouseEvents = true
            }
            return
        }

        guard notchState.isExpanded else { return }
        cancelPendingExpansion()
        notchWindow?.ignoresMouseEvents = false

        if isMouseInsideVisibleNotch(padding: HoverBehavior.expandedExitPadding) {
            collapseTask?.cancel()
        } else {
            scheduleCollapseIfNeeded()
        }
    }

    private func scheduleExpansionIfNeeded() {
        collapseTask?.cancel()
        guard expandTask == nil, notchState.isExpanded == false else { return }

        expandTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: HoverBehavior.expandDelay)
            guard !Task.isCancelled, let self else { return }
            self.expandTask = nil
            guard self.notchState.isExpanded == false else { return }
            guard self.isMouseInsideVisibleNotch(padding: HoverBehavior.closedTriggerPadding) else { return }
            self.notchWindow?.ignoresMouseEvents = false
            self.notchState.expand()
        }
    }

    private func cancelPendingExpansion() {
        expandTask?.cancel()
        expandTask = nil
    }

    private func scheduleCollapseIfNeeded() {
        collapseTask?.cancel()
        guard notchState.isExpanded else { return }

        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: HoverBehavior.collapseDelay)
            guard !Task.isCancelled, let self else { return }
            guard self.isMouseInsideVisibleNotch(padding: HoverBehavior.expandedExitPadding) == false else { return }
            self.notchState.collapse()
            self.notchWindow?.ignoresMouseEvents = true
        }
    }

    private func isMouseInsideVisibleNotch(padding: CGFloat) -> Bool {
        guard let notchWindow, notchWindow.isVisible else { return false }
        let visibleSize = notchState.currentSize
        let frame = notchWindow.frame
        let visibleFrame = NSRect(
            x: frame.midX - visibleSize.width / 2,
            y: frame.maxY - visibleSize.height,
            width: visibleSize.width,
            height: visibleSize.height
        )
        return visibleFrame.insetBy(dx: -padding, dy: -padding).contains(NSEvent.mouseLocation)
    }

    private func targetScreen() -> NSScreen? {
        if let screenWithMouse = NSScreen.screenWithMouse, screenWithMouse.safeAreaInsets.top > 0 {
            return screenWithMouse
        }

        if let notchedScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notchedScreen
        }

        return NSScreen.screenWithMouse ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func closedSize(for screen: NSScreen?) -> CGSize {
        guard let screen else { return SkillNotchState.Layout.fallbackClosedSize }

        var width = SkillNotchState.Layout.fallbackClosedSize.width
        var height = SkillNotchState.Layout.fallbackClosedSize.height

        if let leftAreaWidth = screen.auxiliaryTopLeftArea?.width,
           let rightAreaWidth = screen.auxiliaryTopRightArea?.width {
            let realNotchWidth = screen.frame.width - leftAreaWidth - rightAreaWidth + 4
            if realNotchWidth.isFinite, realNotchWidth > 0 {
                width = realNotchWidth
            }
        }

        if screen.safeAreaInsets.top > 0 {
            height = max(28, screen.safeAreaInsets.top)
        }

        return CGSize(width: width.rounded(), height: height.rounded())
    }

    private func frame(for size: CGSize, on screen: NSScreen?) -> NSRect {
        let screenFrame = screen?.frame ?? .zero

        return NSRect(
            x: screenFrame.origin.x + (screenFrame.width - size.width) / 2,
            y: screenFrame.origin.y + screenFrame.height - size.height,
            width: size.width,
            height: size.height
        )
    }
}

private extension NSScreen {
    static var screenWithMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
}

final class SkillNotchPanel: NSPanel {
    var onMouseExited: (() -> Void)?

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        level = .mainMenu + 3
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onMouseExited?()
    }
}

final class ClearHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
}
