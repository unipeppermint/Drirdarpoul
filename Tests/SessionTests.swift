import Foundation

@main
struct SessionTests {
    private static var checks = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else { fatalError("FAILED: \(message)") }
    }

    static func fixture(revision: Int = 1) -> Level {
        Level(schemaVersion: 1, contentRevision: revision, id: "test.six", chapterID: "test", number: 1,
              title: "六张牌", subtitle: "测试", story: "纸上推理",
              rules: Rules(id: "follow_suit_no_trump", version: 1, players: ["A", "B", "C"], firstLeader: "A", roundCount: 2),
              cards: ["S5", "S9", "S2", "H3", "H10", "H7"].map { Card(id: $0) },
              facts: [Evidence(id: "f1", text: "A 第一轮 S5", constraint: Constraint(kind: "cardPlayed", round: 1, player: "A", card: "S5"))],
              falseTestimonyCount: 0,
              testimonies: [Evidence(id: "t1", text: "B 第一轮获胜", constraint: Constraint(kind: "roundWinner", round: 1, player: "B"))],
              hints: [Hint(title: "观察", text: "关注可靠记录", evidenceIDs: ["f1"], conclusion: nil),
                      Hint(title: "推导", text: "B 必须击败 S5", evidenceIDs: ["t1"], conclusion: nil)],
              authorSolution: AuthorSolution(plays: ["S5", "S9", "S2", "H3", "H10", "H7"], falseTestimonyIDs: [], explanation: "测试"))
    }

    static func replacingCompletedBoard(in data: Data, id: String, board: [String]) throws -> Data {
        var payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var completed = payload["completed"] as! [String: Any]
        var record = completed[id] as! [String: Any]
        record["board"] = board
        completed[id] = record
        payload["completed"] = completed
        return try JSONSerialization.data(withJSONObject: payload)
    }

    static func main() throws {
        let level = fixture()
        let session = GameSession(level: level)
        expect(session.board == ["S5", nil, nil, nil, nil, nil], "fixed card initializes in place")
        expect(session.pool.count == 5, "initial pool excludes fixed cards")
        expect(!session.move(card: "S5", to: 1), "fixed card cannot move")
        expect(!session.move(card: "S9", to: 0), "fixed slot rejects another card")
        expect(!session.move(card: "S9", to: -1), "negative slot rejected")
        expect(!session.move(card: "S9", to: 6), "out-of-range slot rejected")
        expect(!session.move(card: "X99", to: 1), "unknown card rejected")
        expect(!session.canUndo, "rejected actions do not create undo history")
        expect(session.move(card: "S9", to: 1), "pool placement works")
        expect(!session.move(card: "S9", to: 1), "same position is a no-op")
        expect(session.move(card: "H3", to: 2), "second card placement works")
        expect(session.move(card: "S9", to: 2), "board swap works")
        expect(session.board[1] == "H3" && session.board[2] == "S9", "swap preserves both cards")
        expect(session.move(card: "H7", to: 2), "pool replacement works")
        expect(session.pool.contains { $0.id == "S9" }, "pool replacement returns old card to pool")
        expect(Set(session.board.compactMap { $0 }).count == session.board.compactMap { $0 }.count, "no duplicate card after moves")
        expect(session.undo(), "undo replacement works")
        expect(session.board[2] == "S9", "undo restores board exactly")
        expect(session.move(card: "H3", to: nil), "return to pool works")
        expect(session.board[1] == nil, "returned card vacates slot")
        expect(session.undo() && session.board[1] == "H3", "undo return restores card")
        session.notes = "先检查领出者。"
        session.testimonyMarks = ["t1": "false", "unknown-id": "true"]
        expect(session.testimonyMarks == ["t1": "false"], "unknown testimony mark removed")
        expect(session.useHint() != nil && session.hintCount == 1, "hint increments independently")
        expect(session.undo() && session.testimonyMarks.isEmpty, "testimony hypotheses undo")
        expect(session.hintCount == 1, "undo never unread a hint")
        expect(session.undo() && session.notes.isEmpty, "notes undo")
        _ = session.useHint()
        expect(session.useHint() == nil && session.hintCount == 2, "hints stop at available count")

        for index in 0..<100 { session.notes = "笔记 \(index)" }
        expect(session.undoStack.count == GameSession.undoLimit, "undo history stays bounded")
        session.notes = String(repeating: "纸", count: 12_000)
        expect(session.notes.count == GameSession.noteLimit, "notes stay bounded")
        let restored = GameSession(level: level, draft: session.makeDraft())
        expect(restored.board == session.board && restored.notes == session.notes, "draft restores board and notes")
        expect(restored.undoStack == session.undoStack && restored.hintCount == session.hintCount, "draft restores undo and hints")
        expect(GameSession(level: fixture(revision: 2), draft: session.makeDraft()).board == level.initialBoard, "revision mismatch starts fresh")

        let bad = Draft(levelID: level.id, contentRevision: 1, board: ["H7", "S5", "S9", "S9", "X", "H3", "S2"],
                        notes: "保留笔记", hintCount: 100, testimonyMarks: ["t1": "invalid"],
                        undoStack: [SessionSnapshot(board: ["X"], notes: "", testimonyMarks: [:])], lastUsed: Date())
        let repaired = GameSession(level: level, draft: bad)
        expect(repaired.board == ["S5", nil, "S9", nil, nil, "H3"], "invalid draft repairs fixed, duplicate, unknown and extra cards")
        expect(repaired.undoStack.isEmpty && repaired.hintCount == 2 && repaired.testimonyMarks.isEmpty, "invalid history and metadata repaired")

        let testRoot = FileManager.default.temporaryDirectory.appendingPathComponent("card-trace-session-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: testRoot) }
        let dir = testRoot.appendingPathComponent("normal")
        let store = SaveRepository(levels: [level], directory: dir)
        let first = GameSession(level: level)
        _ = first.move(card: "S9", to: 1)
        store.updateDraft(first.makeDraft())
        expect(store.saveNow(), "first atomic save succeeds")
        let reopened = SaveRepository(levels: [level], directory: dir)
        expect(reopened.draft(for: level)?.board == first.board, "saved board survives reopen")
        expect(reopened.draft(for: level)?.undoStack.count == 1 && reopened.currentLevelID == level.id, "undo and current level survive reopen")
        _ = first.move(card: "H3", to: 2)
        store.updateDraft(first.makeDraft())
        expect(store.saveNow(), "second save succeeds")
        let primary = dir.appendingPathComponent("progress.json")
        try Data("corrupt".utf8).write(to: primary)
        let backupRecovery = SaveRepository(levels: [level], directory: dir)
        expect(backupRecovery.draft(for: level)?.board == ["S5", "S9", nil, nil, nil, nil], "corrupt primary recovers prior valid backup")
        expect(backupRecovery.notice?.contains("备份") == true, "backup recovery informs player")
        expect(FileManager.default.fileExists(atPath: primary.path + ".damaged"), "corrupt bytes preserved")
        expect(backupRecovery.saveNow(), "recovered store can save safely")

        let autoDir = testRoot.appendingPathComponent("autosave")
        let autoStore = SaveRepository(levels: [level], directory: autoDir)
        first.notes = "下一轮先检查跟花。"
        first.testimonyMarks = ["t1": "true"]
        _ = first.useHint()
        autoStore.updateDraft(first.makeDraft())
        _ = first.move(card: "H7", to: 4)
        autoStore.updateDraft(first.makeDraft())
        Thread.sleep(forTimeInterval: 0.7)
        let autoRestored = SaveRepository(levels: [level], directory: autoDir)
        expect(autoRestored.draft(for: level)?.board == first.board, "coalesced autosave writes the newest move without lifecycle callback")
        expect(autoRestored.draft(for: level)?.notes == first.notes && autoRestored.draft(for: level)?.testimonyMarks == first.testimonyMarks, "notes and testimony hypotheses survive autosave")
        expect(autoRestored.draft(for: level)?.hintCount == 1, "hint reading survives autosave")

        let revisionDir = testRoot.appendingPathComponent("revision")
        let revisionStore = SaveRepository(levels: [level], directory: revisionDir)
        expect(revisionStore.complete(level: level, board: level.authorSolution.plays, notes: "完成", hintCount: 1, testimonyMarks: ["t1": "true"]), "completion reports successful durable write")
        expect(revisionStore.completed[level.id]?.board == level.authorSolution.plays, "accepted reconstruction retained for replay")
        expect(revisionStore.drafts[level.id] == nil, "completion removes the previous draft")
        revisionStore.updateDraft(first.makeDraft())
        expect(revisionStore.saveNow(), "draft resave after completion")
        let revised = SaveRepository(levels: [fixture(revision: 2)], directory: revisionDir)
        expect(revised.drafts[level.id] == nil, "content revision resets only incompatible draft")
        expect(revised.completed[level.id]?.notes == "完成", "content revision preserves completion and notes")
        expect(revised.notice?.contains("内容已更新") == true, "revision reset explains reason")

        let invalidFollowSuit = ["S5", "H3", "S2", "H7", "S9", "H10"]
        let invalidTestimony = ["S5", "S2", "S9", "H3", "H7", "H10"]
        let semanticStore = SaveRepository(levels: [level], directory: testRoot.appendingPathComponent("semantic-writes"))
        expect(!semanticStore.complete(level: level, board: invalidFollowSuit, notes: "不能归档", hintCount: 0), "complete rejects structurally valid follow-suit violation")
        expect(!semanticStore.complete(level: level, board: invalidTestimony, notes: "不能归档", hintCount: 0), "complete rejects a board with wrong testimony count")
        expect(semanticStore.completed.isEmpty, "rejected semantic completions never unlock progress")
        let alternateValid = ["S5", "S9", "S2", "H7", "H10", "H3"]
        expect(semanticStore.complete(level: level, board: alternateValid, notes: "公开条件成立", hintCount: 0, testimonyMarks: ["t1": "false"]), "complete accepts public-rule-valid alternative independently of author answer and personal marks")
        expect(semanticStore.completed[level.id]?.board == alternateValid, "accepted alternative is the exact replay board")

        let semanticDir = testRoot.appendingPathComponent("semantic-recovery")
        try FileManager.default.createDirectory(at: semanticDir, withIntermediateDirectories: true)
        let validCompletionData = try Data(contentsOf: revisionDir.appendingPathComponent("progress.json"))
        let invalidCompletionData = try replacingCompletedBoard(in: validCompletionData, id: level.id, board: invalidFollowSuit)
        try invalidCompletionData.write(to: semanticDir.appendingPathComponent("progress.json"))
        try validCompletionData.write(to: semanticDir.appendingPathComponent("progress.backup.json"))
        let semanticRecovery = SaveRepository(levels: [level], directory: semanticDir)
        expect(semanticRecovery.completed[level.id]?.board == level.authorSolution.plays, "semantic corruption restores the individual valid backup record")
        expect(semanticRecovery.drafts[level.id]?.board == first.board, "completion recovery preserves unrelated current draft state")
        expect(semanticRecovery.notice?.contains("规则复核") == true, "semantic recovery explains why backup was needed")
        expect(semanticRecovery.saveNow(), "semantically recovered store can save")
        let semanticReopen = SaveRepository(levels: [level], directory: semanticDir)
        expect(semanticReopen.completed[level.id]?.board == level.authorSolution.plays, "repaired completion remains valid after another launch")

        let unrecoverableDir = testRoot.appendingPathComponent("semantic-no-backup")
        try FileManager.default.createDirectory(at: unrecoverableDir, withIntermediateDirectories: true)
        // Remove an unrelated current draft to verify recovery of the completion's own notes.
        var invalidPayload = try JSONSerialization.jsonObject(with: invalidCompletionData) as! [String: Any]
        invalidPayload["drafts"] = [String: Any]()
        let noBackupData = try JSONSerialization.data(withJSONObject: invalidPayload)
        try noBackupData.write(to: unrecoverableDir.appendingPathComponent("progress.json"))
        try noBackupData.write(to: unrecoverableDir.appendingPathComponent("progress.backup.json"))
        let semanticRejected = SaveRepository(levels: [level], directory: unrecoverableDir)
        expect(semanticRejected.completed.isEmpty, "invalid completion in both files cannot unlock a chapter")
        expect(semanticRejected.drafts[level.id]?.board == invalidFollowSuit && semanticRejected.drafts[level.id]?.notes == "完成", "unrecoverable completion is retained as a hypothesis with the player's notes")
        expect(semanticRejected.notice?.contains("推理草稿") == true, "demoted completion informs player")

        let futureDir = testRoot.appendingPathComponent("future")
        try FileManager.default.createDirectory(at: futureDir, withIntermediateDirectories: true)
        let futureURL = futureDir.appendingPathComponent("progress.json")
        let futureData = Data("{\"saveVersion\":999,\"unrecognizedPayload\":true}".utf8)
        try futureData.write(to: futureURL)
        let future = SaveRepository(levels: [level], directory: futureDir)
        future.updateDraft(first.makeDraft())
        expect(future.isReadOnly && !future.saveNow(), "future schema is write-protected")
        let preservedFutureData = try Data(contentsOf: futureURL)
        expect(preservedFutureData == futureData, "future file unchanged byte-for-byte")
        expect(future.lastError != nil && future.notice != nil, "future schema reports temporary progress limitation")
        expect(!future.complete(level: level, board: level.authorSolution.plays, notes: "临时完成", hintCount: 0), "completion reports a failed durable write in future-version mode")
        expect(future.completed[level.id] != nil, "failed durable completion can still support temporary in-memory replay")
        let validBackupData = try Data(contentsOf: autoDir.appendingPathComponent("progress.json"))
        try validBackupData.write(to: futureDir.appendingPathComponent("progress.backup.json"))
        let futureWithBackup = SaveRepository(levels: [level], directory: futureDir)
        expect(futureWithBackup.draft(for: level) != nil && futureWithBackup.isReadOnly, "older readable backup cannot remove future schema protection")
        expect(!futureWithBackup.saveNow(), "future primary remains protected after backup recovery")

        let migrationDir = testRoot.appendingPathComponent("migration")
        try FileManager.default.createDirectory(at: migrationDir, withIntermediateDirectories: true)
        var legacy = try JSONSerialization.jsonObject(with: validBackupData) as! [String: Any]
        legacy["saveVersion"] = 0
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        try legacyData.write(to: migrationDir.appendingPathComponent("progress.json"))
        let migration = SaveRepository(levels: [level], directory: migrationDir)
        expect(migration.draft(for: level)?.board == first.board && migration.notice?.contains("升级") == true, "supported old version migrates without losing state")
        expect(migration.saveNow(), "migrated document saves")
        let migrationBackup = try Data(contentsOf: migrationDir.appendingPathComponent("progress.backup.json"))
        expect(migrationBackup == legacyData, "first migrated save preserves original bytes as backup")

        let badDir = testRoot.appendingPathComponent("both-corrupt")
        try FileManager.default.createDirectory(at: badDir, withIntermediateDirectories: true)
        try Data("bad-main".utf8).write(to: badDir.appendingPathComponent("progress.json"))
        try Data("bad-backup".utf8).write(to: badDir.appendingPathComponent("progress.backup.json"))
        let failedRecovery = SaveRepository(levels: [level], directory: badDir)
        expect(failedRecovery.drafts.isEmpty && failedRecovery.notice != nil, "double corruption yields safe empty state with notice")
        failedRecovery.updateDraft(first.makeDraft())
        expect(failedRecovery.saveNow(), "fresh progress can be saved after double corruption")

        // A directory at the expected file path simulates an unwritable destination.
        let failureDir = testRoot.appendingPathComponent("write-failure")
        let failureStore = SaveRepository(levels: [level], directory: failureDir)
        try FileManager.default.createDirectory(at: failureDir.appendingPathComponent("progress.json"), withIntermediateDirectories: true)
        failureStore.updateDraft(first.makeDraft())
        expect(!failureStore.saveNow() && failureStore.lastError != nil, "write errors are surfaced")

        let domain = "card-trace-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let settings = Settings(defaults: defaults)
        expect(settings.hapticsEnabled && !settings.largerText, "settings sensible defaults")
        settings.hapticsEnabled = false
        settings.largerText = true
        let reloadedSettings = Settings(defaults: defaults)
        expect(!reloadedSettings.hapticsEnabled && reloadedSettings.largerText, "settings persist independently")

        if CommandLine.arguments.count > 1 {
            let shipped = try JSONDecoder().decode([Level].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            expect(shipped.count == 40, "integration covers all 40 shipped levels")
            let shippedDir = testRoot.appendingPathComponent("all-shipped-levels")
            let shippedStore = SaveRepository(levels: shipped, directory: shippedDir)
            for level in shipped {
                expect(shippedStore.complete(level: level, board: level.authorSolution.plays, notes: "档案 \(level.number)", hintCount: 0), "shipped level \(level.number) can be semantically completed and saved")
            }
            let shippedReload = SaveRepository(levels: shipped, directory: shippedDir)
            expect(shippedReload.completed.count == 40 && shippedReload.notice == nil, "all shipped completions restore without repair warnings")
            for level in shipped {
                let record = shippedReload.completed[level.id]!
                let replay = RuleEngine.evaluate(level: level, board: record.board.map { Optional($0) })
                expect(replay.accepted && replay.events.count == level.cards.count, "restored shipped level \(level.number) generates a full accepted replay through the same engine")
            }
        }

        print("PASS: \(checks) session, persistence, recovery, and settings checks")
    }
}
