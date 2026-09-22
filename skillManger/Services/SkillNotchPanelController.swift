import AppKit
import Combine
import SwiftUI

@MainActor
final class SkillNotchState: ObservableObject {
    enum Layout {
        static let fallbackClosedSize = CGSize(width: 210, height: 34)
        static let fallbackOpenSize = CGSize(width: 760, height: 620)
    }

    @Published var isExpanded = false
    @Published private(set) var closedSize = Layout.fallbackClosedSize
    @Published private(set) var openSize = Layout.fallbackOpenSize

    var currentSize: CGSize { isExpanded ? openSize : closedSize }
    var windowSize: CGSize {
        CGSize(
            width: openSize.width + NotchGeometry.expandedShadowHorizontalPadding * 2,
            height: openSize.height + NotchGeometry.expandedShadowBottomPadding
        )
    }

    func updateLayout(closedSize: CGSize, openSize: CGSize) {
        if self.closedSize != closedSize { self.closedSize = closedSize }
        if self.openSize != openSize { self.openSize = openSize }
    }

    func updateOpenSize(_ openSize: CGSize) {
        if self.openSize != openSize { self.openSize = openSize }
    }

    func expand() { isExpanded = true }
    func collapse() { isExpanded = false }
    func toggle() { isExpanded.toggle() }
}

@MainActor
final class SkillNotchPanelController: NSObject, NSWindowDelegate {
    static let shared = SkillNotchPanelController(appState: .shared)
    private static let libraryWindowAutosaveName = "SkillManager.LibraryWindow"

    private enum Interaction {
        static let hoverDelay: TimeInterval = 1.0
        static let collapseDelay: TimeInterval = 0.08
        static let menuActionGraceDelay: TimeInterval = 3.0
        static let menuActionMovementThreshold: CGFloat = 4
        static let expandedExitPadding: CGFloat = 8
    }

    private let appState: SkillManagerAppState
    private let notchState = SkillNotchState()
    private let compactPanel = SkillNotchPanel()
    private let expandedPanel = SkillNotchPanel()
    private var compactHost: CompactFileDropHostingView<SkillCompactNotchView>?
    private var expandedHost: NSHostingView<SkillNotchView>?
    private var libraryWindowController: NSWindowController?
    private var mousePollingTimer: Timer?
    private var globalMouseDownMonitor: Any?
    private var hoverWorkItem: DispatchWorkItem?
    private var collapseWorkItem: DispatchWorkItem?
    private var menuActionCollapseWorkItem: DispatchWorkItem?
    private var menuActionInitialMouseLocation: NSPoint?
    private var isAwaitingMenuActionInteraction = false
    private var presentationScreen: NSScreen?
    private var menuTrackingDepth = 0
    private var isApplyingExpandedFrame = false
    private var isResizingExpandedPanel = false

    init(appState: SkillManagerAppState) {
        self.appState = appState
        super.init()
        configure(compactPanel)
        configure(expandedPanel)
        expandedPanel.delegate = self
        observeScreenChanges()
        observeMenuTracking()
        observeOutsideClicks()
        observePanelEvents()
        startMousePolling()
    }

    deinit {
        mousePollingTimer?.invalidate()
        if let globalMouseDownMonitor { NSEvent.removeMonitor(globalMouseDownMonitor) }
        NotificationCenter.default.removeObserver(self)
    }

    func showNotch() {
        presentationScreen = nil
        appState.refreshIfNeeded()
        let layout = currentLayout()
        updateState(for: layout)
        rebuildContent(layout: layout)

        notchState.isExpanded = false
        compactPanel.setFrame(compactFrame(for: layout), display: true)
        applyExpandedFrame(expandedFrame(for: layout), display: true)
        expandedPanel.orderOut(nil)
        compactPanel.orderFrontRegardless()
        appState.notchSettings.recoverSleepAfterLaunchIfNeeded()
    }

    func hideNotch() {
        cancelPendingTransitions()
        compactPanel.orderOut(nil)
        expandedPanel.orderOut(nil)
    }

