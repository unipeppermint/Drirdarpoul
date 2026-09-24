import Foundation

struct SolutionCountResult {
    let count: Int
    let solutions: [[String]]
    /// True only when the entire search tree was explored, never on timeout or limit.
    let exhausted: Bool
    let visitedNodes: Int
}

/// Offline authoring tool. Mobile play only calls RuleEngine, never this search.
enum SolutionCounter {
    static func count(level: Level, limit: Int = 2, timeLimit: TimeInterval = 10) -> SolutionCountResult {
        guard RuleEngine.validateStructure(level: level).isEmpty else {
            return SolutionCountResult(count: 0, solutions: [], exhausted: true, visitedNodes: 0)
        }
        let started = Date()
        let effectiveLimit = max(1, limit)
        let players = level.rules.players
        var board = [String?](repeating: nil, count: level.slotCount)
        var domains = Array(repeating: Set(level.cards.map { $0.id }), count: level.slotCount)
        var publicLeaders: [Int: String] = [1: level.rules.firstLeader]
        for fact in level.facts where fact.constraint.kind == "roundWinner" {
            if let round = fact.constraint.round, let player = fact.constraint.player { publicLeaders[round + 1] = player }
        }
        for fact in level.facts {
            let c = fact.constraint
            switch c.kind {
            case "cardPlayed":
                if let round = c.round, let player = c.player, let card = c.card, let slot = level.slot(round: round, player: player) { domains[slot].formIntersection([card]) }
            case "owner":
                if let player = c.player, let card = c.card {
                    for slot in domains.indices where players[slot % players.count] != player { domains[slot].remove(card) }
                }
            case "playedSuit":
                if let round = c.round, let player = c.player, let suit = c.suit, let slot = level.slot(round: round, player: player) {
                    domains[slot] = domains[slot].filter { Card(id: $0).suit == suit }
                }
            case "leadCard":
                if let round = c.round, let card = c.card, let leader = publicLeaders[round], let slot = level.slot(round: round, player: leader) { domains[slot].formIntersection([card]) }
            default: break
            }
        }
        var solutions: [[String]] = []
        var visited = 0
        var stopped = false
        var used: Set<String> = []
        func search() {
            guard !stopped else { return }
            visited += 1
            if visited == 1 || visited % 128 == 0 {
                if timeLimit <= 0 || Date().timeIntervalSince(started) >= timeLimit { stopped = true; return }
            }
            let evaluation = RuleEngine.evaluateValidLevel(level: level, board: board, includeEvents: false)
            guard evaluation.issues.isEmpty else { return }
            if evaluation.complete {
                if evaluation.accepted {
                    solutions.append(board.compactMap { $0 })
                    if solutions.count >= effectiveLimit { stopped = true }
                }
                return
            }
            // Minimum remaining domain, with chronological slots as a deterministic tie break.
            var selected: Int?
            var candidates: Set<String> = []
            for slot in board.indices where board[slot] == nil {
                let available = domains[slot].subtracting(used)
                if available.isEmpty { return }
                if selected == nil || available.count < candidates.count { selected = slot; candidates = available }
            }
            guard let slot = selected else { return }
            for card in candidates.sorted() {
                board[slot] = card
                used.insert(card)
                search()
                used.remove(card)
                board[slot] = nil
                if stopped { return }
            }
        }
        search()
        return SolutionCountResult(count: solutions.count, solutions: solutions, exhausted: !stopped, visitedNodes: visited)
    }
}
