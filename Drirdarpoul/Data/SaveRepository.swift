import Foundation

struct CompletionRecord: Codable {
    let levelID: String
    let contentRevision: Int
    let board: [String]
    let notes: String
    let hintCount: Int
    let testimonyMarks: [String: String]
    let completedAt: Date
    let lastPlayedAt: Date
}

private struct SaveDocument: Codable {
    var saveVersion: Int = 1
    var drafts: [String: Draft] = [:]
    var completed: [String: CompletionRecord] = [:]
    var currentLevelID: String?
}

/// Small, versioned offline store. All reads and writes are serialized on one queue.
/// Unknown newer versions remain read-only, including when an older backup exists.
final class SaveRepository {
    private enum ReadFailure: Error { case corrupt, futureVersion }
    private static let currentVersion = 1
    private static let maximumFileSize = 10 * 1024 * 1024

    let directory: URL
    private let queue = DispatchQueue(label: "com.cardtrace.save", qos: .utility)
    private var document = SaveDocument()
    private var pendingWrite: DispatchWorkItem?
    private var lastGoodData: Data?
    private var storedNotice: String?
    private var storedError: String?
    private var protectedNewerVersion = false
    private let knownLevels: [String: Level]

    var drafts: [String: Draft] { queue.sync { document.drafts } }
    var completed: [String: CompletionRecord] { queue.sync { document.completed } }
    var currentLevelID: String? { queue.sync { document.currentLevelID } }
    var notice: String? { queue.sync { storedNotice } }
    var lastError: String? { queue.sync { storedError } }
    var isReadOnly: Bool { queue.sync { protectedNewerVersion } }

    private var primaryURL: URL { directory.appendingPathComponent("progress.json") }
    private var backupURL: URL { directory.appendingPathComponent("progress.backup.json") }

