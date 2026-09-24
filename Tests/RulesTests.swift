import Foundation

@main
enum RulesTests {
    private static var checks = 0
    private static func expect(_ condition: @autoclosure () -> Bool, _ label: String, file: StaticString = #file, line: UInt = #line) {
        checks += 1
        guard condition() else { fatalError("FAIL: \(label) (\(file):\(line))") }
    }

    static func fixture(facts: [Evidence]? = nil, testimonies: [Evidence] = [], falseCount: Int = 0,
                        author: [String] = ["S5", "S9", "H3", "S2", "H7", "H10"]) -> Level {
        Level(schemaVersion: 1, contentRevision: 1, id: "test.sample", chapterID: "test", number: 1,
              title: "六张牌原始示例", subtitle: "测试", story: "", rules: Rules(id: "follow_suit_no_trump", version: 1, players: ["A", "B", "C"], firstLeader: "A", roundCount: 2),
              cards: ["S2", "S5", "S9", "H3", "H7", "H10"].map { Card(id: $0) },
              facts: facts ?? [
                Evidence(id: "f1", text: "第一轮 A 出黑桃 5", constraint: Constraint(kind: "cardPlayed", round: 1, player: "A", card: "S5")),
                Evidence(id: "f2", text: "第一轮 C 出红桃 3", constraint: Constraint(kind: "cardPlayed", round: 1, player: "C", card: "H3")),
                Evidence(id: "f3", text: "第一轮 B 获胜", constraint: Constraint(kind: "roundWinner", round: 1, player: "B")),
                Evidence(id: "f4", text: "第二轮领出红桃 7", constraint: Constraint(kind: "leadCard", round: 2, card: "H7"))
              ], falseTestimonyCount: falseCount, testimonies: testimonies, hints: [],
              authorSolution: AuthorSolution(plays: author, falseTestimonyIDs: [], explanation: "作者内容不参与校验"))
    }