    func expand(animated: Bool = true, activate: Bool = false) {
        cancelPendingTransitions()
        let layout = currentLayout()
        updateState(for: layout)
        rebuildContent(layout: layout)
        applyExpandedFrame(expandedFrame(for: layout), display: true)
        expandedPanel.allowsKeyActivation = activate

        if activate {
            NSApp.activate(ignoringOtherApps: true)
            expandedPanel.makeKeyAndOrderFront(nil)
        } else {
            expandedPanel.orderFrontRegardless()
        }
        compactPanel.orderOut(nil)

        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                notchState.expand()
            }
        } else {
            notchState.expand()
        }

        if activate, appState.notchNavigation.selection == .notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                guard let self, self.notchState.isExpanded else { return }
                self.appState.editorInteractionState.requestFocus(searchingIn: self.expandedHost)
            }
        }
    }

    func collapse(animated: Bool = true) {
        guard notchState.isExpanded else { return }
        cancelPendingTransitions()
        rememberEditorSelection()

        if animated {
            withAnimation(.easeOut(duration: 0.16)) {
                notchState.collapse()
            }
        } else {
            notchState.collapse()
        }

        let delay = animated ? 0.17 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.notchState.isExpanded else { return }
            self.presentationScreen = nil
            let layout = self.currentLayout()
            self.expandedPanel.orderOut(nil)
            self.expandedPanel.allowsKeyActivation = false
            self.compactPanel.setFrame(self.compactFrame(for: layout), display: true)
            self.compactPanel.orderFrontRegardless()
        }
    }

    func createNote() {
        rememberEditorSelection()
        appState.noteStore.addTab()
        appState.notchNavigation.selection = .notes
        expand(animated: true, activate: true)
    }

    func showNotchFromMenu() {
        presentFromMenu(createNewNote: false)
    }

    func createNoteFromMenu() {
        presentFromMenu(createNewNote: true)
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
            if !window.setFrameUsingName(Self.libraryWindowAutosaveName) { window.center() }
            window.setFrameAutosaveName(Self.libraryWindowAutosaveName)
            libraryWindowController = NSWindowController(window: window)
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        libraryWindowController?.showWindow(nil)
        libraryWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === libraryWindowController?.window else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    func refreshLibrary() {
        try? appState.store.refresh()
    }

    func flush() {
        rememberEditorSelection()
        appState.noteStore.flush()
        appState.notchSettings.stopKeepingAwake()
    }

    private func configure(_ panel: SkillNotchPanel) {
        panel.appearance = nil
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        panel.onEscape = { [weak self] in self?.collapse(animated: true) }
    }

    private func rebuildContent(layout: NotchLayout) {
        let compactView = SkillCompactNotchView(
            store: appState.store,
            settings: appState.notchSettings,
            size: layout.compactSize,
            onExpand: { [weak self] in self?.expand(animated: true, activate: true) },
            onDropFiles: { [weak self] urls in self?.receiveDroppedFiles(urls) ?? false }
        )
        let expandedView = SkillNotchView(
            store: appState.store,
            languageSettings: appState.languageSettings,
            notchState: notchState,
            navigation: appState.notchNavigation,
            noteStore: appState.noteStore,
            notchSettings: appState.notchSettings,
            imageStore: appState.imageStore,
            fileShelfStore: appState.fileShelfStore,
            notebookWorkspaceState: appState.notebookWorkspaceState,
            editorInteractionState: appState.editorInteractionState,
            openLibrary: { [weak self] in self?.showLibraryWindow() },
            refresh: { [weak self] in self?.refreshLibrary() },
            collapsePanel: { [weak self] in self?.collapse(animated: true) },
            resizePanel: { [weak self] size, isFinal in
                self?.resizeExpandedPanel(to: size, isFinal: isFinal)
            }
        )

        if let compactHost {
            compactHost.rootView = compactView
            configureCompactDrop(compactHost)
        } else {
            let host = CompactFileDropHostingView(rootView: compactView)
            host.frame = NSRect(origin: .zero, size: layout.compactSize)
            host.autoresizingMask = [.width, .height]
            configureCompactDrop(host)
            compactPanel.contentView = host
            compactHost = host
        }

        if let expandedHost {
            expandedHost.rootView = expandedView
        } else {
            let host = SkillFirstMouseHostingView(rootView: expandedView)
            host.frame = NSRect(origin: .zero, size: notchState.windowSize)
            host.autoresizingMask = [.width, .height]
            expandedPanel.contentView = host
            expandedHost = host
        }
    }

    private func receiveDroppedFiles(_ urls: [URL]) -> Bool {
        let accepted = appState.fileShelfStore.acceptDrop(urls)
        guard accepted else { return false }
        appState.notchNavigation.selection = .shelf
        expand(animated: true, activate: false)
        return true
    }

    private func configureCompactDrop(_ host: CompactFileDropHostingView<SkillCompactNotchView>) {
        host.onFilesDropped = { [weak self] urls in
            self?.receiveDroppedFiles(urls) ?? false
        }
    }

    private func startMousePolling() {
        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(mousePollingTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        mousePollingTimer = timer
    }

    @objc private func mousePollingTick() {
        pollMouseLocation()
    }

    private func pollMouseLocation() {
        guard compactPanel.isVisible || expandedPanel.isVisible else { return }
        let mouse = NSEvent.mouseLocation

        if !notchState.isExpanded {
            guard appState.notchSettings.triggerMode == .hover else {
                hoverWorkItem?.cancel()
                hoverWorkItem = nil
                return
            }
            if activationFrame().contains(mouse) {
                scheduleHoverExpansion()
            } else {
                hoverWorkItem?.cancel()
                hoverWorkItem = nil
            }
            return
        }

        guard !expandedPanel.inLiveResize, !isResizingExpandedPanel else {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            return
        }

        if isAwaitingMenuActionInteraction {
            if menuActionPointerMovedIntoPanel(mouse) {
                registerMenuActionInteraction()
            } else {
                return
            }
        }

        guard appState.fileShelfStore.items.isEmpty else {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            return
        }

        guard appState.notchSettings.triggerMode == .hover,
              menuTrackingDepth == 0,
              !appState.editorInteractionState.hasKeyboardFocus() else { return }
        if isPointInExpandedStayRegion(mouse) {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
        } else {
            scheduleCollapse()
        }
    }

    private func scheduleHoverExpansion() {
        guard hoverWorkItem == nil, !notchState.isExpanded else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.hoverWorkItem = nil
            guard self.activationFrame().contains(NSEvent.mouseLocation) else { return }
            self.expand(animated: true, activate: false)
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Interaction.hoverDelay, execute: work)
    }

    private func scheduleCollapse() {
        guard collapseWorkItem == nil else { return }
        guard appState.fileShelfStore.items.isEmpty else { return }
        guard menuTrackingDepth == 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.collapseWorkItem = nil
            guard !self.expandedPanel.inLiveResize, !self.isResizingExpandedPanel else { return }
            guard self.appState.fileShelfStore.items.isEmpty else { return }
            guard self.menuTrackingDepth == 0 else { return }
            guard !self.isPointInExpandedStayRegion(NSEvent.mouseLocation) else { return }
            self.collapse(animated: true)
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Interaction.collapseDelay, execute: work)
    }

    private func cancelPendingTransitions() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
        menuActionCollapseWorkItem?.cancel()
        menuActionCollapseWorkItem = nil
        menuActionInitialMouseLocation = nil
        isAwaitingMenuActionInteraction = false
    }

    private func observeOutsideClicks() {
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.notchState.isExpanded else { return }
                guard self.appState.fileShelfStore.items.isEmpty else { return }
                guard !self.isPointInExpandedStayRegion(NSEvent.mouseLocation) else { return }
                self.collapse(animated: true)
            }
        }
    }

    private func observePanelEvents() {
        expandedPanel.onMouseEvent = { [weak self] event in
            guard let self else { return }
            self.registerMenuActionInteraction()
            guard event.type == .leftMouseDown else { return }
            self.expandedPanel.allowsKeyActivation = true
            NSApp.activate(ignoringOtherApps: true)
            self.expandedPanel.makeKeyAndOrderFront(nil)
        }
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        repositionForCurrentScreen()
    }

    private func observeMenuTracking() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidBeginTracking),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidEndTracking),
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )
    }

    @objc private func menuDidBeginTracking() {
        menuTrackingDepth += 1
        collapseWorkItem?.cancel()
        collapseWorkItem = nil
    }

    @objc private func menuDidEndTracking() {
        menuTrackingDepth = 0
        DispatchQueue.main.async { [weak self] in
            self?.pollMouseLocation()
        }
    }

    private func repositionForCurrentScreen() {
        let layout = currentLayout()
        updateState(for: layout)
        rebuildContent(layout: layout)
        compactPanel.setFrame(compactFrame(for: layout), display: true)
        applyExpandedFrame(expandedFrame(for: layout), display: true)
    }

    private func rememberEditorSelection() {
        if let range = appState.editorInteractionState.currentSelectionRange() {
            appState.noteStore.updateSelection(for: appState.noteStore.activeTabID, range: range)
        }
        appState.noteStore.flush(waitForDisk: false)
    }

    private func updateState(for layout: NotchLayout) {
        notchState.updateLayout(closedSize: layout.compactSize, openSize: layout.expandedSize)
        let screenFrame = targetFrame()
        expandedPanel.minSize = NSSize(
            width: NotchGeometry.minimumExpandedSize.width + NotchGeometry.expandedShadowHorizontalPadding * 2,
            height: NotchGeometry.minimumExpandedSize.height + NotchGeometry.expandedShadowBottomPadding
        )
        expandedPanel.maxSize = NSSize(
            width: max(
                NotchGeometry.minimumExpandedSize.width,
                screenFrame.width - 36 - NotchGeometry.expandedShadowHorizontalPadding * 2
            ) + NotchGeometry.expandedShadowHorizontalPadding * 2,
            height: max(
                NotchGeometry.minimumExpandedSize.height,
                screenFrame.height - 72 - NotchGeometry.expandedShadowBottomPadding
            ) + NotchGeometry.expandedShadowBottomPadding
        )
    }

    private func currentLayout() -> NotchLayout {
        NotchGeometry.layout(
            for: targetScreen(),
            preferredExpandedSize: appState.notchSettings.preferredExpandedSize
        )
    }

    private func targetFrame() -> NSRect {
        targetScreen()?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    }

    private func compactFrame(for layout: NotchLayout) -> NSRect {
        NotchGeometry.activationFrame(for: layout, in: targetFrame())
    }

    private func expandedFrame(for layout: NotchLayout) -> NSRect {
        NotchGeometry.topCenteredFrame(
            for: notchState.windowSize,
            topY: targetFrame().maxY + layout.expandedTopOffset,
            in: targetFrame()
        )
    }

    private func activationFrame() -> NSRect {
        NotchGeometry.activationFrame(for: currentLayout(), in: targetFrame())
    }

    private func expandedContentFrame() -> NSRect {
        var frame = expandedPanel.frame
        frame.origin.x += NotchGeometry.expandedShadowHorizontalPadding
        frame.size.width = notchState.openSize.width
        frame.origin.y = frame.maxY - notchState.openSize.height
        frame.size.height = notchState.openSize.height
        return frame
    }

    private func isPointInExpandedStayRegion(_ point: NSPoint) -> Bool {
        expandedContentFrame()
            .insetBy(dx: -Interaction.expandedExitPadding, dy: -Interaction.expandedExitPadding)
            .contains(point)
            || activationFrame().contains(point)
    }

    private func targetScreen() -> NSScreen? {
        if let presentationScreen,
           let displayID = presentationScreen.displayID,
           NSScreen.screens.contains(where: { $0.displayID == displayID }) {
            return presentationScreen
        }
        return NotchGeometry.targetScreen()
    }

    private func presentFromMenu(createNewNote: Bool) {
        let mouseLocation = NSEvent.mouseLocation
        presentationScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NotchGeometry.targetScreen()

        if createNewNote {
            rememberEditorSelection()
            appState.noteStore.addTab()
            appState.notchNavigation.selection = .notes
        }

        expand(animated: true, activate: true)
        scheduleMenuActionCollapse(from: mouseLocation)
    }

    private func scheduleMenuActionCollapse(from mouseLocation: NSPoint) {
        menuActionCollapseWorkItem?.cancel()
        menuActionInitialMouseLocation = mouseLocation
        isAwaitingMenuActionInteraction = true

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isAwaitingMenuActionInteraction else { return }
            self.menuActionCollapseWorkItem = nil
            self.menuActionInitialMouseLocation = nil
            self.isAwaitingMenuActionInteraction = false
            guard self.appState.fileShelfStore.items.isEmpty else { return }
            self.collapse(animated: true)
        }
        menuActionCollapseWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Interaction.menuActionGraceDelay,
            execute: work
        )
    }

    private func menuActionPointerMovedIntoPanel(_ mouseLocation: NSPoint) -> Bool {
        guard expandedPanel.frame.contains(mouseLocation),
              let initialLocation = menuActionInitialMouseLocation else { return false }
        return hypot(
            mouseLocation.x - initialLocation.x,
            mouseLocation.y - initialLocation.y
        ) >= Interaction.menuActionMovementThreshold
    }

    private func registerMenuActionInteraction() {
        guard isAwaitingMenuActionInteraction else { return }
        menuActionCollapseWorkItem?.cancel()
        menuActionCollapseWorkItem = nil
        menuActionInitialMouseLocation = nil
        isAwaitingMenuActionInteraction = false
    }

    private func applyExpandedFrame(_ frame: NSRect, display: Bool) {
        isApplyingExpandedFrame = true
        expandedPanel.setFrame(frame, display: display)
        synchronizeExpandedHostFrame(to: frame.size)
        isApplyingExpandedFrame = false
    }

    private func synchronizeExpandedHostFrame(to size: NSSize) {
        let bounds = NSRect(origin: .zero, size: size)
        expandedPanel.contentView?.frame = bounds
        expandedHost?.frame = bounds
    }

    private func resizeExpandedPanel(to requestedSize: NSSize, isFinal: Bool) {
        isResizingExpandedPanel = !isFinal
        collapseWorkItem?.cancel()
        collapseWorkItem = nil

        let size = NotchGeometry.clampedExpandedSize(requestedSize, in: targetFrame())
        notchState.updateOpenSize(size)
        applyExpandedFrame(expandedFrame(for: currentLayout()), display: true)

        if isFinal {
            appState.notchSettings.saveExpandedSize(size)
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === expandedPanel,
              notchState.isExpanded,
              !isApplyingExpandedFrame else { return }
        notchState.updateOpenSize(
            NSSize(
                width: max(
                    1,
                    window.frame.width - NotchGeometry.expandedShadowHorizontalPadding * 2
                ),
                height: max(1, window.frame.height - NotchGeometry.expandedShadowBottomPadding)
            )
        )
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === expandedPanel else { return }
        let size = NotchGeometry.clampedExpandedSize(
            NSSize(
                width: window.frame.width - NotchGeometry.expandedShadowHorizontalPadding * 2,
                height: window.frame.height - NotchGeometry.expandedShadowBottomPadding
            ),
            in: targetFrame()
        )
        appState.notchSettings.saveExpandedSize(size)
        notchState.updateOpenSize(size)
        applyExpandedFrame(expandedFrame(for: currentLayout()), display: true)
    }
}

final class SkillNotchPanel: NSPanel {
    var allowsKeyActivation = false
    var onEscape: (() -> Void)?
    var onMouseEvent: ((NSEvent) -> Void)?

    convenience init() {
        self.init(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
    }

    override var canBecomeKey: Bool { allowsKeyActivation }
    override var canBecomeMain: Bool { allowsKeyActivation }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 {
            onEscape?()
            return
        }
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel:
            onMouseEvent?(event)
        default:
            break
        }
        super.sendEvent(event)
    }
}

class SkillFirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

class TransparentHitHostingView<Content: View>: SkillFirstMouseHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        return super.hitTest(point) ?? self
    }
}

final class CompactFileDropHostingView<Content: View>: TransparentHitHostingView<Content> {
    var onFilesDropped: (([URL]) -> Bool)?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDropPasteboardReader.containsFileURLs(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDropPasteboardReader.containsFileURLs(sender.draggingPasteboard) ? .copy : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        FileDropPasteboardReader.containsFileURLs(sender.draggingPasteboard)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = FileDropPasteboardReader.fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        return onFilesDropped?(urls) ?? false
    }
}
