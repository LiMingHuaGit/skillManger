import AppKit
import Foundation

enum FileDropPayload {
    static func normalizedFileURLs(from urls: [URL]) -> [URL] {
        var knownPaths = Set<String>()
        return urls.compactMap { url in
            guard url.isFileURL else { return nil }

            let standardizedURL = url.standardizedFileURL
            guard knownPaths.insert(standardizedURL.path).inserted else {
                return nil
            }
            return standardizedURL
        }
    }
}

@MainActor
enum FileDropPasteboardReader {
    static func containsFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.availableType(from: [.fileURL]) != nil
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.pasteboardItems?.compactMap { item -> URL? in
            guard let value = item.string(forType: .fileURL),
                  let url = URL(string: value),
                  url.isFileURL else {
                return nil
            }
            return url
        } ?? []

        return FileDropPayload.normalizedFileURLs(from: urls)
    }
}

enum FileDragPasteboard {
    static func writer(for url: URL) -> NSURL {
        url.standardizedFileURL as NSURL
    }
}

enum FileDragOperationPolicy {
    static let allowedOperations: NSDragOperation = [.copy, .generic]
}

enum FileDragGesturePolicy {
    static let activationDistance: CGFloat = 8

    static func shouldBegin(from start: NSPoint, to current: NSPoint) -> Bool {
        hypot(current.x - start.x, current.y - start.y) >= activationDistance
    }
}

@MainActor
struct FileDragTrackingState {
    private(set) var mouseDownLocation: NSPoint?
    private(set) var mouseDownPasteboardChangeCount: Int?
    private(set) var didReachActivationDistance = false

    mutating func mouseDown(at location: NSPoint, pasteboardChangeCount: Int) {
        mouseDownLocation = location
        mouseDownPasteboardChangeCount = pasteboardChangeCount
        didReachActivationDistance = false
    }

    mutating func mouseDragged(to location: NSPoint) {
        guard let mouseDownLocation else { return }
        if FileDragGesturePolicy.shouldBegin(from: mouseDownLocation, to: location) {
            didReachActivationDistance = true
        }
    }

    mutating func mouseUp() {
        mouseDownLocation = nil
        mouseDownPasteboardChangeCount = nil
        didReachActivationDistance = false
    }

    func shouldTreatAsFileDrag(
        at point: NSPoint,
        isLeftMouseButtonDown: Bool,
        pasteboard: NSPasteboard,
        fileDropFrame: NSRect
    ) -> Bool {
        guard isLeftMouseButtonDown,
              didReachActivationDistance,
              let mouseDownPasteboardChangeCount,
              pasteboard.changeCount != mouseDownPasteboardChangeCount,
              FileDropPasteboardReader.containsFileURLs(pasteboard),
              fileDropFrame.contains(point) else {
            return false
        }
        return true
    }
}
