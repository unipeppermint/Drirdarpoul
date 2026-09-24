import UIKit

final class ReplayViewController: PaperScreen {
    let store: AppStore; let level: Level; let board: [String?]; let fromCollection: Bool
    private let result: Evaluation
    private var position = 0
    private var timer: Timer?
    private var playbackButton: ActionButton?
    init(store: AppStore, level: Level, board: [String?], fromCollection: Bool) {
        self.store = store; self.level = level; self.board = board; self.fromCollection = fromCollection
        result = RuleEngine.evaluate(level: level, board: board)
        super.init(nibName: nil, bundle: nil); title = "牌局复盘"
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: UIApplication.willResignActiveNotification, object: nil)
        render()
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); pause() }
    @objc private func pause() { timer?.invalidate(); timer = nil; playbackButton?.setTitle("播放", for: .normal) }
    private func render() {
        let offset = scroll.contentOffset; clear()
        let archiveLabel = store.saves.lastError == nil ? "✓  已归档" : "✓  已还原 · 暂未保存"
        let stamp = textLabel(result.accepted ? archiveLabel : "待核实", .headline, color: result.accepted ? Palette.green : Palette.wine); stamp.textAlignment = .center
        let heading = textLabel(result.accepted ? "真相已还原" : "这份记录需要重新核实", .largeTitle, serif: true); heading.textAlignment = .center
        let subtitle = textLabel(level.title, .subheadline, color: Palette.muted); subtitle.textAlignment = .center
        if result.accepted { add(vertical([WaxSeal(frame: .zero), heading, subtitle, stamp], spacing: 5)) } else { add(vertical([stamp, heading, subtitle], spacing: 8)) }
        if let error = store.saves.lastError { add(textLabel(error + " 本次还原仍可复盘，请返回后重试保存。", .footnote, color: Palette.wine)) }
        if !result.accepted {
            add(textLabel(result.issues.first?.message ?? "记录信息不足，请重新打开档案。", .body, color: Palette.wine))
            if let issue = result.issues.first, let slot = issue.slots.first, let eventIndex = result.events.firstIndex(where: { $0.slot == slot }) {
                let jump = ActionButton("定位第一处可证明的矛盾")
                jump.action = { [weak self] in self?.pause(); self?.position = eventIndex + 1; self?.render() }; add(jump)
            }
        }
        let shown = Array(result.events.prefix(position))
        for round in 1...level.rules.roundCount {
            let events = result.events.filter { $0.round == round }
            guard !events.isEmpty else { continue }
            let winner = shown.last(where: { $0.round == round && $0.winner != nil })?.winner
            let grid = CardGrid(); grid.accessibilityContext = "第 \(round) 轮"; grid.allowsEditing = false; grid.dragInteractionEnabled = false
            grid.items = events.map { event in
                let revealed = shown.contains { $0.slot == event.slot }
                return CardItem(card: revealed ? event.card : nil, slot: event.slot, caption: event.player + (event.player == event.leader ? " · 领出" : ""), fixed: false, highlighted: position > 0 && shown.last?.slot == event.slot)
            }
            grid.onTap = { [weak self] item in
                guard let self = self, let index = self.result.events.firstIndex(where: { $0.slot == item.slot }) else { return }
                self.pause(); self.position = index + 1; self.render()
            }
            add(paperPanel(vertical([textLabel("第 \(round) 轮" + (winner.map { " · \($0) 获胜" } ?? " · 逐手还原"), .headline, color: Palette.wine, serif: true), grid], spacing: 8), inset: 12))
        }
        let previous = ActionButton("上一步"); previous.isEnabled = position > 0; previous.accessibilityIdentifier = "replay.previous"
        previous.action = { [weak self] in guard let self = self else { return }; self.pause(); self.position = max(0, self.position - 1); self.render() }
        let play = ActionButton(timer == nil ? "播放" : "暂停", primary: true); playbackButton = play; play.accessibilityIdentifier = "replay.play"
        play.action = { [weak self] in self?.togglePlay() }
        let next = ActionButton("下一步"); next.isEnabled = position < result.events.count; next.accessibilityIdentifier = "replay.nextStep"
        next.action = { [weak self] in guard let self = self else { return }; self.pause(); self.advance() }
        let controls = horizontal([previous, play, next], spacing: 8); controls.distribution = .fillEqually; controls.alignment = .fill; add(controls)
        let slider = UISlider(); slider.minimumValue = 0; slider.maximumValue = Float(max(1, result.events.count)); slider.value = Float(position); slider.minimumTrackTintColor = Palette.wine
        slider.accessibilityLabel = "复盘进度"; slider.accessibilityValue = "第 \(position) 手，共 \(result.events.count) 手"; slider.addTarget(self, action: #selector(seek(_:)), for: .valueChanged); add(slider)
        add(textLabel("\(position) / \(result.events.count) 手  ·  点击牌位可定位到该手", .caption1, color: Palette.muted))
        let explanation = shown.last?.explanation ?? "从第一手开始，看看每张牌如何改变下一轮。"
        let detail = textLabel(explanation, .body); detail.accessibilityIdentifier = "replay.explanation"
        add(paperPanel(vertical([textLabel("这一手的依据", .headline, color: Palette.wine), detail])))
        if position == result.events.count, result.accepted {
            add(paperPanel(vertical([textLabel("关键推理", .title3, color: Palette.wine, serif: true), textLabel(level.authorSolution.explanation, .body)])))
            if !level.testimonies.isEmpty {
                let truths = result.evidence.filter { $0.isTestimony }.map { ($0.truth == .contradicted ? "错误证词：" : "属实证词：") + $0.text }.joined(separator: "\n\n")
                add(paperPanel(vertical([textLabel("证词核对", .title3, serif: true), textLabel(truths, .body)])))
            }
        }
        let finish = ActionButton(!result.accepted ? "返回修正牌局" : (fromCollection ? "返回我的档案" : "下一份档案    →"), primary: true); finish.accessibilityIdentifier = "replay.nextLevel"
        finish.action = { [weak self] in self?.finish() }; add(finish)
        if !fromCollection {
            let back = ActionButton("返回档案首页"); back.action = { [weak self] in self?.navigationController?.popToRootViewController(animated: true) }; add(back)
        }
        view.layoutIfNeeded(); scroll.setContentOffset(offset, animated: false)
    }
    private func togglePlay() {
        if timer != nil { pause(); return }
        if position >= result.events.count { position = 0 }
        let timer = Timer(timeInterval: UIAccessibility.isVoiceOverRunning ? 4 : 1.8, repeats: true) { [weak self] _ in self?.advance() }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common); render()
    }
    private func advance() {
        position = min(result.events.count, position + 1)
        if position >= result.events.count { pause() }
        render()
        if position > 0 { UIAccessibility.post(notification: .announcement, argument: result.events[position - 1].explanation) }
    }
    @objc private func seek(_ sender: UISlider) { pause(); let target = Int(sender.value.rounded()); if target != position { position = target; render() } }
    private func finish() {
        pause()
        if !result.accepted { navigationController?.popViewController(animated: true); return }
        guard !fromCollection, let index = store.levels.firstIndex(where: { $0.id == level.id }), index + 1 < store.levels.count, store.unlocked(store.levels[index+1].chapterID) else { navigationController?.popToRootViewController(animated: true); return }
        let game = GameViewController(store: store, level: store.levels[index+1]); game.hidesBottomBarWhenPushed = true
        if let root = navigationController?.viewControllers.first { navigationController?.setViewControllers([root, game], animated: !UIAccessibility.isReduceMotionEnabled) }
    }
    deinit { timer?.invalidate() }
}
