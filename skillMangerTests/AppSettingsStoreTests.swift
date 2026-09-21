import Foundation
import XCTest
@testable import skillManger

@MainActor
final class NotchWorkspaceSettingsTests: XCTestCase {
    func testSleepRecoveryWaitsUntilApplicationIsVisible() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "skillManager.notch.completedSleepGuardRecoveryV1")
        defaults.set(true, forKey: "skillManager.notch.ownsSleepDisabled")
        let sleepGuard = FakeSystemSleepGuard()
        sleepGuard.resetResult = true

        let store = NotchWorkspaceSettings(
            defaults: defaults,
            systemSleepGuard: sleepGuard,
            sleepDisabledState: { true }
        )

        XCTAssertTrue(store.isKeepingAwake)
        XCTAssertFalse(store.isChangingKeepAwake)
        XCTAssertEqual(sleepGuard.resetCallCount, 0)

        store.recoverSleepAfterLaunchIfNeeded()
        await waitUntil { !store.isChangingKeepAwake }

        XCTAssertEqual(sleepGuard.resetCallCount, 1)
        XCTAssertFalse(defaults.bool(forKey: "skillManager.notch.ownsSleepDisabled"))
        XCTAssertFalse(store.isKeepingAwake)
    }

    func testFailedAuthorizationNeverClaimsSleepOwnership() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "skillManager.notch.completedSleepGuardRecoveryV1")
        let sleepGuard = FakeSystemSleepGuard()
        sleepGuard.shouldSuspendReadiness = true
        sleepGuard.resetResult = true
        let store = NotchWorkspaceSettings(
            defaults: defaults,
            systemSleepGuard: sleepGuard,
            sleepDisabledState: { false }
        )

        store.toggleKeepAwake()
        await waitUntil { sleepGuard.isWaitingForReadiness }

        XCTAssertTrue(store.isChangingKeepAwake)
        XCTAssertFalse(defaults.bool(forKey: "skillManager.notch.ownsSleepDisabled"))

        sleepGuard.resolveReadiness(.failure(SystemSleepGuardError.authorizationDenied))
        await waitUntil { !store.isChangingKeepAwake }

        XCTAssertFalse(defaults.bool(forKey: "skillManager.notch.ownsSleepDisabled"))
        XCTAssertFalse(store.isKeepingAwake)
        XCTAssertNotNil(store.keepAwakeErrorMessage)
    }

    func testCancelledAuthorizationReturnsToIdleWithoutErrorAlert() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "skillManager.notch.completedSleepGuardRecoveryV1")
        let sleepGuard = FakeSystemSleepGuard()
        sleepGuard.shouldSuspendReadiness = true
        let store = NotchWorkspaceSettings(
            defaults: defaults,
            systemSleepGuard: sleepGuard,
            sleepDisabledState: { false }
        )

        store.toggleKeepAwake()
        await waitUntil { sleepGuard.isWaitingForReadiness }
        sleepGuard.resolveReadiness(.failure(SystemSleepGuardError.authorizationCancelled))
        await waitUntil { !store.isChangingKeepAwake }

        XCTAssertFalse(store.isKeepingAwake)
        XCTAssertNil(store.keepAwakeErrorMessage)
        XCTAssertFalse(defaults.bool(forKey: "skillManager.notch.ownsSleepDisabled"))
    }

    func testShelfDragBehaviorAndExpandedSizePersist() {
        let defaults = makeDefaults()
        let store = NotchWorkspaceSettings(
            defaults: defaults,
            systemSleepGuard: FakeSystemSleepGuard(),
            sleepDisabledState: { false }
        )

        store.shelfDragCompletionBehavior = .remove
        store.shelfFileTransferMode = .move
        store.appearanceMode = .light
        store.panelOpacity = 0.70
        store.saveExpandedSize(CGSize(width: 880, height: 660))

        let restored = NotchWorkspaceSettings(
            defaults: defaults,
            systemSleepGuard: FakeSystemSleepGuard(),
            sleepDisabledState: { false }
        )
        XCTAssertEqual(restored.shelfDragCompletionBehavior, .remove)
        XCTAssertEqual(restored.shelfFileTransferMode, .move)
        XCTAssertEqual(restored.appearanceMode, .light)
        XCTAssertEqual(restored.panelOpacity, 0.70)
        XCTAssertEqual(restored.preferredExpandedSize, CGSize(width: 880, height: 660))
    }

    func testPanelOpacityIsClampedWhenRestoredAndChanged() {
        let defaults = makeDefaults()
        defaults.set(0.20, forKey: "skillManager.notch.panelOpacity")
        let store = NotchWorkspaceSettings(
            defaults: defaults,
            systemSleepGuard: FakeSystemSleepGuard(),
            sleepDisabledState: { false }
        )

        XCTAssertEqual(store.panelOpacity, 0.60)

        store.panelOpacity = 1.40
        XCTAssertEqual(store.panelOpacity, 1.0)
        XCTAssertEqual(defaults.double(forKey: "skillManager.notch.panelOpacity"), 1.0)

        store.panelOpacity = 0.10
        XCTAssertEqual(store.panelOpacity, 0.60)
        XCTAssertEqual(defaults.double(forKey: "skillManager.notch.panelOpacity"), 0.60)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
        XCTAssertTrue(condition())
    }
}

@MainActor
private final class FakeSystemSleepGuard: SystemSleepGuardControlling {
    var isRunning = false
    var shouldSuspendReadiness = false
    var resetResult = true
    private(set) var isWaitingForReadiness = false
    private(set) var resetCallCount = 0
    private var readinessContinuation: CheckedContinuation<Void, Error>?

    func start() throws {
        isRunning = true
    }

    func waitUntilReady() async throws {
        guard shouldSuspendReadiness else {
            throw SystemSleepGuardError.helperLaunchFailed("Fake helper was not configured.")
        }

        isWaitingForReadiness = true
        return try await withCheckedThrowingContinuation { continuation in
            readinessContinuation = continuation
        }
    }

    func resolveReadiness(_ result: Result<Void, Error>) {
        isWaitingForReadiness = false
        readinessContinuation?.resume(with: result)
        readinessContinuation = nil
    }

    func requestStop() {
        isRunning = false
    }

    func resetSleepIfNeeded() async -> Bool {
        resetCallCount += 1
        isRunning = false
        return resetResult
    }
}
