import UIKit

final class GameViewController: PaperScreen {
    let store: AppStore; let level: Level; let session: GameSession
    private var selectedCard: String?
    private var feedback: String?
    private var submitted: Evaluation?
    private var undoButton: ActionButton!
    private var hasSavedCompletion = false
    init(store: AppStore, level: Level) {
        self.store = store; self.level = level
        var draft = store.saves.draft(for: level)
        if draft == nil, let record = store.saves.completed[level.id], !record.notes.isEmpty {
            // Replaying resets the reconstruction, not the player's collected notebook.
            draft = Draft(levelID: level.id, contentRevision: level.contentRevision, board: level.initialBoard,
                          notes: record.notes, hintCount: 0, testimonyMarks: [:], undoStack: [], lastUsed: Date())
        }
        session = GameSession(level: level, draft: draft)
        super.init(nibName: nil, bundle: nil); title = level.title
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); stack.spacing = 12
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Rules", style: .plain, target: self, action: #selector(showRules))
        let dock = UIView(); dock.backgroundColor = Palette.paper; dock.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(dock)
        undoButton = ActionButton("Undo", symbol: "arrow.uturn.backward"); undoButton.accessibilityIdentifier = "game.undo"
        undoButton.action = { [weak self] in guard let self = self else { return }; if self.session.undo() { self.didChange("Last move undone") } }
        let hints = ActionButton("Hint", symbol: "lightbulb"); hints.accessibilityIdentifier = "game.hint"; hints.action = { [weak self] in self?.showHint() }
        let verify = ActionButton("Check", primary: true); verify.accessibilityIdentifier = "game.verify"; verify.action = { [weak self] in self?.verify() }
        let buttons = horizontal([undoButton, hints, verify], spacing: 8); buttons.distribution = .fillEqually; buttons.alignment = .fill
        buttons.translatesAutoresizingMaskIntoConstraints = false; dock.addSubview(buttons)
        scrollBottom.isActive = false
        NSLayoutConstraint.activate([dock.leadingAnchor.constraint(equalTo: view.leadingAnchor),dock.trailingAnchor.constraint(equalTo: view.trailingAnchor),dock.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),buttons.leadingAnchor.constraint(equalTo: dock.leadingAnchor, constant: 12),buttons.trailingAnchor.constraint(equalTo: dock.trailingAnchor, constant: -12),buttons.topAnchor.constraint(equalTo: dock.topAnchor, constant: 10),buttons.bottomAnchor.constraint(equalTo: dock.bottomAnchor, constant: -8),scroll.bottomAnchor.constraint(equalTo: dock.topAnchor)])
        NotificationCenter.default.addObserver(self, selector: #selector(save), name: UIApplication.willResignActiveNotification, object: nil)
        render(); persist()
    }
    override func fontChanged() { if isViewLoaded, undoButton != nil { render() } }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); save() }
    @objc private func save() { persist(); _ = store.saves.saveNow() }
    private func persist() { if !hasSavedCompletion { store.saves.updateDraft(session.makeDraft()) } }
    private func didChange(_ text: String? = nil) {
        selectedCard = nil; submitted = nil; feedback = text; hasSavedCompletion = false
        store.haptic(); persist(); render()
        if let text = text { UIAccessibility.post(notification: .announcement, argument: text) }
    }
    private func render() {
        let offset = scroll.contentOffset
        clear(); undoButton.isEnabled = session.canUndo
        let compactUndo = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        undoButton.setTitle(compactUndo ? nil : "Undo", for: .normal)
        undoButton.accessibilityLabel = "Undo"
        undoButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: compactUndo ? 0 : 8)
        let derived = RuleEngine.evaluate(level: level, board: session.board)
        add(textLabel("FILE \(String(format: "%02d", level.number)) · \(level.cards.count) cards / \(level.rules.roundCount) rounds", .caption1, color: Palette.wine))
        let rule = textLabel("Follow suit · No trumps", .subheadline, color: Palette.muted, serif: true);rule.textAlignment = .center
        add(rule)
        let instructions = level.number <= 6 ? "Tap a card, then a slot. Drag to move or swap." : "Place each player's cards. The leader sets the order."
        add(textLabel(instructions, .footnote, color: Palette.muted))
        if let feedback = feedback {
            add(paperPanel(textLabel(feedback, .subheadline, color: Palette.wine), inset: 12))
            if let checked = submitted, checked.complete, !checked.accepted {
                let inspect = ActionButton("Review this attempt")
                inspect.accessibilityIdentifier = "game.inspectFailure"
                inspect.action = { [weak self] in
                    guard let self = self else { return }
                    self.navigationController?.pushViewController(ReplayViewController(store: self.store, level: self.level, board: self.session.board, fromCollection: false), animated: true)
                }; add(inspect)
            }
        }
        if let error = store.saves.lastError { add(textLabel(error, .footnote, color: Palette.wine)) }
        add(textLabel("The play record", .title2, serif: true))
        for round in 1...level.rules.roundCount {
            let players = level.rules.players
            let leader = derived.leaders[round]
            var ordered = players
            if let leader = leader, let index = players.firstIndex(of: leader) { ordered = Array(players[index...]) + Array(players[..<index]) }
            let grid = CardGrid()
            grid.accessibilityContext = "Round \(round)"
            grid.items = ordered.map { player in
                let slot = level.slot(round: round, player: player)!
                return CardItem(card: session.board[slot], slot: slot, caption: player + (player == leader ? " · Lead" : ""), fixed: level.fixedPlays[slot] != nil, selected: selectedCard != nil && selectedCard == session.board[slot])
            }
            wire(grid)
            let winnerText = derived.winners[round].map { " · \($0) wins" } ?? ""
            let heading = textLabel("Round \(round)\(winnerText)", .headline, color: Palette.wine, serif: true)
            let order = textLabel(leader == nil ? "Leader not yet known" : "\(ordered.joined(separator: " → ")) · \(round == 1 ? "Play order" : "Deduced order")", .caption1, color: Palette.muted)
            let roundHeading = horizontal([heading, UIView(), order], spacing: 6)
            if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { roundHeading.axis = .vertical; roundHeading.alignment = .leading }
            add(paperPanel(vertical([roundHeading, grid], spacing: 6), inset: 12))
        }
        add(textLabel("Unplaced cards", .title2, serif: true))
        if session.pool.isEmpty { add(textLabel("Every card is in place. Check your reconstruction.", .footnote, color: Palette.muted)) }
        else {
            let pool = CardGrid(); pool.items = session.pool.map { CardItem(card: $0.id, slot: nil, caption: "Unplaced", fixed: false, selected: $0.id == selectedCard) }; wire(pool); add(pool)
        }
        if let selected = selectedCard {
            let selection = textLabel("Selected: \(Card(id: selected).spoken). Tap a destination.", .footnote, color: Palette.wine)
            selection.accessibilityIdentifier = "game.selection"; add(selection)
            if session.board.contains(where: { $0 == selected }) {
                let back = ActionButton("Return to unplaced cards"); back.accessibilityIdentifier = "game.return"; back.action = { [weak self] in self?.move(selected, to: nil) }; add(back)
            }
        }
        var evidenceViews: [UIView] = [archiveHeading("Reliable clues", symbol: "pin")]
        for fact in level.facts { evidenceViews.append(evidenceLabel(fact, isTestimony: false)) }
        add(paperPanel(vertical(evidenceViews)))
        if !level.testimonies.isEmpty {
            var testimonyViews: [UIView] = [textLabel("Witness statements", .title3, serif: true), textLabel("Exactly \(level.falseTestimonyCount) of these statements are false. Your marks are for your own reference.", .footnote, color: Palette.wine)]
            for (index, testimony) in level.testimonies.enumerated() {
                testimonyViews.append(evidenceLabel(testimony, isTestimony: true))
                let control = UISegmentedControl(items: ["Uncertain", "True", "False"])
                control.tag = index; control.selectedSegmentIndex = ["unknown","true","false"].firstIndex(of: session.testimonyMarks[testimony.id] ?? "unknown") ?? 0
                control.selectedSegmentTintColor = Palette.wash; control.accessibilityLabel = testimony.text
                control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
                control.addTarget(self, action: #selector(markTestimony(_:)), for: .valueChanged); testimonyViews.append(control)
            }
            add(paperPanel(vertical(testimonyViews)))
        }
        let notes = ActionButton(session.notes.isEmpty ? "Add a note" : "Edit your notes", symbol: "square.and.pencil"); notes.accessibilityIdentifier = "game.notes"; notes.action = { [weak self] in self?.editNotes() }; add(notes)
        if !session.notes.isEmpty { add(textLabel(session.notes, .body, color: Palette.muted)) }
        if session.hintCount > 0 {
            let hintText = level.hints.prefix(session.hintCount).map { "\($0.title)\n\($0.text)" }.joined(separator: "\n\n")
            add(paperPanel(vertical([textLabel("Hints read · \(session.hintCount) / \(level.hints.count)", .headline, color: Palette.wine), textLabel(hintText, .footnote)])))
        }
        view.layoutIfNeeded(); scroll.setContentOffset(offset, animated: false)
    }
    private func evidenceLabel(_ evidence: Evidence, isTestimony: Bool) -> UILabel {
        let result = submitted?.evidence.first { $0.id == evidence.id && $0.isTestimony == isTestimony }
        let prefix: String
        switch result?.truth {
        case .satisfied?: prefix = isTestimony ? "[Matches] " : "[Supported] "
        case .contradicted?: prefix = isTestimony ? "[Does not match] " : "[Conflict] "
        default: prefix = submitted == nil ? "· " : "[Undetermined] "
        }
        return textLabel(prefix + evidence.text, .subheadline)
    }
    private func wire(_ grid: CardGrid) {
        grid.onTap = { [weak self] item in self?.tap(item) }
        grid.onDropCard = { [weak self] card, slot in self?.move(card, to: slot) }
        grid.onRemove = { [weak self] card in self?.move(card, to: nil) }
    }
    private func tap(_ item: CardItem) {
        if item.fixed { message("Fixed card", "A reliable clue confirms this card's position. It cannot be moved."); return }
        if let selected = selectedCard, let slot = item.slot, item.card != selected { move(selected, to: slot); return }
        if let card = item.card { selectedCard = selectedCard == card ? nil : card; store.haptic(); render() }
        else { feedback = "Select an unplaced card first, then tap this slot."; render() }
    }
    private func move(_ card: String, to slot: Int?) {
        if session.move(card: card, to: slot) { didChange() }
        else { message("Cannot move this card", "Fixed cards cannot be moved. Choose another slot.") }
    }
    @objc private func markTestimony(_ sender: UISegmentedControl) {
        let testimony = level.testimonies[sender.tag]
        session.testimonyMarks[testimony.id] = ["unknown","true","false"][sender.selectedSegmentIndex]
        if hasSavedCompletion { store.saves.complete(level: level, session: session) } else { persist() }; undoButton.isEnabled = session.canUndo
    }
    private func verify() {
        selectedCard = nil
        let result = RuleEngine.evaluate(level: level, board: session.board); submitted = result
        if result.accepted {
            if !hasSavedCompletion { store.saves.complete(level: level, session: session); _ = store.saves.saveNow(); hasSavedCompletion = true }
            let replay = ReplayViewController(store: store, level: level, board: session.board, fromCollection: false)
            navigationController?.pushViewController(replay, animated: !UIAccessibility.isReduceMotionEnabled)
        } else {
            feedback = result.issues.first?.message ?? "Unplaced cards: \(session.pool.count). Clues remain undetermined until there is enough evidence."
            render(); scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: !UIAccessibility.isReduceMotionEnabled)
            UIAccessibility.post(notification: .announcement, argument: feedback)
        }
    }
    @objc private func showRules() {
        message("Follow suit · No trumps", "\(level.story)\n\nAll cards are dealt. Each player (\(level.rules.players.joined(separator: ", "))) holds \(level.rules.roundCount) cards. Play follows the seating order \(level.rules.players.joined(separator: " → ")).\n\n\(level.rules.firstLeader) leads the first round. Each player plays one card per round and must follow the lead suit if they have it. Otherwise, they may play another suit. The highest card of the lead suit wins and its owner leads the next round. Each card is used once.\n\nReliable clues are always true. Check witness statements against the exact false-statement count given in the file.")
    }
    private func showHint() {
        guard session.hintCount < level.hints.count else { message("All hints revealed", level.hints.map { "\($0.title)\n\($0.text)" }.joined(separator: "\n\n")); return }
        if session.hintCount == 2 {
            let alert = UIAlertController(title: "Reveal the next deduction?", message: "This hint reveals a specific next move.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Keep thinking", style: .cancel)); alert.addAction(UIAlertAction(title: "Reveal hint", style: .default) { [weak self] _ in self?.revealHint() }); present(alert, animated: true)
        } else { revealHint() }
    }
    private func revealHint() {
        guard let hint = session.useHint() else { return }; if hasSavedCompletion { store.saves.complete(level: level, session: session) } else { persist() }; render(); message(hint.title, hint.text)
    }
    private func editNotes() {
        let editor = NotesViewController(text: session.notes) { [weak self] text in guard let self = self else { return }; self.session.notes = text; if self.hasSavedCompletion { self.store.saves.complete(level: self.level, session: self.session) } else { self.persist() }; self.render() }
        present(UINavigationController(rootViewController: editor), animated: true)
    }
}
final class NotesViewController: UIViewController, UITextViewDelegate {
    private var pendingSave: DispatchWorkItem?
    private let editor = UITextView(); private let original: String; private let saveText: (String) -> Void
    init(text: String, save: @escaping (String) -> Void) { original = text; saveText = save; super.init(nibName: nil, bundle: nil); title = "Notebook" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = Palette.paper; editor.backgroundColor = Palette.paper; editor.textColor = Palette.ink
        editor.delegate = self
        editor.font = UIFont.preferredFont(forTextStyle: .body); editor.adjustsFontForContentSizeCategory = true; editor.text = original; editor.accessibilityLabel = "Your notes"
        editor.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(editor)
        NSLayoutConstraint.activate([editor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),editor.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),editor.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),editor.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(done))
        NotificationCenter.default.addObserver(self, selector: #selector(keyboard(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(persist), name: UIApplication.willResignActiveNotification, object: nil)
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); persist() }
    func textViewDidChange(_ textView: UITextView) {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }
        pendingSave = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    @objc private func persist() { pendingSave?.cancel(); pendingSave = nil; saveText(editor.text) }
    @objc private func done() { persist(); dismiss(animated: true) }
    @objc private func keyboard(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let local = view.convert(frame, from: nil); editor.contentInset.bottom = max(0, view.bounds.maxY - local.minY - view.safeAreaInsets.bottom); editor.scrollIndicatorInsets = editor.contentInset
    }
    deinit { pendingSave?.cancel(); NotificationCenter.default.removeObserver(self) }
}
