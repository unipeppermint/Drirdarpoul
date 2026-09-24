import Foundation

/// The only authority for play order, winners, legal plays, and evidence truth.
/// This type deliberately never reads an author's solution or hints.
enum RuleEngine {
    private struct RoundState {
        let number: Int
        let leader: String?
        let leadCard: Card?
        let winner: String?
    }

    static func validateStructure(level: Level) -> [String] {
        var errors: [String] = []
        let rules = level.rules
        if level.schemaVersion != 1 { errors.append("不支持的关卡结构版本。") }
        if level.contentRevision < 1 { errors.append("关卡修订号必须为正整数。") }
        if rules.id != "follow_suit_no_trump" || rules.version != 1 { errors.append("不支持的规则版本。") }
        if !(2...4).contains(rules.players.count) || Set(rules.players).count != rules.players.count || rules.players.contains(where: { $0.isEmpty }) {
            errors.append("座次必须包含 2 至 4 个不同的人物。")
        }
        if !rules.players.contains(rules.firstLeader) { errors.append("首轮领出者不在座次中。") }
        if !(1...8).contains(rules.roundCount) { errors.append("轮数必须在 1 至 8 之间。") }
        let expectedCards = rules.players.count.multipliedReportingOverflow(by: rules.roundCount)
        if expectedCards.overflow || level.cards.count != expectedCards.partialValue { errors.append("牌数与每人每轮一张的规则不符。") }
        let cardIDs = Set(level.cards.map { $0.id })
        if cardIDs.count != level.cards.count { errors.append("牌组包含重复的牌。") }
        if level.cards.contains(where: { !["S", "H", "D", "C"].contains($0.suit) || !(2...14).contains($0.rank) || $0.id != "\($0.suit)\($0.rank)" }) {
            errors.append("牌组包含无法识别的花色或点数。")
        }
        if level.falseTestimonyCount < 0 || level.falseTestimonyCount > level.testimonies.count { errors.append("错误证词数量超出范围。") }
        let evidence = level.facts + level.testimonies
        if Set(evidence.map { $0.id }).count != evidence.count || evidence.contains(where: { $0.id.isEmpty }) {
            errors.append("线索编号必须非空且唯一。")
        }
        func validConstraint(_ c: Constraint) -> Bool {
            let roundOK = c.round.map { $0 >= 1 && $0 <= rules.roundCount } ?? false
            let playerOK = c.player.map { rules.players.contains($0) } ?? false
            let cardOK = c.card.map { cardIDs.contains($0) } ?? false
            let suitOK = c.suit.map { ["S", "H", "D", "C"].contains($0) } ?? false
            switch c.kind {
            case "cardPlayed": return roundOK && playerOK && cardOK && c.suit == nil
            case "roundWinner": return roundOK && playerOK && c.card == nil && c.suit == nil
            case "leadCard": return roundOK && cardOK && c.player == nil && c.suit == nil
            case "owner": return playerOK && cardOK && c.round == nil && c.suit == nil
            case "playedSuit": return roundOK && playerOK && suitOK && c.card == nil
            default: return false
            }
        }
        for item in evidence where !validConstraint(item.constraint) { errors.append("线索 \(item.id) 的约束或引用无效。") }
        for (index, hint) in level.hints.enumerated() {
            if hint.evidenceIDs.contains(where: { id in !evidence.contains(where: { $0.id == id }) }) { errors.append("提示 \(index + 1) 引用了不存在的线索。") }
            if let conclusion = hint.conclusion, !validConstraint(conclusion) { errors.append("提示 \(index + 1) 的结论无效。") }
        }
        return errors
    }

    static func evaluate(level: Level, board: [String?]) -> Evaluation {
        let errors = validateStructure(level: level)
        guard errors.isEmpty else {
            return Evaluation(complete: false, accepted: false,
                              issues: errors.map { RuleIssue(message: $0, slots: [], evidenceID: nil) },
                              evidence: [], events: [], leaders: [:], winners: [:])
        }
        return evaluateValidLevel(level: level, board: board, includeEvents: true)
    }

    static func truth(of constraint: Constraint, level: Level, board: [String?]) -> Truth {
        guard validateStructure(level: level).isEmpty, board.count == level.slotCount else { return .unknown }
        let rounds = roundStates(level: level, board: board)
        return truth(of: constraint, level: level, board: board, rounds: rounds)
    }

