import UIKit

func archiveSymbol(_ name: String, color: UIColor = Palette.wine, size: CGFloat = 20) -> UIImageView {
    let image = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .regular)))
    image.tintColor = color; image.contentMode = .scaleAspectFit; image.isAccessibilityElement = false
    image.widthAnchor.constraint(equalToConstant: size + 2).isActive = true
    image.heightAnchor.constraint(equalToConstant: size + 2).isActive = true
    return image
}

func archiveHeading(_ title: String, symbol: String) -> UIView {
    horizontal([archiveSymbol(symbol), textLabel(title, .title3, serif: true)], spacing: 9)
}

func archiveDivider() -> UIView {
    let line = UIView(); line.backgroundColor = Palette.line.withAlphaComponent(0.7)
    line.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
    return line
}

/// One record in a chapter. The number and state carry the hierarchy without repeating artwork.
final class ArchiveLevelRow: UIControl {
    var action: (() -> Void)?
    init(level: Level, completed: Bool, started: Bool) {
        super.init(frame: .zero)
        let number = textLabel(String(format: "%02d", level.number), .title2, color: completed ? Palette.green : Palette.wine, serif: true)
        number.textAlignment = .center; number.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let status = completed ? "Restored" : (started ? "Continue" : "\(level.cards.count) cards · \(level.rules.roundCount) rounds")
        let copy = vertical([textLabel(level.title, .headline, serif: true), textLabel(status, .caption1, color: completed ? Palette.green : Palette.muted)], spacing: 6)
        let content = horizontal([number, copy, archiveSymbol(completed ? "checkmark.circle.fill" : "chevron.right", color: completed ? Palette.green : Palette.muted, size: 16)], spacing: 15)
        content.isUserInteractionEnabled = false; content.translatesAutoresizingMaskIntoConstraints = false; addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: leadingAnchor), content.trailingAnchor.constraint(equalTo: trailingAnchor), content.topAnchor.constraint(equalTo: topAnchor, constant: 15), content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15), heightAnchor.constraint(greaterThanOrEqualToConstant: 76)])
        isAccessibilityElement = true; accessibilityTraits = .button; accessibilityLabel = "File \(level.number), \(level.title), \(status)"
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.55 : 1 } }
    @objc private func tap() { action?() }
}

/// Full-row touch target, with a native switch or a disclosure indicator.
final class ArchiveSettingsRow: UIControl {
    var action: (() -> Void)?
    init(_ title: String, detail: String, symbol: String, toggle: UISwitch? = nil) {
        super.init(frame: .zero)
        let copy = vertical([textLabel(title, .body), textLabel(detail, .caption1, color: Palette.muted)], spacing: 5)
        let leading = horizontal([archiveSymbol(symbol, size: 19), copy], spacing: 13)
        leading.isUserInteractionEnabled = false
        let trailing: UIView = toggle ?? archiveSymbol("chevron.right", color: Palette.muted, size: 13)
        trailing.setContentHuggingPriority(.required, for: .horizontal)
        trailing.setContentCompressionResistancePriority(.required, for: .horizontal)
        let content = horizontal([leading, trailing], spacing: 16)
        content.translatesAutoresizingMaskIntoConstraints = false; addSubview(content)
        NSLayoutConstraint.activate([content.leadingAnchor.constraint(equalTo: leadingAnchor), content.trailingAnchor.constraint(equalTo: trailingAnchor), content.topAnchor.constraint(equalTo: topAnchor, constant: 15), content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15), heightAnchor.constraint(greaterThanOrEqualToConstant: 72)])
        if let toggle = toggle {
            isAccessibilityElement = false
            // The switch announces the same information; avoid a duplicate label stop.
            leading.accessibilityElementsHidden = true
            toggle.accessibilityLabel = title; toggle.accessibilityHint = detail
            action = { [weak toggle] in guard let toggle = toggle else { return }; toggle.setOn(!toggle.isOn, animated: true); toggle.sendActions(for: .valueChanged) }
        } else {
            content.isUserInteractionEnabled = false
            isAccessibilityElement = true; accessibilityTraits = .button; accessibilityLabel = title + ", " + detail
        }
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        var ancestor: UIView? = hit
        while let current = ancestor, current !== self {
            if current is UISwitch { return hit }
            ancestor = current.superview
        }
        return self
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.55 : 1 } }
    @objc private func tap() { action?() }
}

final class ArchiveGuideViewController: PaperScreen {
    enum Topic { case rules, storage }
    private let topic: Topic
    init(topic: Topic) { self.topic = topic; super.init(nibName: nil, bundle: nil); title = topic == .rules ? "How to play" : "Saving your files" }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        let art = artworkView(topic == .rules ? "CardsEngravingV2" : "LettersEngravingV2")
        art.heightAnchor.constraint(equalTo: art.widthAnchor, multiplier: 0.48).isActive = true; add(art)
        let sections: [(String, String)] = topic == .rules ? [
            ("Reconstruct a game from its clues", "Each file contains a partial record and a set of clues. Put every unplaced card back with the right player and round so the game fits all reliable clues."),
            ("01  Follow the lead suit", "Each player plays one card per round. If they still hold the lead suit, they must follow it. Only a player with none of that suit may play another suit. Each card is used once."),
            ("02  Win the round", "There are no trumps. The highest card of the lead suit wins, and its owner leads the next round. Open Rules within a file to see the seating order and first leader."),
            ("03  Check the statements", "Reliable clues are always true. Witness statements may be mistaken: use the exact number of false statements given in the file. Marking them can help you organize your deductions."),
            ("Take your time. Revisit any play.", "Tap a card, then its destination, or drag it directly. Undo takes back a move; hints reveal the reasoning one layer at a time. After solving a file, replay each move to see why it works.")
        ] : [
            ("Every step is remembered", "Your card placements, notes, revealed hints, and completed files are saved automatically on this device. Open a file again to continue where you left off."),
            ("Keep the stories you restore", "Solved files appear in your collection. Replay them or take on the puzzle again whenever you like. Starting again does not delete your completed record."),
            ("Stored on this device", "No account or internet connection is needed. Files do not sync across devices. Uninstalling the app removes its local records, so keep a copy of any notes you need first.")
        ]
        for (heading, copy) in sections { add(vertical([textLabel(heading, .title3, serif: true), textLabel(copy, .body, color: Palette.muted)], spacing: 9)) }
    }
}

final class ReplayStepButton: UIButton {
    var action: (() -> Void)?
    init(symbol: String, label: String, primary: Bool = false) {
        super.init(frame: .zero)
        setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        tintColor = primary ? Palette.card : Palette.wine
        backgroundColor = primary ? Palette.wine : .clear; layer.cornerRadius = 22
        accessibilityLabel = label
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: 44), heightAnchor.constraint(equalToConstant: 44)])
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isEnabled: Bool { didSet { alpha = isEnabled ? 1 : 0.35 } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.65 : (isEnabled ? 1 : 0.35) } }
    @objc private func tap() { action?() }
}
