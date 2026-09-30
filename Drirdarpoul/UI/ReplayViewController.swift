import UIKit

final class ReplayViewController: PaperScreen {
    let store: AppStore; let level: Level; let board: [String?]; let fromCollection: Bool
    private let result: Evaluation
    private var position = 0
    private var timer: Timer?
    private var playbackButton: ReplayStepButton?
    init(store: AppStore, level: Level, board: [String?], fromCollection: Bool) {
        self.store = store; self.level = level; self.board = board; self.fromCollection = fromCollection
        result = RuleEngine.evaluate(level: level, board: board)
        position = result.accepted ? result.events.count : 0
        super.init(nibName: nil, bundle: nil); title = "Replay"; hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(pause), name: UIApplication.willResignActiveNotification, object: nil)
        render()
    }
    override func fontChanged() { if isViewLoaded { render() } }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); pause() }
    @objc private func pause() { timer?.invalidate(); timer = nil; playbackButton?.setImage(UIImage(systemName: "play.fill"), for: .normal); playbackButton?.accessibilityLabel = "Play" }
    private func render() {
        let offset = scroll.contentOffset; clear()
        let archiveLabel = store.saves.lastError == nil ? "✓  Filed away" : "✓  Restored · Not yet saved"
        let stamp = textLabel(result.accepted ? archiveLabel : "Uncertain", .headline, color: result.accepted ? Palette.green : Palette.wine); stamp.textAlignment = .center
        let heading = textLabel(result.accepted ? "The truth, restored" : "Something does not add up", .largeTitle, serif: true); heading.textAlignment = .center
        let subtitle = textLabel(level.title, .subheadline, color: Palette.muted); subtitle.textAlignment = .center
        if result.accepted { add(vertical([WaxSeal(frame: .zero), heading, subtitle, stamp], spacing: 5)) } else { add(vertical([stamp, heading, subtitle], spacing: 8)) }
        if let error = store.saves.lastError { add(textLabel(error + " You can still replay this result. Return and try saving again.", .footnote, color: Palette.wine)) }
        if !result.accepted {
            add(textLabel(result.issues.first?.message ?? "This record is incomplete. Please open the file again.", .body, color: Palette.wine))
            if let issue = result.issues.first, let slot = issue.slots.first, let eventIndex = result.events.firstIndex(where: { $0.slot == slot }) {
                let jump = ActionButton("Go to the first conflict")
                jump.action = { [weak self] in self?.pause(); self?.position = eventIndex + 1; self?.render() }; add(jump)
            }
        }
        let shown = Array(result.events.prefix(position))
        for round in 1...level.rules.roundCount {
            let events = result.events.filter { $0.round == round }
            guard !events.isEmpty else { continue }
            let winner = shown.last(where: { $0.round == round && $0.winner != nil })?.winner
            let grid = CardGrid(); grid.accessibilityContext = "Round \(round)"; grid.allowsEditing = false; grid.dragInteractionEnabled = false
            grid.items = events.map { event in
                let revealed = shown.contains { $0.slot == event.slot }
                return CardItem(card: revealed ? event.card : nil, slot: event.slot, caption: event.player + (event.player == event.leader ? " · Lead" : ""), fixed: false, highlighted: position > 0 && shown.last?.slot == event.slot)
            }
            grid.onTap = { [weak self] item in
                guard let self = self, let index = self.result.events.firstIndex(where: { $0.slot == item.slot }) else { return }
                self.pause(); self.position = index + 1; self.render()
            }
            add(paperPanel(vertical([textLabel("Round \(round)" + (winner.map { " · \($0) wins" } ?? " · Play by play"), .headline, color: Palette.wine, serif: true), grid], spacing: 8), inset: 12))
        }
        let previous = ReplayStepButton(symbol: "backward.end", label: "Previous play"); previous.isEnabled = position > 0; previous.accessibilityIdentifier = "replay.previous"
        previous.action = { [weak self] in guard let self = self else { return }; self.pause(); self.position = max(0, self.position - 1); self.render() }
        let play = ReplayStepButton(symbol: timer == nil ? "play.fill" : "pause.fill", label: timer == nil ? "Play" : "Pause", primary: true); playbackButton = play; play.accessibilityIdentifier = "replay.play"
        play.action = { [weak self] in self?.togglePlay() }
        let next = ReplayStepButton(symbol: "forward.end", label: "Next play"); next.isEnabled = position < result.events.count; next.accessibilityIdentifier = "replay.nextStep"
        next.action = { [weak self] in guard let self = self else { return }; self.pause(); self.advance() }
        let slider = UISlider(); slider.minimumValue = 0; slider.maximumValue = Float(max(1, result.events.count)); slider.value = Float(position); slider.minimumTrackTintColor = Palette.wine
        slider.accessibilityLabel = "Replay progress"; slider.accessibilityValue = "Play \(position) of \(result.events.count)"; slider.addTarget(self, action: #selector(seek(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(finishSeeking), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        let controls = horizontal([previous, play, slider, next], spacing: 8); add(controls)
        add(textLabel("\(position) / \(result.events.count) plays · Tap a card to jump to that play", .caption1, color: Palette.muted))
        let explanation = shown.last?.explanation ?? "Start with the first play and follow how each card shapes the next round."
        let detail = textLabel(explanation, .body); detail.accessibilityIdentifier = "replay.explanation"
        add(paperPanel(vertical([textLabel("Why this play works", .headline, color: Palette.wine), detail])))
        if position == result.events.count, result.accepted {
            add(paperPanel(vertical([textLabel("The reasoning", .title3, color: Palette.wine, serif: true), textLabel(level.authorSolution.explanation, .body)])))
            if !level.testimonies.isEmpty {
                let truths = result.evidence.filter { $0.isTestimony }.map { ($0.truth == .contradicted ? "False statement: " : "True statement: ") + $0.text }.joined(separator: "\n\n")
                add(paperPanel(vertical([textLabel("Checking the statements", .title3, serif: true), textLabel(truths, .body)])))
            }
        }
        let hasNext = store.levels.firstIndex(where: { $0.id == level.id }).map { $0 + 1 < store.levels.count && store.unlocked(store.levels[$0 + 1].chapterID) } ?? false
        let finishTitle = !result.accepted ? "Revise your cards" : (fromCollection ? "Back to collection" : (hasNext ? "Next file" : "Back to archive"))
        if result.accepted, !fromCollection, store.levels.allSatisfy({ store.saves.completed[$0.id] != nil }) { add(textLabel("The archive is complete. Every discovery is now part of your collection.", .body, color: Palette.muted, serif: true)) }
        let finish = ActionButton(finishTitle, primary: true, accessory: "arrow.right"); finish.accessibilityIdentifier = "replay.nextLevel"
        finish.action = { [weak self] in self?.finish() }; add(finish)
        if !fromCollection && (!result.accepted || hasNext) {
            let back = ActionButton("Back to archive"); back.action = { [weak self] in self?.navigationController?.popToRootViewController(animated: true) }; add(back)
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
    @objc private func seek(_ sender: UISlider) {
        pause(); let target = Int(sender.value.rounded())
        if target != position { position = target; if !sender.isTracking { render() } }
    }
    @objc private func finishSeeking() { render() }
    private func finish() {
        pause()
        if !result.accepted { navigationController?.popViewController(animated: true); return }
        guard !fromCollection, let index = store.levels.firstIndex(where: { $0.id == level.id }), index + 1 < store.levels.count, store.unlocked(store.levels[index+1].chapterID) else { navigationController?.popToRootViewController(animated: true); return }
        let game = GameViewController(store: store, level: store.levels[index+1]); game.hidesBottomBarWhenPushed = true
        if let root = navigationController?.viewControllers.first { navigationController?.setViewControllers([root, game], animated: !UIAccessibility.isReduceMotionEnabled) }
    }
    deinit { timer?.invalidate() }
}