    init(levels: [Level] = [], directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CardTrace", isDirectory: true)
        self.knownLevels = Dictionary(levels.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        queue.sync { load() }
    }

    func draft(for level: Level) -> Draft? {
        queue.sync {
            guard let draft = document.drafts[level.id], draft.contentRevision == level.contentRevision else { return nil }
            return draft
        }
    }

    /// Coalesces rapid moves, but does not depend on lifecycle callbacks for saving.
    func updateDraft(_ draft: Draft) {
        queue.sync {
            document.drafts[draft.levelID] = draft
            document.currentLevelID = draft.levelID
            scheduleWrite()
        }
    }

    /// Recheck the same public rules used by the UI before recording a completion.
    /// The exact accepted reconstruction is retained for later replay.
    @discardableResult
    func complete(level: Level, session: GameSession) -> Bool {
        let draft = session.makeDraft()
        guard draft.levelID == level.id, draft.board.allSatisfy({ $0 != nil }) else { return false }
        return complete(level: level, board: draft.board.compactMap { $0 }, notes: draft.notes,
                        hintCount: draft.hintCount, testimonyMarks: draft.testimonyMarks)
    }

    @discardableResult
    func complete(level: Level, board: [String], notes: String, hintCount: Int,
                  testimonyMarks: [String: String] = [:]) -> Bool {
        guard RuleEngine.evaluate(level: level, board: board.map { Optional($0) }).accepted else { return false }
        return queue.sync {
            let now = Date()
            document.completed[level.id] = CompletionRecord(
                levelID: level.id, contentRevision: level.contentRevision, board: board,
                notes: String(notes.prefix(GameSession.noteLimit)),
                hintCount: max(0, min(hintCount, level.hints.count)), testimonyMarks: testimonyMarks,
                completedAt: document.completed[level.id]?.completedAt ?? now, lastPlayedAt: now)
            document.drafts.removeValue(forKey: level.id)
            document.currentLevelID = level.id
            pendingWrite?.cancel()
            pendingWrite = nil
            return writeDocument()
        }
    }

    func resetDraft(for level: Level) {
        queue.sync {
            document.drafts.removeValue(forKey: level.id)
            if document.currentLevelID == level.id { document.currentLevelID = nil }
            scheduleWrite()
        }
    }

    /// Flush on leaving a game, completion, and application background entry.
    @discardableResult
    func saveNow() -> Bool {
        queue.sync {
            pendingWrite?.cancel()
            pendingWrite = nil
            return writeDocument()
        }
    }

    private func scheduleWrite() {
        pendingWrite?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingWrite = nil
            _ = self.writeDocument()
        }
        pendingWrite = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func read(_ url: URL) throws -> (SaveDocument, Data, Bool) {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attrs[.size] as? NSNumber, size.intValue <= Self.maximumFileSize else { throw ReadFailure.corrupt }
        let data = try Data(contentsOf: url)
        guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = raw["saveVersion"] as? Int else { throw ReadFailure.corrupt }
        if version > Self.currentVersion { throw ReadFailure.futureVersion }
        guard version >= 0 else { throw ReadFailure.corrupt }
        // Compatibility policy: version zero is accepted only when all current
        // record fields decode. Migration keeps the original bytes as the backup.
        var decoded = try JSONDecoder().decode(SaveDocument.self, from: data)
        decoded.saveVersion = Self.currentVersion
        return (decoded, data, version < Self.currentVersion)
    }

    private func load() {
        let manager = FileManager.default
        var primaryFailed = false
        if manager.fileExists(atPath: primaryURL.path) {
            do {
                let (loaded, raw, migrated) = try read(primaryURL)
                document = loaded
                lastGoodData = raw
                if migrated { appendNotice("Your save was upgraded. The original record is preserved in a backup.") }
            } catch ReadFailure.futureVersion {
                protectedNewerVersion = true
                primaryFailed = true
                appendNotice("This save is from a newer version. You can play temporarily, but must update the app to save progress. The original file is preserved.")
            } catch {
                primaryFailed = true
                preserveCorruptFile(primaryURL)
            }
        }
        if lastGoodData == nil && manager.fileExists(atPath: backupURL.path) {
            do {
                let (loaded, raw, _) = try read(backupURL)
                document = loaded
                lastGoodData = raw
                appendNotice("Progress was restored from the latest backup. You may need to repeat your last move.")
            } catch ReadFailure.futureVersion {
                protectedNewerVersion = true
                appendNotice("The backup is from a newer version. The original file is preserved; update the app to restore it.")
            } catch {
                preserveCorruptFile(backupURL)
                appendNotice("Neither the save nor its backup could be read. The damaged files are preserved. You can start this case again.")
            }
        } else if primaryFailed && lastGoodData == nil && !protectedNewerVersion {
            appendNotice("The save could not be read. The damaged file is preserved. You can start this case again.")
        }
        normalizeLoadedDrafts()
        normalizeLoadedCompletions()
    }

    private func normalizeLoadedDrafts() {
        for (id, draft) in document.drafts {
            guard id == draft.levelID else {
                document.drafts.removeValue(forKey: id)
                appendNotice("Unrecognized drafts were removed. Completed records are preserved.")
                continue
            }
            guard let level = knownLevels[id] else { continue }
            guard draft.contentRevision == level.contentRevision else {
                document.drafts.removeValue(forKey: id)
                appendNotice("Some file content was updated and its drafts were reset. Completed records are preserved.")
                continue
            }
            let repaired = GameSession(level: level, draft: draft).makeDraft()
            if repaired.board != draft.board || repaired.undoStack != draft.undoStack ||
                repaired.notes != draft.notes || repaired.testimonyMarks != draft.testimonyMarks ||
                repaired.hintCount != draft.hintCount {
                document.drafts[id] = repaired
                appendNotice("Invalid card placements or undo history were repaired. Other progress is preserved.")
            }
        }
    }

    private func normalizeLoadedCompletions() {
        let invalid = document.completed.filter { !isValidCompletion($0.value, for: $0.key) }
        guard !invalid.isEmpty else { return }
        preserveCorruptFile(primaryURL)
        var backup: SaveDocument?
        if FileManager.default.fileExists(atPath: backupURL.path) {
            do { backup = try read(backupURL).0 }
            catch ReadFailure.futureVersion {
                protectedNewerVersion = true
                appendNotice("The backup is from a newer version. The original file is preserved; update the app to restore it.")
            } catch { preserveCorruptFile(backupURL) }
        }
        for (id, record) in invalid {
            if let previous = backup?.completed[id], isValidCompletion(previous, for: id) {
                document.completed[id] = previous
                appendNotice("Some completed records failed a rule check and were restored from the latest backup. Other progress is preserved.")
            } else {
                document.completed.removeValue(forKey: id)
                // Preserve the player's work as a hypothesis, never as an unlock.
                if let level = knownLevels[id], record.contentRevision == level.contentRevision,
                   document.drafts[id] == nil {
                    let draft = Draft(levelID: id, contentRevision: level.contentRevision,
                                      board: record.board.map { Optional($0) }, notes: record.notes,
                                      hintCount: record.hintCount, testimonyMarks: record.testimonyMarks,
                                      undoStack: [], lastUsed: record.lastPlayedAt)
                    document.drafts[id] = GameSession(level: level, draft: draft).makeDraft()
                    appendNotice("Some completed records failed a rule check and were kept as drafts. Check them again to return them to your collection.")
                } else {
                    appendNotice("Some completed card records are damaged and cannot be restored. Other progress is preserved.")
                }
            }
        }
        // The original is retained in .damaged. Do not rotate semantically invalid
        // bytes over a valid backup on the next normal save.
        lastGoodData = try? JSONEncoder().encode(document)
    }

    private func isValidCompletion(_ record: CompletionRecord, for id: String) -> Bool {
        guard id == record.levelID, record.contentRevision > 0, !record.board.isEmpty,
              Set(record.board).count == record.board.count else { return false }
        // Historic completions survive content edits. Only a matching revision can
        // be replayed or checked against today's evidence and rules.
        guard let level = knownLevels[id], record.contentRevision == level.contentRevision else { return true }
        return RuleEngine.evaluate(level: level, board: record.board.map { Optional($0) }).accepted
    }

    private func appendNotice(_ message: String) {
        guard !(storedNotice?.contains(message) ?? false) else { return }
        storedNotice = [storedNotice, message].compactMap { $0 }.joined(separator: "\n")
    }

    private func preserveCorruptFile(_ url: URL) {
        let preserved = directory.appendingPathComponent("\(url.lastPathComponent).damaged")
        // Never discard the earliest failed file during repeated recovery attempts.
        if !FileManager.default.fileExists(atPath: preserved.path) {
            try? FileManager.default.copyItem(at: url, to: preserved)
        }
    }

    private func writeDocument() -> Bool {
        guard !protectedNewerVersion else {
            storedError = "This save is from a newer version. Progress was not written, to protect the original file."
            return false
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(document)
            guard data.count <= Self.maximumFileSize else {
                storedError = "The save is too large. Your previous progress has not been overwritten."
                return false
            }
            // Both writes are atomic. A crash between them still leaves a valid primary
            // or backup. Never rotate unvalidated on-disk bytes into the good backup.
            try (lastGoodData ?? data).write(to: backupURL, options: .atomic)
            try data.write(to: primaryURL, options: .atomic)
            lastGoodData = data
            storedError = nil
            return true
        } catch {
            storedError = "Progress could not be saved. Please check available storage and try again."
            return false
        }
    }
}
