import Foundation

struct SessionSnapshot: Codable, Equatable {
    let board: [String?]
    let notes: String
    let testimonyMarks: [String: String]
}

struct Draft: Codable {
    let levelID: String
    let contentRevision: Int
    let board: [String?]
    let notes: String
    let hintCount: Int
    let testimonyMarks: [String: String]
    let undoStack: [SessionSnapshot]
    let lastUsed: Date
}

/// The only mutable source of truth for a player's reconstruction.
/// All access is expected on the UI thread; derived rules never live here.
final class GameSession {
    static let undoLimit = 80
    static let noteLimit = 10_000

    let level: Level
    private(set) var board: [String?]
    private(set) var hintCount: Int
    private(set) var undoStack: [SessionSnapshot]
    private var storedNotes: String
    private var storedMarks: [String: String]

    var notes: String {
        get { storedNotes }
        set {
            let bounded = String(newValue.prefix(Self.noteLimit))
            guard bounded != storedNotes else { return }
            remember()
            storedNotes = bounded
        }
    }

    /// These are personal hypotheses, never authoritative evidence.
    var testimonyMarks: [String: String] {
        get { storedMarks }
        set {
            let cleaned = Self.cleanMarks(newValue, level: level)
            guard cleaned != storedMarks else { return }
            remember()
            storedMarks = cleaned
        }
    }

    var pool: [Card] {
        let placed = Set(board.compactMap { $0 })
        return level.cards.filter { !placed.contains($0.id) }
    }

    var canUndo: Bool { !undoStack.isEmpty }

    init(level: Level, draft: Draft? = nil) {
        self.level = level
        if let draft = draft,
           draft.levelID == level.id,
           draft.contentRevision == level.contentRevision {
            board = Self.repairBoard(draft.board, level: level)
            storedNotes = String(draft.notes.prefix(Self.noteLimit))
            storedMarks = Self.cleanMarks(draft.testimonyMarks, level: level)
            hintCount = max(0, min(draft.hintCount, level.hints.count))
            // A damaged undo entry must never resurrect an invalid arrangement.
            undoStack = Array(draft.undoStack.filter {
                Self.repairBoard($0.board, level: level) == $0.board &&
                $0.notes.count <= Self.noteLimit &&
                Self.cleanMarks($0.testimonyMarks, level: level) == $0.testimonyMarks
            }.suffix(Self.undoLimit))
        } else {
            board = level.initialBoard
            storedNotes = ""
            storedMarks = [:]
            hintCount = 0
            undoStack = []
        }
    }

    /// A pool replacement returns the previous card to the pool; board moves swap.
    /// A nil destination returns a player's card to the pool.
    @discardableResult
    func move(card: String, to target: Int?) -> Bool {
        guard level.cards.contains(where: { $0.id == card }),
              !level.fixedPlays.values.contains(card) else { return false }
        let source = board.firstIndex(where: { $0 == card })
        if let target = target {
            guard board.indices.contains(target), level.fixedPlays[target] == nil,
                  source != target else { return false }
            remember()
            if let source = source { board[source] = board[target] }
            board[target] = card
        } else {
            guard let source = source else { return false }
            remember()
            board[source] = nil
        }
        return true
    }

    @discardableResult
    func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        board = previous.board
        storedNotes = previous.notes
        storedMarks = previous.testimonyMarks
        return true
    }

    /// Reading a hint is deliberately independent of the undo history.
    @discardableResult
    func useHint() -> Hint? {
        guard hintCount < level.hints.count else { return nil }
        let hint = level.hints[hintCount]
        hintCount += 1
        return hint
    }

    func makeDraft() -> Draft {
        Draft(levelID: level.id, contentRevision: level.contentRevision,
              board: board, notes: storedNotes, hintCount: hintCount,
              testimonyMarks: storedMarks, undoStack: undoStack, lastUsed: Date())
    }

    private func remember() {
        undoStack.append(SessionSnapshot(board: board, notes: storedNotes, testimonyMarks: storedMarks))
        if undoStack.count > Self.undoLimit { undoStack.removeFirst(undoStack.count - Self.undoLimit) }
    }

    private static func cleanMarks(_ marks: [String: String], level: Level) -> [String: String] {
        let IDs = Set(level.testimonies.map { $0.id })
        return marks.filter { IDs.contains($0.key) && ["unknown", "true", "false"].contains($0.value) }
    }

    private static func repairBoard(_ proposed: [String?], level: Level) -> [String?] {
        var result = level.initialBoard
        let allowed = Set(level.cards.map { $0.id })
        var used = Set(result.compactMap { $0 })
        for slot in result.indices where level.fixedPlays[slot] == nil {
            guard proposed.indices.contains(slot), let card = proposed[slot],
                  allowed.contains(card), !used.contains(card) else { continue }
            result[slot] = card
            used.insert(card)
        }
        return result
    }
}