    static func main() throws {
        let sample = fixture()
        let solved: [String?] = ["S5", "S9", "H3", "S2", "H7", "H10"]
        expect(RuleEngine.validateStructure(level: sample).isEmpty, "sample schema")
        let good = RuleEngine.evaluate(level: sample, board: solved)
        expect(good.complete && good.accepted && good.issues.isEmpty, "exact six-card example accepted")
        expect(good.winners[1] == "B" && good.winners[2] == "C", "no-trump winners")
        expect(good.leaders[1] == "A" && good.leaders[2] == "B", "winner becomes leader")
        expect(good.events.map { $0.player } == ["A", "B", "C", "B", "C", "A"], "replay follows cyclic seating, not fixed slot order")
        expect(good.events.map { $0.card } == ["S5", "S9", "H3", "H7", "H10", "S2"], "replay uses chronological cards")
        expect(good.events[2].winner == "B" && good.events[5].winner == "C", "winner attached to round-final event")
        expect(good.events[1].winner == nil, "winner is not announced before round ends")
        expect(good.events[5].explanation.contains("垫牌不参与争胜"), "off-suit explanation")
        let counted = SolutionCounter.count(level: sample)
        expect(counted.count == 1 && counted.exhausted, "exact original product example has proven unique solution")
        expect(counted.solutions.first == solved.compactMap { $0 }, "solver solution matches derivation")

        let initial = RuleEngine.evaluate(level: sample, board: sample.initialBoard)
        expect(!initial.complete && !initial.accepted && initial.issues.isEmpty, "incomplete is neutral")
        expect(initial.evidence.first { $0.id == "f3" }?.truth == .unknown, "public winner not circularly marked checked")
        expect(initial.leaders[2] == "B", "credible public winner can establish following leader")
        expect(initial.winners[1] == nil, "incomplete actual winner not invented")
        let empty = RuleEngine.evaluate(level: fixture(facts: []), board: [nil, nil, nil, nil, nil, nil])
        expect(empty.issues.isEmpty && empty.leaders[2] == nil && empty.events.isEmpty, "missing prior round keeps next order unknown")
        let partial: [String?] = ["S5", nil, "H3", nil, nil, nil]
        expect(RuleEngine.evaluate(level: sample, board: partial).issues.isEmpty, "unknown future hand is not a revoke")
        let revoke: [String?] = ["S5", nil, "H3", nil, nil, "S2"]
        let revokeResult = RuleEngine.evaluate(level: sample, board: revoke)
        expect(revokeResult.issues.contains { $0.slots == [2, 5] && $0.message.contains("必须跟随") }, "future assigned same-suit card proves failure to follow")
        expect(!RuleEngine.evaluate(level: sample, board: ["S5", "S9", "H3", "H10", "H7", "S2"]).accepted, "complete revoke rejected")

        let free = fixture(facts: [])
        let offSuitHigh = RuleEngine.evaluate(level: free, board: ["S5", "S2", "H10", "S9", "H3", "H7"])
        expect(offSuitHigh.accepted && offSuitHigh.winners[1] == "A", "higher rank of wrong suit cannot win")
        let contradictedWinner = RuleEngine.evaluate(level: sample, board: ["S9", "S5", "H3", "S2", "H7", "H10"])
        expect(contradictedWinner.leaders[2] == "A", "actual winner overrides contradicted public claim")
        expect(contradictedWinner.evidence.first { $0.id == "f3" }?.truth == .contradicted, "false reliable winner is detected")
        let partialContradiction = RuleEngine.evaluate(level: sample, board: ["S9", "S5", nil, nil, nil, nil])
        expect(partialContradiction.leaders[2] == nil, "impossible public winner does not propagate on partial board")
        expect(partialContradiction.evidence.first { $0.id == "f3" }?.truth == .contradicted, "larger played card refutes partial winner")
        let offSuitWinner = RuleEngine.truth(of: Constraint(kind: "roundWinner", round: 1, player: "C"), level: free, board: ["S5", nil, "H3", nil, nil, nil])
        expect(offSuitWinner == .contradicted, "off-suit player cannot win even before completion")

        expect(RuleEngine.truth(of: Constraint(kind: "owner", player: "A", card: "S2"), level: sample, board: solved) == .satisfied, "ownership based on slots")
        expect(RuleEngine.truth(of: Constraint(kind: "owner", player: "C", card: "S2"), level: sample, board: partial) == .unknown, "unplaced ownership unknown")
        expect(RuleEngine.truth(of: Constraint(kind: "playedSuit", round: 2, player: "B", suit: "H"), level: sample, board: solved) == .satisfied, "played suit constraint")
        expect(RuleEngine.truth(of: Constraint(kind: "cardPlayed", round: 2, player: "A", card: "S5"), level: sample, board: partial) == .contradicted, "card already elsewhere refutes placement")
        expect(RuleEngine.truth(of: Constraint(kind: "leadCard", round: 2, card: "S5"), level: sample, board: partial) == .contradicted, "card in another round cannot lead")
        expect(!RuleEngine.evaluate(level: sample, board: ["S5", "S5", "H3", nil, nil, nil]).issues.isEmpty, "duplicate cards rejected")
        expect(!RuleEngine.evaluate(level: sample, board: ["C14", nil, nil, nil, nil, nil]).issues.isEmpty, "unknown card rejected")
        expect(!RuleEngine.evaluate(level: sample, board: [nil]).complete, "wrong board size handled safely")
        expect(RuleEngine.truth(of: Constraint(kind: "cardPlayed", round: 0, player: "A", card: "S5"), level: sample, board: solved) == .unknown, "invalid arbitrary constraint is safe")

        let testimonies = [
            Evidence(id: "t1", text: "黑桃 2 属于 A", constraint: Constraint(kind: "owner", player: "A", card: "S2")),
            Evidence(id: "t2", text: "第一轮 C 获胜", constraint: Constraint(kind: "roundWinner", round: 1, player: "C"))
        ]
        let suspect = fixture(testimonies: testimonies, falseCount: 1)
        let suspectResult = RuleEngine.evaluate(level: suspect, board: solved)
        expect(suspectResult.accepted, "exactly one false testimony accepted")
        expect(suspectResult.evidence.filter { $0.isTestimony && $0.truth == .contradicted }.map { $0.id } == ["t2"], "false testimony identity is derived")
        expect(RuleEngine.evaluate(level: suspect, board: partial).issues.isEmpty, "one known false testimony is allowed under one-false policy")
        expect(!RuleEngine.evaluate(level: fixture(testimonies: testimonies, falseCount: 0), board: partial).issues.isEmpty, "false testimony lower bound enforced")
        expect(!RuleEngine.evaluate(level: fixture(testimonies: testimonies, falseCount: 2), board: solved).accepted, "false testimony upper bound enforced")
        let merelyClaimed = fixture(facts: [], testimonies: [Evidence(id: "t", text: "B 赢第一轮", constraint: Constraint(kind: "roundWinner", round: 1, player: "B"))], falseCount: 0)
        expect(RuleEngine.evaluate(level: merelyClaimed, board: [nil, nil, nil, nil, nil, nil]).leaders[2] == nil, "suspect claims never establish public order")

        let multi = SolutionCounter.count(level: free)
        expect(multi.count == 2 && !multi.exhausted, "second solution proves nonunique, stopping is explicit")
        let conflicting = fixture(facts: sample.facts + [Evidence(id: "conflict", text: "A 出黑桃 9", constraint: Constraint(kind: "cardPlayed", round: 1, player: "A", card: "S9"))])
        let noSolution = SolutionCounter.count(level: conflicting)
        expect(noSolution.count == 0 && noSolution.exhausted, "contradicting reliable facts prove no solution")
        let timedOut = SolutionCounter.count(level: free, timeLimit: 0)
        expect(timedOut.count == 0 && !timedOut.exhausted, "timeout is never called unique or exhaustive")
        let unsupported = fixture(facts: [Evidence(id: "bad", text: "", constraint: Constraint(kind: "executeScript"))])
        expect(!RuleEngine.validateStructure(level: unsupported).isEmpty, "unknown constraint rejected at loading")
        expect(!RuleEngine.evaluate(level: unsupported, board: solved).accepted, "invalid content cannot be accepted")
        let wrongAuthor = fixture(author: ["intentionally-invalid-author-answer"])
        expect(RuleEngine.evaluate(level: wrongAuthor, board: solved).accepted, "runtime evaluation never consults author solution")
        let independent = SolutionCounter.count(level: wrongAuthor)
        expect(independent.count == 1 && independent.exhausted && independent.solutions == counted.solutions, "solver never consults author solution")

        // Cross-check every six-card permutation against a deliberately simple, independent
        // rules implementation. Every subset of every legal game must stay contradiction-free.
        func independentlyLegal(_ cards: [String]) -> Bool {
            var leader = 0
            for round in 0..<2 {
                let lead = Card(id: cards[round * 3 + leader])
                var winner = leader
                for player in 0..<3 {
                    let played = Card(id: cards[round * 3 + player])
                    if round == 0 && played.suit != lead.suit && Card(id: cards[3 + player]).suit == lead.suit { return false }
                    if played.suit == lead.suit && played.rank > Card(id: cards[round * 3 + winner]).rank { winner = player }
                }
                leader = winner
            }
            return true
        }
        var permutations = 0
        var legalPermutations = 0
        var deck = free.cards.map { $0.id }
        func enumerate(_ index: Int) {
            if index == deck.count {
                permutations += 1
                let legal = independentlyLegal(deck)
                expect(RuleEngine.evaluate(level: free, board: deck.map(Optional.some)).accepted == legal, "independent full-game parity: \(deck)")
                if legal {
                    legalPermutations += 1
                    for mask in 0..<(1 << deck.count) {
                        let hypothesis: [String?] = deck.enumerated().map { (mask & (1 << $0.offset)) == 0 ? nil : $0.element }
                        expect(RuleEngine.evaluate(level: free, board: hypothesis).issues.isEmpty, "legal completion never gives a partial contradiction: \(deck), mask \(mask)")
                    }
                }
                return
            }
            for other in index..<deck.count {
                deck.swapAt(index, other)
                enumerate(index + 1)
                deck.swapAt(index, other)
            }
        }
        enumerate(0)
        expect(permutations == 720 && legalPermutations > 1, "all six-card permutations enumerated")
        let allSolutions = SolutionCounter.count(level: free, limit: 1000, timeLimit: 30)
        expect(allSolutions.exhausted && allSolutions.count == legalPermutations, "solver pruning preserves every legal six-card solution")

        let threeRoundCards = ["S5", "S9", "H3", "S2", "H7", "H10", "C9", "C2", "C5"]
        let threeRound = Level(schemaVersion: 1, contentRevision: 1, id: "test.three", chapterID: "test", number: 2,
                               title: "三轮", subtitle: "", story: "", rules: Rules(id: "follow_suit_no_trump", version: 1, players: ["A", "B", "C"], firstLeader: "A", roundCount: 3),
                               cards: threeRoundCards.map { Card(id: $0) }, facts: [], falseTestimonyCount: 0, testimonies: [], hints: [],
                               authorSolution: AuthorSolution(plays: [], falseTestimonyIDs: [], explanation: ""))
        let threeResult = RuleEngine.evaluate(level: threeRound, board: threeRoundCards.map(Optional.some))
        expect(threeResult.accepted && threeResult.winners[3] == "A", "three-round hand depletion")
        expect(threeResult.events.map { $0.player } == ["A", "B", "C", "B", "C", "A", "C", "A", "B"], "three-round seating rotation")

        let prototypeFirst = fixture(facts: sample.facts + [Evidence(id: "fixed-next-lead", text: "第二轮 B 出红桃 7", constraint: Constraint(kind: "cardPlayed", round: 2, player: "B", card: "H7"))])
        let game = GameSession(level: prototypeFirst)
        expect(game.pool.count == 3 && RuleEngine.evaluate(level: prototypeFirst, board: game.board).issues.isEmpty, "prototype first level starts with three playable cards")
        expect(game.move(card: "S9", to: 1), "first-level tap-to-place first move")
        expect(RuleEngine.evaluate(level: prototypeFirst, board: game.board).winners[1] == "B", "placing first winner computes next-round order")
        expect(game.move(card: "S2", to: 5) && game.move(card: "H10", to: 3), "first-level wrong remainder is still editable")
        let incorrectGame = RuleEngine.evaluate(level: prototypeFirst, board: game.board)
        expect(incorrectGame.complete && !incorrectGame.accepted && incorrectGame.events.count == 6, "incorrect complete game still supports full replay")
        expect(incorrectGame.events.contains { $0.slot == 2 && $0.explanation.contains("必须跟随花色") }, "replay locates the proven rule violation at the offending play")
        expect(game.move(card: "S2", to: 3), "board-to-board swap corrects first level")
        expect(RuleEngine.evaluate(level: prototypeFirst, board: game.board).accepted, "first-level three moves and swap close the game")
        let resumedGame = GameSession(level: prototypeFirst, draft: game.makeDraft())
        expect(RuleEngine.evaluate(level: prototypeFirst, board: resumedGame.board).accepted, "resumed first-level completion rederives acceptance")
        expect(resumedGame.undo() && !RuleEngine.evaluate(level: prototypeFirst, board: resumedGame.board).accepted, "undo after restore restores prior incorrect hypothesis")

        // Optional bundled-content check; separate author tooling also checks hint implications.
        if CommandLine.arguments.count > 1 {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let levels = try JSONDecoder().decode([Level].self, from: data)
            for level in levels {
                expect(RuleEngine.validateStructure(level: level).isEmpty, "\(level.id): valid schema")
                let answer = level.authorSolution.plays.map(Optional.some)
                let evaluation = RuleEngine.evaluate(level: level, board: answer)
                expect(evaluation.accepted, "\(level.id): author answer follows rules")
                let result = SolutionCounter.count(level: level, timeLimit: 30)
                expect(result.count == 1 && result.exhausted, "\(level.id): proven unique")
                expect(result.solutions.first == level.authorSolution.plays, "\(level.id): author answer matches unique solution")
                let session = GameSession(level: level)
                for slot in level.authorSolution.plays.indices.reversed() where level.fixedPlays[slot] == nil {
                    expect(session.move(card: level.authorSolution.plays[slot], to: slot), "\(level.id): editable position accepts move")
                    expect(RuleEngine.evaluate(level: level, board: session.board).issues.isEmpty, "\(level.id): legal partial move remains neutral")
                }
                let played = RuleEngine.evaluate(level: level, board: session.board)
                expect(played.accepted && played.events.count == level.slotCount, "\(level.id): session to full replay closes")
                expect(Set(played.events.map { $0.slot }).count == level.slotCount, "\(level.id): every slot appears once in replay")
                expect(played.events.filter { $0.winner != nil }.count == level.rules.roundCount, "\(level.id): each replay round announces its winner once")
            }
            print("Validated \(levels.count) bundled levels.")
        }
        print("PASS: \(checks) rule, solver, replay, and partial-evidence checks.")
    }
}