    /// The solver validates immutable level data once, then uses this cheaper path.
    static func evaluateValidLevel(level: Level, board: [String?], includeEvents: Bool) -> Evaluation {
        guard board.count == level.slotCount else {
            return Evaluation(complete: false, accepted: false,
                              issues: [RuleIssue(message: "牌位数量与档案不符。", slots: [], evidenceID: nil)],
                              evidence: [], events: [], leaders: [:], winners: [:])
        }
        var issues: [RuleIssue] = []
        let cardIDs = Set(level.cards.map { $0.id })
        var firstSlot: [String: Int] = [:]
        for (slot, value) in board.enumerated() {
            guard let card = value else { continue }
            if !cardIDs.contains(card) { issues.append(RuleIssue(message: "这张牌不属于本档案的牌组。", slots: [slot], evidenceID: nil)) }
            if let earlier = firstSlot[card] {
                issues.append(RuleIssue(message: "同一张牌只能出现一次。", slots: [earlier, slot], evidenceID: nil))
            } else { firstSlot[card] = slot }
        }
        let rounds = roundStates(level: level, board: board)
        let playerCount = level.rules.players.count
        for state in rounds {
            guard let lead = state.leadCard else { continue }
            for (playerIndex, player) in level.rules.players.enumerated() {
                let slot = (state.number - 1) * playerCount + playerIndex
                guard let id = board[slot], Card(id: id).suit != lead.suit else { continue }
                // A player's cards in future rounds are still in that player's hand now.
                // Unknown cards never prove a revoke; only an explicitly placed card can.
                if state.number < level.rules.roundCount,
                   let later = ((state.number + 1)...level.rules.roundCount).map({ ($0 - 1) * playerCount + playerIndex }).first(where: {
                       board[$0].map { Card(id: $0).suit == lead.suit } ?? false
                   }) {
                    issues.append(RuleIssue(message: "第 \(state.number) 轮领出\(lead.suitName)，\(player) 手中仍有\(lead.suitName)，必须跟随花色。", slots: [slot, later], evidenceID: nil))
                }
            }
        }
        var evidence: [EvidenceResult] = []
        for fact in level.facts {
            let result = truth(of: fact.constraint, level: level, board: board, rounds: rounds)
            evidence.append(EvidenceResult(id: fact.id, text: fact.text, truth: result, isTestimony: false))
            if result == .contradicted {
                issues.append(RuleIssue(message: "与可靠线索冲突：\(fact.text)", slots: relatedSlots(fact.constraint, level: level, board: board), evidenceID: fact.id))
            }
        }
        var falseCount = 0
        var unknownCount = 0
        for testimony in level.testimonies {
            let result = truth(of: testimony.constraint, level: level, board: board, rounds: rounds)
            evidence.append(EvidenceResult(id: testimony.id, text: testimony.text, truth: result, isTestimony: true))
            if result == .contradicted { falseCount += 1 }
            if result == .unknown { unknownCount += 1 }
        }
        if falseCount > level.falseTestimonyCount || falseCount + unknownCount < level.falseTestimonyCount {
            issues.append(RuleIssue(message: "证词数量不符：档案要求恰有 \(level.falseTestimonyCount) 条错误证词；当前已有 \(falseCount) 条不成立、\(unknownCount) 条待核实。", slots: [], evidenceID: nil))
        }
        let complete = board.allSatisfy { $0 != nil }
        let accepted = complete && issues.isEmpty && evidence.allSatisfy { $0.truth != .unknown }
        var leaders: [Int: String] = [:]
        var winners: [Int: String] = [:]
        for round in rounds {
            if let leader = round.leader { leaders[round.number] = leader }
            if let winner = round.winner { winners[round.number] = winner }
        }
        let events = includeEvents ? replay(level: level, board: board, rounds: rounds, issues: issues) : []
        return Evaluation(complete: complete, accepted: accepted, issues: issues, evidence: evidence,
                          events: events, leaders: leaders, winners: winners)
    }

    private static func roundStates(level: Level, board: [String?]) -> [RoundState] {
        let players = level.rules.players
        var result: [RoundState] = []
        var leader: String? = level.rules.firstLeader
        for number in 1...level.rules.roundCount {
            let leadSlot = leader.flatMap { level.slot(round: number, player: $0) }
            let leadCard = leadSlot.flatMap { board[$0] }.map { Card(id: $0) }
            let slots = ((number - 1) * players.count)..<(number * players.count)
            var winner: String?
            if let lead = leadCard, slots.allSatisfy({ board[$0] != nil }) {
                let contenders = slots.filter { board[$0].map { Card(id: $0).suit == lead.suit } ?? false }
                if let winningSlot = contenders.max(by: { Card(id: board[$0]!).rank < Card(id: board[$1]!).rank }) {
                    winner = players[winningSlot % players.count]
                }
            }
            let state = RoundState(number: number, leader: leader, leadCard: leadCard, winner: winner)
            result.append(state)
            if let actual = winner {
                // The placed board takes precedence when it contradicts a public claim.
                leader = actual
            } else {
                let claims = level.facts.compactMap { evidence -> String? in
                    let c = evidence.constraint
                    guard c.kind == "roundWinner", c.round == number, let player = c.player,
                          winnerTruth(player: player, level: level, board: board, state: state) != .contradicted else { return nil }
                    return player
                }
                let unique = Set(claims)
                leader = unique.count == 1 ? unique.first : nil
            }
        }
        return result
    }

