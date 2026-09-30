import Foundation

struct Card: Codable, Hashable {
    let id: String
    var suit: String { String(id.prefix(1)) }
    var rank: Int { Int(id.dropFirst()) ?? 0 }
    var symbol: String { ["S": "♠", "H": "♥", "D": "♦", "C": "♣"][suit] ?? "?" }
    var suitName: String { ["S": "spades", "H": "hearts", "D": "diamonds", "C": "clubs"][suit] ?? "Unknown" }
    var label: String { "\(symbol)\(rank)" }
    var spoken: String { "\(rank) of \(suitName)" }
    var isRed: Bool { suit == "H" || suit == "D" }
}

struct Rules: Codable {
    let id: String
    let version: Int
    let players: [String]
    let firstLeader: String
    let roundCount: Int
}

// Slot indices are round-major, in fixed seating order, independent of derived play order.
// All constraint round numbers are ONE-based. No script execution in content.
struct Constraint: Codable, Equatable {
    let kind: String // cardPlayed, roundWinner, leadCard, owner, playedSuit
    var round: Int? = nil
    var player: String? = nil
    var card: String? = nil
    var suit: String? = nil
}

struct Evidence: Codable {
    let id: String
    let text: String
    let constraint: Constraint
}
struct Hint: Codable {
    let title: String
    let text: String
    let evidenceIDs: [String]
    // Optional mathematically checkable conclusion; text is editorial.
    let conclusion: Constraint?
}
struct AuthorSolution: Codable {
    let plays: [String]
    let falseTestimonyIDs: [String]
    let explanation: String
}
struct Level: Codable {
    let schemaVersion: Int
    let contentRevision: Int
    let id: String
    let chapterID: String
    let number: Int
    let title: String
    let subtitle: String
    let story: String
    let rules: Rules
    let cards: [Card]
    let facts: [Evidence]
    let falseTestimonyCount: Int
    let testimonies: [Evidence]
    let hints: [Hint]
    let authorSolution: AuthorSolution

    var slotCount: Int { rules.players.count * rules.roundCount }
    func slot(round: Int, player: String) -> Int? {
        guard (1...rules.roundCount).contains(round), let p = rules.players.firstIndex(of: player) else { return nil }
        return (round - 1) * rules.players.count + p
    }
    var fixedPlays: [Int: String] {
        var result: [Int: String] = [:]
        for fact in facts where fact.constraint.kind == "cardPlayed" {
            if let r = fact.constraint.round, let p = fact.constraint.player,
               let c = fact.constraint.card, let s = slot(round: r, player: p) { result[s] = c }
        }
        return result
    }
    var initialBoard: [String?] {
        var result = [String?](repeating: nil, count: slotCount)
        for (s, c) in fixedPlays { result[s] = c }
        return result
    }
}

enum Truth: String { case satisfied, contradicted, unknown }
struct RuleIssue {
    let message: String
    let slots: [Int]
    let evidenceID: String?
}
struct EvidenceResult {
    let id: String
    let text: String
    let truth: Truth
    let isTestimony: Bool
}
struct ReplayEvent {
    let round: Int
    let player: String
    let card: String
    let slot: Int
    let leader: String
    let winner: String? // present on final play of the round
    let explanation: String
}
struct Evaluation {
    let complete: Bool
    let accepted: Bool
    let issues: [RuleIssue]
    let evidence: [EvidenceResult]
    let events: [ReplayEvent]
    let leaders: [Int: String] // round number -> derivable leader
    let winners: [Int: String]
}
