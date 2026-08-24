//
//  CodexSessionContextReader.swift
//  skillManger
//
//  Created by Codex on 2026/8/24.
//

import Foundation
import SQLite3

enum CodexSessionContextReaderError: LocalizedError {
    case missingSessionIndex(String)
    case unreadableSessionIndex(String)

    var errorDescription: String? {
        switch self {
        case .missingSessionIndex(let path):
            "Codex session index was not found at \(path)."
        case .unreadableSessionIndex(let path):
            "Codex session index could not be read at \(path)."
        }
    }
}

struct CodexSessionContextReader {
    private let codexHomeURL: URL
    private let fileManager: FileManager

    init(codexHomeURL: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex", isDirectory: true), fileManager: FileManager = .default) {
        self.codexHomeURL = codexHomeURL
        self.fileManager = fileManager
    }

    func recentContexts(limit: Int = 8, messagesPerSession: Int = 4) throws -> [CodexSessionContext] {
        let sessions = try readSessionIndex(limit: max(limit * 3, limit))
        let historyURL = codexHomeURL.appendingPathComponent("thread_history_1.sqlite")
        let historySnapshotURL = makeHistorySnapshot(from: historyURL)
        defer { removeHistorySnapshot(at: historySnapshotURL) }

        return sessions.prefix(limit).map { session in
            CodexSessionContext(
                id: session.id,
                title: session.title,
                preview: session.title,
                cwd: "",
                updatedAt: session.updatedAt,
                recentUserMessages: historySnapshotURL.map {
                    readRecentUserMessages(threadID: session.id, databaseURL: $0, limit: messagesPerSession)
                } ?? []
            )
        }
    }

    private func makeHistorySnapshot(from sourceURL: URL) -> URL? {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return nil }

        let snapshotDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("SkillManagerCodexHistory-\(UUID().uuidString)", isDirectory: true)
        let snapshotURL = snapshotDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            try fileManager.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
            try fileManager.copyItem(at: sourceURL, to: snapshotURL)
            copySidecarIfPresent(named: sourceURL.path + "-wal", to: snapshotURL.path + "-wal")
            copySidecarIfPresent(named: sourceURL.path + "-shm", to: snapshotURL.path + "-shm")
            return snapshotURL
        } catch {
            try? fileManager.removeItem(at: snapshotDirectory)
            return nil
        }
    }

    private func copySidecarIfPresent(named sourcePath: String, to destinationPath: String) {
        guard fileManager.fileExists(atPath: sourcePath) else { return }
        try? fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
    }

    private func removeHistorySnapshot(at snapshotURL: URL?) {
        guard let snapshotURL else { return }
        try? fileManager.removeItem(at: snapshotURL.deletingLastPathComponent())
    }

    private func readSessionIndex(limit: Int) throws -> [IndexedSession] {
        let indexURL = codexHomeURL.appendingPathComponent("session_index.jsonl")
        guard fileManager.fileExists(atPath: indexURL.path) else {
            throw CodexSessionContextReaderError.missingSessionIndex(indexURL.path)
        }
        guard let contents = try? String(contentsOf: indexURL, encoding: .utf8) else {
            throw CodexSessionContextReaderError.unreadableSessionIndex(indexURL.path)
        }

        var latestByID: [String: IndexedSession] = [:]
        for line in contents.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let entry = try? JSONDecoder().decode(SessionIndexEntry.self, from: data),
                  let updatedAt = Self.parseDate(entry.updatedAt) else { continue }

            let session = IndexedSession(id: entry.id, title: entry.threadName, updatedAt: updatedAt)
            if let existing = latestByID[entry.id], existing.updatedAt >= updatedAt { continue }
            latestByID[entry.id] = session
        }

        return latestByID.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    private func readRecentUserMessages(threadID: String, databaseURL: URL, limit: Int) -> [String] {
        guard fileManager.fileExists(atPath: databaseURL.path) else { return [] }

        var database: OpaquePointer?
        let databaseURI = databaseURL.absoluteString + "?mode=ro&immutable=1"
        guard sqlite3_open_v2(databaseURI, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI, nil) == SQLITE_OK,
              let database else {
            return []
        }
        defer { sqlite3_close(database) }

        let query = """
        SELECT item_json
        FROM thread_items
        WHERE thread_id = ? AND item_type = 'userMessage'
        ORDER BY created_at_ms DESC
        LIMIT ?
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, threadID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var messages: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let rawText = sqlite3_column_text(statement, 0) else { continue }
            let json = String(cString: rawText)
            if let text = Self.extractUserText(from: json), text.isEmpty == false {
                messages.append(text)
            }
        }
        return messages.reversed()
    }

    private static func extractUserText(from itemJSON: String) -> String? {
        guard let data = itemJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ThreadItemPayload.self, from: data) else { return nil }

        return payload.content
            .compactMap(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
            .nilIfBlank
    }

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        let regular = ISO8601DateFormatter()
        regular.formatOptions = [.withInternetDateTime]
        return regular.date(from: value)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private struct IndexedSession: Hashable {
    var id: String
    var title: String
    var updatedAt: Date
}

private struct SessionIndexEntry: Decodable {
    var id: String
    var threadName: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
        case updatedAt = "updated_at"
    }
}

private struct ThreadItemPayload: Decodable {
    var content: [ThreadContent]
}

private struct ThreadContent: Decodable {
    var text: String?
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
