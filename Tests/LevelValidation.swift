import Foundation

@main
enum LevelValidation {
    static var checks = 0
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !condition() { fatalError("CONTENT FAIL: \(message)") }
    }

    static func copy(_ level: Level, facts: [Evidence], testimonies: [Evidence]? = nil, falseCount: Int? = nil) -> Level {
        Level(schemaVersion: level.schemaVersion, contentRevision: level.contentRevision, id: level.id,
              chapterID: level.chapterID, number: level.number, title: level.title, subtitle: level.subtitle,
              story: level.story, rules: level.rules, cards: level.cards, facts: facts,
              falseTestimonyCount: falseCount ?? level.falseTestimonyCount,
              testimonies: testimonies ?? level.testimonies, hints: [], authorSolution: level.authorSolution)
    }

    static func main() throws {
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Drirdarpoul/Data/levels.json"
        let levels = try LevelRepository.load(url: URL(fileURLWithPath: path))
        let started = Date()
        var totalNodes = 0
        for level in levels {
            let answer = level.authorSolution.plays.map(Optional.some)
            let evaluation = RuleEngine.evaluate(level: level, board: answer)
            require(evaluation.accepted, "\(level.id): authored board satisfies rules and evidence")
            require(evaluation.events.count == level.cards.count, "\(level.id): full chronological replay")
            require(RuleEngine.evaluate(level: level, board: level.initialBoard).issues.isEmpty, "\(level.id): initial state has no proven contradiction")
            let counted = SolutionCounter.count(level: level, limit: 2, timeLimit: 60)
            totalNodes += counted.visitedNodes
            require(counted.count == 1 && counted.exhausted, "\(level.id): exhaustive unique solution (count \(counted.count), exhausted \(counted.exhausted))")
            require(counted.solutions.first == level.authorSolution.plays, "\(level.id): author matches independently searched solution")
            let falseIDs = evaluation.evidence.filter { $0.isTestimony && $0.truth == .contradicted }.map { $0.id }
            require(Set(falseIDs) == Set(level.authorSolution.falseTestimonyIDs), "\(level.id): wrong witness identities agree")
            require(level.hints.count == 3, "\(level.id): exactly three free hint layers")
            require(level.hints[0].conclusion == nil && level.hints[1].conclusion == nil, "\(level.id): first two layers do not carry a reveal")
            let allIDs = Set((level.facts + level.testimonies).map { $0.id })
            for hint in level.hints {
                require(!hint.text.isEmpty && !hint.evidenceIDs.isEmpty, "\(level.id): useful text and evidence references")
                require(Set(hint.evidenceIDs).isSubset(of: allIDs), "\(level.id): no dangling hint evidence")
                guard let conclusion = hint.conclusion else { continue }
                require(RuleEngine.truth(of: conclusion, level: level, board: answer) == .satisfied, "\(level.id): hint conclusion agrees with engine")
                require(conclusion.kind == "cardPlayed", "\(level.id): this author suite validates explicit card-placement conclusions")
                let references = Set(hint.evidenceIDs)
                let supportingFacts = level.facts.filter { references.contains($0.id) }
                let supportingTestimonies = level.testimonies.filter { references.contains($0.id) }
                require(supportingTestimonies.count == level.testimonies.count || supportingTestimonies.isEmpty,
                        "\(level.id): an exact false-count policy is never applied to a witness subset")
                for card in level.cards where card.id != conclusion.card {
                    var alternative = conclusion
                    alternative.card = card.id
                    let contradiction = Evidence(id: "hint-alternative", text: "作者工具：检验提示结论的反例", constraint: alternative)
                    let premise = copy(level, facts: supportingFacts + [contradiction], testimonies: supportingTestimonies,
                                       falseCount: supportingTestimonies.isEmpty ? 0 : level.falseTestimonyCount)
                    let counterexample = SolutionCounter.count(level: premise, limit: 1, timeLimit: 60)
                    totalNodes += counterexample.visitedNodes
                    require(counterexample.count == 0 && counterexample.exhausted,
                            "\(level.id): referenced evidence proves hint against alternative \(card.id)")
                }
            }
            if level.chapterID == "chapter04" {
                require(level.testimonies.count == 4 && (1...2).contains(level.falseTestimonyCount), "\(level.id): explicit witness policy")
                let noWitnesses = copy(level, facts: level.facts, testimonies: [], falseCount: 0)
                let ambiguous = SolutionCounter.count(level: noWitnesses, limit: 1000, timeLimit: 60)
                require(ambiguous.count >= 2 && ambiguous.exhausted, "\(level.id): witnesses materially constrain the solution")
                for witness in level.testimonies {
                    let truths = ambiguous.solutions.map { RuleEngine.truth(of: witness.constraint, level: noWitnesses, board: $0.map(Optional.some)) }
                    require(truths.contains(.satisfied) && truths.contains(.contradicted),
                            "\(level.id): \(witness.id) is genuinely uncertain under reliable facts alone")
                }
            }
            print(String(format: "%02d", level.number) + " \(level.title): unique, replay and hint entailment passed (\(counted.visitedNodes) nodes)")
        }
        let sample = levels[0]
        require(sample.cards.map { $0.id } == ["S2", "S5", "S9", "H3", "H7", "H10"], "exact tutorial deck")
        require(sample.fixedPlays == [0: "S5", 2: "H3", 4: "H7"], "exact three fixed prototype cards")
        require(sample.authorSolution.plays == ["S5", "S9", "H3", "S2", "H7", "H10"], "exact tutorial outcome")
        require(levels.prefix(8).count == 8 && levels.prefix(6).allSatisfy { $0.chapterID == "chapter01" }, "eight-level milestone includes six tutorials")
        let suitCounts = Set(levels.map { Set($0.cards.map { $0.suit }).count })
        require(suitCounts.isSuperset(of: [2, 3, 4]), "two, three and four-suit content")
        require(Set(levels.map { $0.rules.firstLeader }) == Set(["A", "B", "C"]), "all three initial leaders used")
        print("PASS: \(levels.count) levels, \(checks) content checks, \(totalNodes) searched nodes, \(String(format: "%.2f", Date().timeIntervalSince(started))) seconds.")
    }
}
