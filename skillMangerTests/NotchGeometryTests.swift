import AppKit
import XCTest
@testable import skillManger

@MainActor
final class NotchGeometryTests: XCTestCase {
    func testActivationFrameMatchesNotchInsteadOfExtendedDropTarget() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let layout = NotchLayout(
            notchSize: NSSize(width: 210, height: 32),
            compactSize: NSSize(width: 204, height: 34),
            expandedSize: NSSize(width: 480, height: 408),
            compactTopOffset: 0,
            expandedTopOffset: 0
        )

        let activationFrame = NotchGeometry.activationFrame(for: layout, in: screenFrame)
        let dropFrame = NotchGeometry.fileDropFrame(for: layout, in: screenFrame)

        XCTAssertEqual(activationFrame.width, 210)
        XCTAssertEqual(activationFrame.height, 34)
        XCTAssertEqual(activationFrame.midX, screenFrame.midX)
        XCTAssertEqual(activationFrame.maxY, screenFrame.maxY)
        XCTAssertEqual(dropFrame.maxY, activationFrame.maxY)
        XCTAssertEqual(
            dropFrame.height - activationFrame.height,
            NotchGeometry.fileDropTargetExtension
        )
    }

    func testExpandedSizeUsesSavedPreferenceWithinScreenBounds() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1200, height: 800)

        XCTAssertEqual(
            NotchGeometry.clampedExpandedSize(NSSize(width: 900, height: 700), in: screenFrame),
            NSSize(width: 900, height: 700)
        )
        XCTAssertEqual(
            NotchGeometry.clampedExpandedSize(NSSize(width: 2000, height: 1200), in: screenFrame),
            NSSize(width: 1164, height: 728)
        )
        XCTAssertEqual(
            NotchGeometry.clampedExpandedSize(NSSize(width: 320, height: 260), in: screenFrame),
            NotchGeometry.minimumExpandedSize
        )
    }

    func testScreenFrameSelectionSupportsOffsetExternalDisplays() {
        let builtIn = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let external = NSRect(x: 1512, y: -160, width: 2560, height: 1440)

        XCTAssertEqual(
            NotchGeometry.screenFrame(containing: NSPoint(x: 2400, y: 900), from: [builtIn, external]),
            external
        )
    }
}
