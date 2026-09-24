import UIKit

final class AppStore {
    let levels: [Level]
    let saves: SaveRepository
    let settings = Settings()
    init() throws { levels = try LevelRepository.load(); saves = SaveRepository(levels: levels) }
    func unlocked(_ chapterID: String) -> Bool {
        let chapters = LevelRepository.chapters
        guard let index = chapters.firstIndex(where: { $0.id == chapterID }), index > 0 else { return true }
        return levels.filter { $0.chapterID == chapters[index - 1].id }.allSatisfy { saves.completed[$0.id] != nil }
    }
    var nextLevel: Level {
        if let id = saves.currentLevelID, let current = levels.first(where: { $0.id == id }), unlocked(current.chapterID), saves.completed[id] == nil { return current }
        return levels.first { saves.completed[$0.id] == nil && unlocked($0.chapterID) } ?? levels[0]
    }
    func haptic() { if settings.hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() } }
    func open(_ level: Level, from controller: UIViewController) {
        let game = GameViewController(store: self, level: level); game.hidesBottomBarWhenPushed = true
        controller.navigationController?.pushViewController(game, animated: !UIAccessibility.isReduceMotionEnabled)
    }
}

final class HomeViewController: PaperScreen {
    let store: AppStore
    init(store: AppStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "档案" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); render() }
    private func render() {
        clear()
        let brand = vertical([SuitMark(), textLabel("牌局档案", .largeTitle, serif: true)], spacing: 7)
        brand.alignment = .leading
        let head = horizontal([brand, UIView(), textLabel("每张牌，\n都留下了线索。", .subheadline, color: Palette.muted, serif: true)])
        head.alignment = .bottom
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { head.axis = .vertical;head.alignment = .leading;head.spacing = 8 }
        add(head)
        let level = store.nextLevel
        let art = ArchiveIllustration(); art.heightAnchor.constraint(equalTo: art.widthAnchor, multiplier: 0.72).isActive = true
        let stamp = textLabel(String(format: "档案 %02d", level.number), .title3, color: Palette.wine, serif: true)
        stamp.backgroundColor = Palette.paper.withAlphaComponent(0.92); stamp.layer.borderColor = Palette.wine.cgColor; stamp.layer.borderWidth = 1
        stamp.textAlignment = .center; stamp.translatesAutoresizingMaskIntoConstraints = false; art.addSubview(stamp)
        NSLayoutConstraint.activate([stamp.topAnchor.constraint(equalTo: art.topAnchor, constant: 12), stamp.trailingAnchor.constraint(equalTo: art.trailingAnchor, constant: -12), stamp.widthAnchor.constraint(greaterThanOrEqualToConstant: 83),stamp.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)])
        let info = vertical([textLabel(level.title, .title2, serif: true), textLabel("\(level.subtitle) · 第 \(level.number) 关", .subheadline, color: Palette.muted)], spacing: 5)
        let count = textLabel("\(store.saves.completed.count) / 40", .title3, serif: true); count.textAlignment = .right
        let progress = vertical([count, textLabel("已完成", .caption1, color: Palette.muted)], spacing: 5); progress.alignment = .trailing
        progress.setContentHuggingPriority(.required, for: .horizontal)
        let play = ActionButton(store.saves.drafts[level.id] == nil ? "打开档案    →" : "继续推理    →", primary: true)
        play.accessibilityIdentifier = "home.continue"; play.action = { [weak self] in guard let self = self else { return }; self.store.open(level, from: self) }
        let summary = horizontal([info, UIView(), progress])
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { summary.axis = .vertical;summary.alignment = .leading;progress.alignment = .leading;count.textAlignment = .left }
        add(paperPanel(vertical([art, summary, play], spacing: 12), inset: 10))
        add(textLabel("探索档案", .title2, serif: true))
        for chapter in LevelRepository.chapters {
            let levels = store.levels.filter { $0.chapterID == chapter.id }
            let done = levels.filter { store.saves.completed[$0.id] != nil }.count
            let available = store.unlocked(chapter.id)
            let detail = available ? "\(chapter.subtitle) · \(done)/\(levels.count) 已还原" : "完成前章解锁 · 全部免费"
            let row = IllustratedArchiveRow(title: chapter.title, detail: detail, imageName: chapterArtwork(chapter.id), locked: !available)
            row.accessibilityIdentifier = "chapter.\(chapter.id)"
            row.action = { [weak self] in
                guard let self = self else { return }
                if available { self.navigationController?.pushViewController(ChapterViewController(store: self.store, chapter: chapter), animated: true) }
                else { self.message("档案尚未开启", "完成前章的全部档案后解锁。所有章节免费。") }
            }
            add(row)
        }
        add(textLabel("40 份档案 · 提示、撤销与复盘全部免费", .caption1, color: Palette.muted))
        if let notice = store.saves.notice { add(textLabel(notice, .footnote, color: Palette.wine)) }
        if let error = store.saves.lastError { add(textLabel(error, .footnote, color: Palette.wine)) }
    }
}
final class ChapterViewController: PaperScreen {
    let store: AppStore; let chapter: Chapter
    init(store: AppStore, chapter: Chapter) { self.store = store; self.chapter = chapter; super.init(nibName: nil, bundle: nil); title = chapter.title }
    required init?(coder: NSCoder) { fatalError() }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); clear()
        let banner = artworkView(chapterArtwork(chapter.id)); banner.heightAnchor.constraint(equalTo: banner.widthAnchor, multiplier: 0.55).isActive = true
        add(banner); add(textLabel(chapter.story, .body, color: Palette.muted))
        for level in store.levels.filter({ $0.chapterID == chapter.id }) {
            let done = store.saves.completed[level.id] != nil
            let button = IllustratedArchiveRow(title: "\(String(format: "%02d", level.number))  \(level.title)", detail: done ? "✓ 已还原 · 再次推理" : level.subtitle, imageName: chapterArtwork(chapter.id))
            button.accessibilityIdentifier = "level.\(level.number)"
            button.action = { [weak self] in guard let self = self else { return }; self.store.open(level, from: self) }
            add(button)
        }
    }
}
final class CollectionViewController: PaperScreen {
    let store: AppStore
    init(store: AppStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "收藏" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); clear()
        add(horizontal([textLabel("我的档案", .largeTitle, serif: true), UIView(), textLabel(String(format: "%02d", store.saves.completed.count), .largeTitle, color: Palette.wine, serif: true)]))
        add(textLabel("收藏每一次恍然大悟。", .subheadline, color: Palette.muted))
        if store.saves.completed.isEmpty {
            let art = ArchiveIllustration(motif: 2); art.heightAnchor.constraint(equalToConstant: 160).isActive = true
            let start = ActionButton("开启第一份档案", primary: true); start.action = { [weak self] in guard let self = self else { return }; self.store.open(self.store.nextLevel, from: self) }
            add(paperPanel(vertical([art, textLabel("故事，等待你来还原。", .title3, serif: true), textLabel("完成档案后，故事、推理笔记和逐手复盘都会保存在这里。", .body, color: Palette.muted), start])))
        }
        for level in store.levels {
            guard let record = store.saves.completed[level.id] else { continue }
            let review = ActionButton("查看复盘    →"); review.accessibilityIdentifier = "collection.replay.\(level.number)"
            review.action = { [weak self] in
                guard let self = self else { return }
                guard record.contentRevision == level.contentRevision else { self.message("档案内容已更新", "历史完成记录仍保留。重新推理后可生成当前版本的复盘。"); return }
                let replay = ReplayViewController(store: self.store, level: level, board: record.board.map { Optional($0) }, fromCollection: true)
                replay.hidesBottomBarWhenPushed = true; self.navigationController?.pushViewController(replay, animated: true)
            }
            let replayGame = ActionButton("再次推理"); replayGame.action = { [weak self] in guard let self = self else { return }; self.confirmReplay(level) }
            let notes = record.notes
            let art = artworkView(chapterArtwork(level.chapterID))
            NSLayoutConstraint.activate([art.widthAnchor.constraint(equalToConstant: 104),art.heightAnchor.constraint(equalToConstant: 113)])
            let editorial = vertical([textLabel(String(format: "NO. %02d", level.number), .caption1, color: Palette.wine, serif: true), textLabel(level.title, .title2, serif: true), textLabel(level.subtitle, .subheadline, color: Palette.muted), textLabel("✓ 已还原", .caption1, color: Palette.green)], spacing: 7)
            let top = horizontal([editorial, art], spacing: 10); top.alignment = .top
            let story = textLabel(level.story, .footnote, color: Palette.muted)
            add(paperPanel(vertical([top, story, horizontal([review, replayGame])], spacing: 12), inset: 13))
            if !notes.isEmpty { add(paperPanel(vertical([textLabel("✎  推理笔记", .headline, serif: true),textLabel(notes, .subheadline, color: Palette.muted)], spacing: 7), inset: 13)) }
        }
    }
    private func confirmReplay(_ level: Level) {
        let alert = UIAlertController(title: "重新推理这份档案？", message: "重置这份档案的摆牌草稿，通关收藏记录保留。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel)); alert.addAction(UIAlertAction(title: "重新开始", style: .default) { [weak self] _ in
            guard let self = self else { return }; self.store.saves.resetDraft(for: level); self.store.open(level, from: self)
        }); present(alert, animated: true)
    }
}
final class SettingsViewController: PaperScreen {
    let store: AppStore
    init(store: AppStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "设置" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); add(textLabel("让推理更从容", .largeTitle, serif: true))
        let haptics = UISwitch(); haptics.onTintColor = Palette.wine; haptics.isOn = store.settings.hapticsEnabled; haptics.addTarget(self, action: #selector(setHaptics(_:)), for: .valueChanged); haptics.accessibilityLabel = "操作触感"
        let large = UISwitch(); large.onTintColor = Palette.wine; large.isOn = store.settings.largerText; large.addTarget(self, action: #selector(setLarge(_:)), for: .valueChanged); large.accessibilityLabel = "加大文字"
        add(paperPanel(vertical([horizontal([textLabel("操作触感"), UIView(), haptics]), horizontal([textLabel("加大文字"), UIView(), large])], spacing: 24)))
        add(paperPanel(vertical([textLabel("离线，也能安心收藏", .title3, serif: true), textLabel("摆牌、笔记和提示阅读进度会自动保存在本机。卸载应用会移除本地档案；暂不提供跨设备同步。", .body, color: Palette.muted)])))
        add(paperPanel(vertical([textLabel("玩法速记", .title3, serif: true), textLabel("每轮每人出一张牌。手中有领出花色时必须跟花色；没有时才可以出其他花色。没有王牌，只有领出花色参与比较，点数最大者获胜并领出下一轮。", .body)])))
        add(textLabel("牌局档案  1.0\n40 份档案 · 提示、撤销与复盘全部免费\n采用系统字体，支持旁白与减少动态效果。", .footnote, color: Palette.muted))
        if store.saves.isReadOnly { add(textLabel(store.saves.notice ?? "存档版本较新，当前为只读模式。", .body, color: Palette.wine)) }
    }
    @objc private func setHaptics(_ sender: UISwitch) { store.settings.hapticsEnabled = sender.isOn }
    @objc private func setLarge(_ sender: UISwitch) { store.settings.largerText = sender.isOn; NotificationCenter.default.post(name: .init("CardTraceTextChanged"), object: nil) }
}
