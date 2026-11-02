import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
final class NotchPanelHotKeyController {
    private let settingsStore: NotchWorkspaceSettings
    private var cancellable: AnyCancellable?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x534b4d47), id: 1)

    init(settingsStore: NotchWorkspaceSettings) {
        self.settingsStore = settingsStore
        installEventHandler()
        registerCurrentShortcut()
        cancellable = settingsStore.$panelShortcut
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.registerCurrentShortcut()
            }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.id == 1 else { return OSStatus(eventNotHandledErr) }

                let controller = Unmanaged<NotchPanelHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in
                    controller.showNotchPanel()
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        if status != noErr {
            settingsStore.setPanelShortcutRegistrationError("The global shortcut listener could not start.")
        }
    }

    private func registerCurrentShortcut() {
        unregisterHotKey()
        let shortcut = settingsStore.panelShortcut
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.registrationModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        if status == noErr {
            hotKeyRef = newHotKeyRef
            settingsStore.setPanelShortcutRegistrationError(nil)
        } else {
            hotKeyRef = nil
            settingsStore.setPanelShortcutRegistrationError("The shortcut is already used by macOS or another app.")
        }
    }

    private func unregisterHotKey() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func showNotchPanel() {
        SkillNotchPanelController.shared.toggleFromShortcut()
    }
}