    private static func winnerTruth(player: String, level: Level, board: [String?], state: RoundState) -> Truth {
        guard level.rules.players.contains(player) else { return .unknown }
        if let winner = state.winner { return winner == player ? .satisfied : .contradicted }
        guard let lead = state.leadCard, let target = level.slot(round: state.number, player: player), let id = board[target] else { return .unknown }
        let card = Card(id: id)
        if card.suit != lead.suit { return .contradicted }
        let count = level.rules.players.count
        let slots = ((state.number - 1) * count)..<(state.number * count)
        if slots.contains(where: { slot in
            guard let other = board[slot].map({ Card(id: $0) }) else { return false }
            return other.suit == lead.suit && other.rank > card.rank
        }) { return .contradicted }
        return .unknown
    }

    private static func truth(of c: Constraint, level: Level, board: [String?], rounds: [RoundState]) -> Truth {
        switch c.kind {
        case "cardPlayed":
            guard let round = c.round, let player = c.player, let card = c.card, let slot = level.slot(round: round, player: player) else { return .unknown }
            if let placed = board[slot] { return placed == card ? .satisfied : .contradicted }
            return board.contains(card) ? .contradicted : .unknown
        case "playedSuit":
            guard let round = c.round, let player = c.player, let suit = c.suit, let slot = level.slot(round: round, player: player), let placed = board[slot] else { return .unknown }
            return Card(id: placed).suit == suit ? .satisfied : .contradicted
        case "owner":
            guard let player = c.player, let card = c.card, let slot = board.firstIndex(where: { $0 == card }) else { return .unknown }
            return level.rules.players[slot % level.rules.players.count] == player ? .satisfied : .contradicted
        case "roundWinner":
            guard let round = c.round, let player = c.player, let state = rounds.first(where: { $0.number == round }) else { return .unknown }
            return winnerTruth(player: player, level: level, board: board, state: state)
        case "leadCard":
            guard let round = c.round, let card = c.card, let state = rounds.first(where: { $0.number == round }) else { return .unknown }
            if let lead = state.leadCard { return lead.id == card ? .satisfied : .contradicted }
            if let other = board.firstIndex(where: { $0 == card }) {
                if other / level.rules.players.count != round - 1 { return .contradicted }
                if let leader = state.leader, level.rules.players[other % level.rules.players.count] != leader { return .contradicted }
            }
            return .unknown
        default: return .unknown
        }
    }

    private static func relatedSlots(_ c: Constraint, level: Level, board: [String?]) -> [Int] {
        if let round = c.round, let player = c.player, let slot = level.slot(round: round, player: player), c.kind != "roundWinner" { return [slot] }
        if let round = c.round { return Array(((round - 1) * level.rules.players.count)..<(round * level.rules.players.count)) }
        if let card = c.card, let slot = board.firstIndex(where: { $0 == card }) { return [slot] }
        return []
    }

    private static func replay(level: Level, board: [String?], rounds: [RoundState], issues: [RuleIssue]) -> [ReplayEvent] {
        var events: [ReplayEvent] = []
        let players = level.rules.players
        for state in rounds {
            guard let leader = state.leader, let first = players.firstIndex(of: leader) else { break }
            for offset in 0..<players.count {
                let player = players[(first + offset) % players.count]
                guard let slot = level.slot(round: state.number, player: player), let id = board[slot] else { return events }
                let card = Card(id: id)
                var explanation: String
                if offset == 0 {
                    explanation = "\(player) 领出\(card.spoken)，本轮跟随\(card.suitName)。"
                } else if card.suit == state.leadCard?.suit {
                    explanation = "\(player) 出\(card.spoken)，跟随领出花色。"
                } else {
                    let remainingSlots = ((state.number * players.count)..<board.count).filter { $0 % players.count == (slot % players.count) }
                    if let issue = issues.first(where: { $0.evidenceID == nil && $0.slots.first == slot && $0.message.contains("必须跟随") }) {
                        explanation = issue.message
                    } else if remainingSlots.allSatisfy({ board[$0] != nil }) {
                        explanation = "\(player) 已无\(state.leadCard?.suitName ?? "领出花色")，可垫出\(card.spoken)；垫牌不参与争胜。"
                    } else {
                        explanation = "\(player) 出\(card.spoken)；须确认剩余手牌中没有\(state.leadCard?.suitName ?? "领出花色")。"
                    }
                }
                let winner = offset == players.count - 1 ? state.winner : nil
                if let winner = winner, let winningSlot = level.slot(round: state.number, player: winner), let winningID = board[winningSlot] {
                    explanation += " \(winner) 的\(Card(id: winningID).spoken)是本轮领出花色中最大的一张，赢得本轮。"
                    if state.number < level.rules.roundCount { explanation += " 下一轮由 \(winner) 领出。" }
                }
                events.append(ReplayEvent(round: state.number, player: player, card: id, slot: slot, leader: leader, winner: winner, explanation: explanation))
            }
        }
        return events
    }
}
