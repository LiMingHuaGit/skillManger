//
//  PerformanceDiagnostics.swift
//  skillManger
//
//  Created by Codex on 2026/9/2.
//

import Foundation
import OSLog

enum PerformanceDiagnostics {
    static let library = Logger(subsystem: subsystem, category: "LibraryPerformance")
    static let indexing = Logger(subsystem: subsystem, category: "IndexingPerformance")
    static let recommendations = Logger(subsystem: subsystem, category: "RecommendationPerformance")

    private static let subsystem = Bundle.main.bundleIdentifier ?? "liminghua.skillManger"

    static func start() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    @discardableResult
    static func finish(
        _ operation: String,
        startedAt: UInt64,
        logger: Logger,
        itemCount: Int? = nil,
        details: String = "",
        slowThresholdMS: Double? = nil
    ) -> Double {
        let elapsedMS = milliseconds(since: startedAt)
        let count = itemCount.map(String.init) ?? "-"
        let thread = Thread.isMainThread ? "main" : "background"

        if let slowThresholdMS, elapsedMS >= slowThresholdMS {
            logger.notice("SLOW operation=\(operation, privacy: .public) duration_ms=\(elapsedMS, format: .fixed(precision: 2)) count=\(count, privacy: .public) thread=\(thread, privacy: .public) details=\(details, privacy: .public)")
        } else {
            logger.debug("operation=\(operation, privacy: .public) duration_ms=\(elapsedMS, format: .fixed(precision: 2)) count=\(count, privacy: .public) thread=\(thread, privacy: .public) details=\(details, privacy: .public)")
        }

        return elapsedMS
    }

    static func milliseconds(since startedAt: UInt64) -> Double {
        let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
        return Double(elapsed) / 1_000_000
    }
}
