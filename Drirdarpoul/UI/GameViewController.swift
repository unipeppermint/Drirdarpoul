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
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "规则", style: .plain, target: self, action: #selector(showRules))
        let dock = UIView(); dock.backgroundColor = Palette.paper; dock.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(dock)
        undoButton = ActionButton("撤销", symbol: "arrow.uturn.backward"); undoButton.accessibilityIdentifier = "game.undo"
        undoButton.action = { [weak self] in guard let self = self else { return }; if self.session.undo() { self.didChange("已撤销上一步") } }
        let hints = ActionButton("提示", symbol: "lightbulb"); hints.accessibilityIdentifier = "game.hint"; hints.action = { [weak self] in self?.showHint() }
        let verify = ActionButton("验证推理", primary: true); verify.accessibilityIdentifier = "game.verify"; verify.action = { [weak self] in self?.verify() }
        let buttons = horizontal([undoButton, hints, verify], spacing: 8); buttons.distribution = .fillEqually; buttons.alignment = .fill
        buttons.translatesAutoresizingMaskIntoConstraints = false; dock.addSubview(buttons)
        scrollBottom.isActive = false
        NSLayoutConstraint.activate([dock.leadingAnchor.constraint(equalTo: view.leadingAnchor),dock.trailingAnchor.constraint(equalTo: view.trailingAnchor),dock.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),buttons.leadingAnchor.constraint(equalTo: dock.leadingAnchor, constant: 12),buttons.trailingAnchor.constraint(equalTo: dock.trailingAnchor, constant: -12),buttons.topAnchor.constraint(equalTo: dock.topAnchor, constant: 10),buttons.bottomAnchor.constraint(equalTo: dock.bottomAnchor, constant: -8),scroll.bottomAnchor.constraint(equalTo: dock.topAnchor)])
        NotificationCenter.default.addObserver(self, selector: #selector(save), name: UIApplication.willResignActiveNotification, object: nil)
        render(); persist()
    }
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
        let derived = RuleEngine.evaluate(level: level, board: session.board)
        add(textLabel("档案 \(String(format: "%02d", level.number))  ·  \(level.cards.count) 张牌 / \(level.rules.roundCount) 轮", .caption1, color: Palette.wine))
        let rule = textLabel("须跟花色 · 无王牌", .subheadline, color: Palette.muted, serif: true);rule.textAlignment = .center
        add(rule)
        let instructions = level.number <= 6 ? "点选牌 → 点牌位 · 可拖动与交换" : "按人物归位出牌 · 领出者决定顺序"
        add(textLabel(instructions, .footnote, color: Palette.muted))
        if let feedback = feedback {
            add(paperPanel(textLabel(feedback, .subheadline, color: Palette.wine), inset: 12))
            if let checked = submitted, checked.complete, !checked.accepted {
                let inspect = ActionButton("逐手检查这次摆法")
                inspect.accessibilityIdentifier = "game.inspectFailure"
                inspect.action = { [weak self] in
                    guard let self = self else { return }
                    self.navigationController?.pushViewController(ReplayViewController(store: self.store, level: self.level, board: self.session.board, fromCollection: false), animated: true)
                }; add(inspect)
            }
        }
        if let error = store.saves.lastError { add(textLabel(error, .footnote, color: Palette.wine)) }
        add(textLabel("出牌时间线", .title2, serif: true))
        for round in 1...level.rules.roundCount {
            let players = level.rules.players
            let leader = derived.leaders[round]
            var ordered = players
            if let leader = leader, let index = players.firstIndex(of: leader) { ordered = Array(players[index...]) + Array(players[..<index]) }
            let grid = CardGrid()
            grid.accessibilityContext = "第 \(round) 轮"
            grid.items = ordered.map { player in
                let slot = level.slot(round: round, player: player)!
                return CardItem(card: session.board[slot], slot: slot, caption: player + (player == leader ? " · 领出" : ""), fixed: level.fixedPlays[slot] != nil, selected: selectedCard != nil && selectedCard == session.board[slot])
            }
            wire(grid)
            let winnerText = derived.winners[round].map { "  ·  \($0) 获胜" } ?? ""
            let heading = textLabel("第 \(round) 轮\(winnerText)", .headline, color: Palette.wine, serif: true)
            let order = textLabel(leader == nil ? "领出者待推断 · 暂按座次排列" : "\(ordered.joined(separator: " → ")) · \(round == 1 ? "规则指定" : "当前推导")", .caption1, color: Palette.muted)
            add(paperPanel(vertical([horizontal([heading, UIView(), order], spacing: 6), grid], spacing: 6), inset: 12))
        }
        add(textLabel("待归位的牌", .title2, serif: true))
        if session.pool.isEmpty { add(textLabel("所有牌已归位，可以验证推理。", .footnote, color: Palette.muted)) }
        else {
            let pool = CardGrid(); pool.items = session.pool.map { CardItem(card: $0.id, slot: nil, caption: "待归位", fixed: false, selected: $0.id == selectedCard) }; wire(pool); add(pool)
        }
        if let selected = selectedCard {
            let selection = textLabel("已选 \(Card(id: selected).spoken) · 点目标位置", .footnote, color: Palette.wine)
            selection.accessibilityIdentifier = "game.selection"; add(selection)
            if session.board.contains(where: { $0 == selected }) {
                let back = ActionButton("移回待归位牌"); back.accessibilityIdentifier = "game.return"; back.action = { [weak self] in self?.move(selected, to: nil) }; add(back)
            }
        }
        var evidenceViews: [UIView] = [textLabel("📌  可信线索", .title3, serif: true)]
        for fact in level.facts { evidenceViews.append(evidenceLabel(fact, isTestimony: false)) }
        add(paperPanel(vertical(evidenceViews)))
        if !level.testimonies.isEmpty {
            var testimonyViews: [UIView] = [textLabel("待核实证词", .title3, serif: true), textLabel("以下恰有 \(level.falseTestimonyCount) 条错误。标记仅作你的推理笔记。", .footnote, color: Palette.wine)]
            for (index, testimony) in level.testimonies.enumerated() {
                testimonyViews.append(evidenceLabel(testimony, isTestimony: true))
                let control = UISegmentedControl(items: ["待核实", "我认为真", "我认为假"])
                control.tag = index; control.selectedSegmentIndex = ["unknown","true","false"].firstIndex(of: session.testimonyMarks[testimony.id] ?? "unknown") ?? 0
                control.selectedSegmentTintColor = Palette.wash; control.accessibilityLabel = testimony.text
                control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
                control.addTarget(self, action: #selector(markTestimony(_:)), for: .valueChanged); testimonyViews.append(control)
            }
            add(paperPanel(vertical(testimonyViews)))
        }
        let notes = ActionButton(session.notes.isEmpty ? "写下推理笔记    ✎" : "编辑推理笔记    ✎"); notes.accessibilityIdentifier = "game.notes"; notes.action = { [weak self] in self?.editNotes() }; add(notes)
        if !session.notes.isEmpty { add(textLabel(session.notes, .body, color: Palette.muted)) }
        if session.hintCount > 0 {
            let hintText = level.hints.prefix(session.hintCount).map { "\($0.title)\n\($0.text)" }.joined(separator: "\n\n")
            add(paperPanel(vertical([textLabel("已读提示 · \(session.hintCount) / \(level.hints.count)", .headline, color: Palette.wine), textLabel(hintText, .footnote)])))
        }
        view.layoutIfNeeded(); scroll.setContentOffset(offset, animated: false)
    }
    private func evidenceLabel(_ evidence: Evidence, isTestimony: Bool) -> UILabel {
        let result = submitted?.evidence.first { $0.id == evidence.id && $0.isTestimony == isTestimony }
        let prefix: String
        switch result?.truth {
        case .satisfied?: prefix = isTestimony ? "[符合当前牌局] " : "[当前成立] "
        case .contradicted?: prefix = isTestimony ? "[不符合当前牌局] " : "[矛盾] "
        default: prefix = submitted == nil ? "· " : "[待推断] "
        }
        return textLabel(prefix + evidence.text, .subheadline)
    }
    private func wire(_ grid: CardGrid) {
        grid.onTap = { [weak self] item in self?.tap(item) }
        grid.onDropCard = { [weak self] card, slot in self?.move(card, to: slot) }
        grid.onRemove = { [weak self] card in self?.move(card, to: nil) }
    }
    private func tap(_ item: CardItem) {
        if item.fixed { message("已知牌", "这是可信线索中已经确认的牌，不能移动。"); return }
        if let selected = selectedCard, let slot = item.slot, item.card != selected { move(selected, to: slot); return }
        if let card = item.card { selectedCard = selectedCard == card ? nil : card; store.haptic(); render() }
        else { feedback = "先选择一张待归位的牌，再点这个位置。"; render() }
    }
    private func move(_ card: String, to slot: Int?) {
        if session.move(card: card, to: slot) { didChange() }
        else { message("不能移动", "公开的固定牌不可移动；请选择其他位置。") }
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
            feedback = result.issues.first?.message ?? "还有 \(session.pool.count) 张牌未归位。信息不足的线索仍为待推断。"
            render(); scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: !UIAccessibility.isReduceMotionEnabled)
            UIAccessibility.post(notification: .announcement, argument: feedback)
        }
    }
    @objc private func showRules() {
        message("须跟花色 · 无王牌", "\(level.story)\n\n全部牌发完，\(level.rules.players.joined(separator: "、")) 各持 \(level.rules.roundCount) 张。座次 \(level.rules.players.joined(separator: " → ")) 循环。\n\n首轮由 \(level.rules.firstLeader) 领出，每轮每人出一张。手中有领出花色必须跟；没有时才可出其他花色。只有领出花色参与争胜，点数最大者获胜，并领出下一轮。已出的牌不能再用。\n\n可信线索始终成立；标为待核实的证词按题面指定的错误数量检查。")
    }
    private func showHint() {
        guard session.hintCount < level.hints.count else { message("提示已全部展开", level.hints.map { "\($0.title)\n\($0.text)" }.joined(separator: "\n\n")); return }
        if session.hintCount == 2 {
            let alert = UIAlertController(title: "展开具体推导？", message: "第三层提示会明确给出下一步结论。提示免费。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "再想一想", style: .cancel)); alert.addAction(UIAlertAction(title: "展开提示", style: .default) { [weak self] _ in self?.revealHint() }); present(alert, animated: true)
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
    init(text: String, save: @escaping (String) -> Void) { original = text; saveText = save; super.init(nibName: nil, bundle: nil); title = "推理笔记" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = Palette.paper; editor.backgroundColor = Palette.paper; editor.textColor = Palette.ink
        editor.delegate = self
        editor.font = UIFont.preferredFont(forTextStyle: .body); editor.adjustsFontForContentSizeCategory = true; editor.text = original; editor.accessibilityLabel = "推理笔记正文"
        editor.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(editor)
        NSLayoutConstraint.activate([editor.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),editor.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),editor.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),editor.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(done))
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
