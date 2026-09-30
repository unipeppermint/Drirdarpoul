import UIKit
import SafariServices

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
    init(store: AppStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "Archive" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); render() }
    override func fontChanged() { if isViewLoaded { render() } }
    private func render() {
        clear()
        let brand = vertical([SuitMark(), textLabel("Card Trace", .largeTitle, serif: true)], spacing: 7)
        brand.alignment = .leading
        let head = horizontal([brand, UIView(), textLabel("Every card\nleaves a trace.", .subheadline, color: Palette.muted, serif: true)])
        head.alignment = .bottom
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { head.axis = .vertical;head.alignment = .leading;head.spacing = 8 }
        add(head)
        let level = store.nextLevel
        let complete = store.levels.allSatisfy { store.saves.completed[$0.id] != nil }
        let chapter = LevelRepository.chapters.first { $0.id == level.chapterID }!
        let art = artworkView(complete ? "LettersEngravingV2" : chapterArtwork(level.chapterID)); art.heightAnchor.constraint(equalTo: art.widthAnchor, multiplier: 0.64).isActive = true
        let stamp = textLabel(complete ? "COMPLETE" : String(format: "FILE %02d", level.number), .title3, color: Palette.wine, serif: true)
        stamp.backgroundColor = Palette.paper.withAlphaComponent(0.92); stamp.layer.borderColor = Palette.wine.cgColor; stamp.layer.borderWidth = 1
        stamp.textAlignment = .center; stamp.translatesAutoresizingMaskIntoConstraints = false; art.addSubview(stamp)
        NSLayoutConstraint.activate([stamp.topAnchor.constraint(equalTo: art.topAnchor, constant: 12), stamp.trailingAnchor.constraint(equalTo: art.trailingAnchor, constant: -12), stamp.widthAnchor.constraint(greaterThanOrEqualToConstant: 83),stamp.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)])
        let info = vertical([textLabel(complete ? "Every mystery, restored" : level.title, .title2, serif: true), textLabel(complete ? "Four chapters to revisit." : "\(chapter.title) · File \(level.number)", .subheadline, color: Palette.muted)], spacing: 6)
        let count = textLabel("\(store.saves.completed.count) / \(store.levels.count)", .title3, serif: true); count.textAlignment = .right
        let progress = vertical([count, textLabel("Restored", .caption1, color: Palette.muted)], spacing: 5); progress.alignment = .trailing
        progress.setContentHuggingPriority(.required, for: .horizontal)
        let play = ActionButton(complete ? "Revisit the first file" : (store.saves.drafts[level.id] == nil ? "Open file" : "Continue"), primary: true, accessory: "arrow.right")
        play.accessibilityIdentifier = "home.continue"; play.action = { [weak self] in guard let self = self else { return }; self.store.open(level, from: self) }
        let summary = horizontal([info, progress], spacing: 16)
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { summary.axis = .vertical;summary.alignment = .leading;progress.alignment = .leading;count.textAlignment = .left }
        else { progress.widthAnchor.constraint(equalToConstant: 72).isActive = true }
        add(paperPanel(vertical([art, summary, play], spacing: 12), inset: 10))
        add(textLabel("Explore the archive", .title2, serif: true))
        for chapter in LevelRepository.chapters {
            let levels = store.levels.filter { $0.chapterID == chapter.id }
            let done = levels.filter { store.saves.completed[$0.id] != nil }.count
            let available = store.unlocked(chapter.id)
            let detail = available ? "\(chapter.subtitle) · \(done)/\(levels.count) restored" : "\(chapter.subtitle) · Complete the previous chapter"
            let row = IllustratedArchiveRow(title: chapter.title, detail: detail, imageName: chapterArtwork(chapter.id), locked: !available)
            row.accessibilityIdentifier = "chapter.\(chapter.id)"
            row.action = { [weak self] in
                guard let self = self else { return }
                if available { self.navigationController?.pushViewController(ChapterViewController(store: self.store, chapter: chapter), animated: true) }
                else { self.message("Chapter locked", "Restore every file in the previous chapter to open this one.") }
            }
            add(row)
        }
        let footer = textLabel("Four chapters. Forty mysteries.", .caption1, color: Palette.muted, serif: true)
        footer.textAlignment = .center; add(footer)
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
        add(banner)
        add(textLabel(chapter.story, .body, color: Palette.muted))
        let levels = store.levels.filter { $0.chapterID == chapter.id }
        let done = levels.filter { store.saves.completed[$0.id] != nil }.count
        add(horizontal([textLabel("Case files", .title3, serif: true), UIView(), textLabel("\(done) / \(levels.count) restored", .caption1, color: Palette.muted)]))
        let rows = vertical(spacing: 0)
        for (index, level) in levels.enumerated() {
            if index > 0 { rows.addArrangedSubview(archiveDivider()) }
            let button = ArchiveLevelRow(level: level, completed: store.saves.completed[level.id] != nil, started: store.saves.drafts[level.id] != nil)
            button.accessibilityIdentifier = "level.\(level.number)"
            button.action = { [weak self] in guard let self = self else { return }; self.store.open(level, from: self) }
            rows.addArrangedSubview(button)
        }
        add(paperPanel(rows, inset: 14))
    }
}
final class CollectionViewController: PaperScreen {
    let store: AppStore
    init(store: AppStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "Collection" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); render()
    }
    override func fontChanged() { if isViewLoaded { render() } }
    private func render() {
        clear()
        let total = vertical([textLabel(String(format: "%02d", store.saves.completed.count), .largeTitle, color: Palette.wine, serif: true), textLabel("Restored", .caption1, color: Palette.muted)], spacing: 3)
        total.alignment = .trailing; total.setContentHuggingPriority(.required, for: .horizontal)
        let header = horizontal([textLabel("My collection", .largeTitle, serif: true), total], spacing: 16)
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { header.axis = .vertical; header.alignment = .leading; total.alignment = .leading }
        else { total.widthAnchor.constraint(equalToConstant: 72).isActive = true }
        add(header)
        add(textLabel("Keep every moment of discovery.", .subheadline, color: Palette.muted))
        if store.saves.completed.isEmpty {
            let art = artworkView("LettersEngravingV2"); art.heightAnchor.constraint(equalTo: art.widthAnchor, multiplier: 0.66).isActive = true
            let start = ActionButton(store.saves.drafts[store.nextLevel.id] == nil ? "Open your first file" : "Continue your investigation", primary: true, accessory: "arrow.right"); start.action = { [weak self] in guard let self = self else { return }; self.store.open(self.store.nextLevel, from: self) }
            add(paperPanel(vertical([art, textLabel("A story waiting to be told", .title3, serif: true), textLabel("Restore a file to collect its story, your notes, and a play-by-play replay here.", .body, color: Palette.muted), start])))
        }
        for level in store.levels {
            guard let record = store.saves.completed[level.id] else { continue }
            let review = ActionButton("View replay", accessory: "arrow.right"); review.accessibilityIdentifier = "collection.replay.\(level.number)"
            review.action = { [weak self] in
                guard let self = self else { return }
                guard record.contentRevision == level.contentRevision else { self.message("File updated", "Your completed record is safe. Solve this file again to create a replay for the updated version."); return }
                let replay = ReplayViewController(store: self.store, level: level, board: record.board.map { Optional($0) }, fromCollection: true)
                replay.hidesBottomBarWhenPushed = true; self.navigationController?.pushViewController(replay, animated: true)
            }
            let replayGame = ActionButton("Solve again"); replayGame.action = { [weak self] in guard let self = self else { return }; self.confirmReplay(level) }
            let notes = record.notes
            let art = artworkView(chapterArtwork(level.chapterID))
            NSLayoutConstraint.activate([art.widthAnchor.constraint(equalToConstant: 104),art.heightAnchor.constraint(equalToConstant: 113)])
            let editorial = vertical([textLabel(String(format: "NO. %02d", level.number), .caption1, color: Palette.wine, serif: true), textLabel(level.title, .title2, serif: true), textLabel(level.subtitle, .subheadline, color: Palette.muted), textLabel("✓ Restored", .caption1, color: Palette.green)], spacing: 7)
            let top = horizontal([editorial, art], spacing: 10); top.alignment = .top
            if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { top.axis = .vertical }
            let story = textLabel(level.story, .footnote, color: Palette.muted)
            let actions = horizontal([review, replayGame], spacing: 8); actions.distribution = .fillEqually; actions.alignment = .fill
            if traitCollection.preferredContentSizeCategory.isAccessibilityCategory { actions.axis = .vertical }
            add(paperPanel(vertical([top, story, actions], spacing: 14), inset: 15))
            if !notes.isEmpty { add(paperPanel(vertical([archiveHeading("Notebook", symbol: "pencil"),textLabel(notes, .subheadline, color: Palette.muted)], spacing: 7), inset: 13)) }
        }
    }
    private func confirmReplay(_ level: Level) {
        let alert = UIAlertController(title: "Start this file again?", message: "This resets your card placements for this file. Your completed record stays in your collection.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.addAction(UIAlertAction(title: "Start again", style: .default) { [weak self] _ in
            guard let self = self else { return }; self.store.saves.resetDraft(for: level); self.store.open(level, from: self)
        }); present(alert, animated: true)
    }
}
final class SettingsViewController: PaperScreen {
    let store: AppStore
    init(store: AppStore) { self.store = store; super.init(nibName: nil, bundle: nil); title = "Settings" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        add(textLabel("Settings", .largeTitle, serif: true))
        add(textLabel("Find the truth at your own pace.", .subheadline, color: Palette.muted))
        add(textLabel("Your experience", .title3, serif: true))
        let haptics = UISwitch(); haptics.onTintColor = Palette.wine; haptics.isOn = store.settings.hapticsEnabled
        haptics.addTarget(self, action: #selector(setHaptics(_:)), for: .valueChanged); haptics.accessibilityIdentifier = "settings.haptics"
        let large = UISwitch(); large.onTintColor = Palette.wine; large.isOn = store.settings.largerText
        large.addTarget(self, action: #selector(setLarge(_:)), for: .valueChanged); large.accessibilityIdentifier = "settings.largeText"
        let preferences = vertical([
            ArchiveSettingsRow("Haptic feedback", detail: "A gentle response when you place a card", symbol: "hand.tap", toggle: haptics), archiveDivider(),
            ArchiveSettingsRow("Larger text", detail: "Make cards and clues easier to read", symbol: "textformat.size", toggle: large)
        ], spacing: 0)
        add(paperPanel(preferences, inset: 14))
        add(textLabel("Field guide", .title3, serif: true))
        let rules = ArchiveSettingsRow("How to play", detail: "Rules, clues, and replay", symbol: "book")
        rules.accessibilityIdentifier = "settings.rules"; rules.action = { [weak self] in self?.openGuide(.rules) }
        let storage = ArchiveSettingsRow("Saving your files", detail: "Pick up where you left off", symbol: "archivebox")
        storage.accessibilityIdentifier = "settings.storage"; storage.action = { [weak self] in self?.openGuide(.storage) }
        add(paperPanel(vertical([rules, archiveDivider(), storage], spacing: 0), inset: 14))
        add(textLabel("Privacy", .title3, serif: true))
        let privacy = ArchiveSettingsRow("Privacy Policy", detail: "How your information is handled", symbol: "hand.raised")
        privacy.accessibilityIdentifier = "settings.privacyPolicy"
        privacy.action = { [weak self] in self?.openPrivacyPolicy() }
        add(paperPanel(privacy, inset: 14))
        let brand = SuitMark()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let signature = vertical([brand, textLabel("Card Trace", .title3, serif: true), textLabel("Every card leaves a trace.", .caption1, color: Palette.muted), textLabel("Version \(version)", .caption2, color: Palette.muted)], spacing: 9)
        signature.alignment = .center; signature.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 12, right: 0); signature.isLayoutMarginsRelativeArrangement = true; add(signature)
        if store.saves.isReadOnly { add(textLabel(store.saves.notice ?? "Update the app to keep saving your files.", .body, color: Palette.wine)) }
    }
    private func openGuide(_ topic: ArchiveGuideViewController.Topic) {
        navigationController?.pushViewController(ArchiveGuideViewController(topic: topic), animated: !UIAccessibility.isReduceMotionEnabled)
    }
    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://tkzcpoj.netlify.app/card-trace/privacy-policy/") else { return }
        let browser = SFSafariViewController(url: url)
        browser.preferredBarTintColor = Palette.paper
        browser.preferredControlTintColor = Palette.wine
        browser.dismissButtonStyle = .done
        present(browser, animated: !UIAccessibility.isReduceMotionEnabled)
    }
    @objc private func setHaptics(_ sender: UISwitch) { store.settings.hapticsEnabled = sender.isOn; if sender.isOn { store.haptic() } }
    @objc private func setLarge(_ sender: UISwitch) { store.settings.largerText = sender.isOn; NotificationCenter.default.post(name: .init("CardTraceTextChanged"), object: nil) }
}
