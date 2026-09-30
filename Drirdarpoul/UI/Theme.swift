import UIKit

enum Palette {
    static let paper = UIColor(hex: 0xF6F2E8)
    static let ink = UIColor(hex: 0x252B27)
    static let wine = UIColor(hex: 0x833D46)
    static let muted = UIColor(hex: 0x736F64)
    static let line = UIColor(hex: 0xD9D0BF)
    static let card = UIColor(hex: 0xFFFCF4)
    static let green = UIColor(hex: 0x51674F)
    static let wash = UIColor(hex: 0xEBE5D8)
}
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}
func archiveFont(_ style: UIFont.TextStyle, serif: Bool = false) -> UIFont {
    guard serif else { return UIFont.preferredFont(forTextStyle: style) }
    let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
    let face = UIFont(descriptor: descriptor.withDesign(.serif) ?? descriptor, size: descriptor.pointSize)
    return UIFontMetrics(forTextStyle: style).scaledFont(for: face)
}
func textLabel(_ text: String, _ style: UIFont.TextStyle = .body, color: UIColor = Palette.ink, serif: Bool = false) -> UILabel {
    let label = UILabel()
    label.text = text; label.textColor = color; label.numberOfLines = 0
    label.font = archiveFont(style, serif: serif)
    label.adjustsFontForContentSizeCategory = true
    return label
}
func vertical(_ views: [UIView] = [], spacing: CGFloat = 12) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views); stack.axis = .vertical; stack.spacing = spacing
    return stack
}
func horizontal(_ views: [UIView], spacing: CGFloat = 10) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views); stack.axis = .horizontal; stack.spacing = spacing; stack.alignment = .center
    return stack
}
func paperPanel(_ content: UIView, inset: CGFloat = 16) -> UIView {
    let view = PaperSurface(); view.backgroundColor = Palette.card; view.layer.cornerRadius = 9
    view.layer.shadowColor = UIColor(hex: 0x514332).cgColor; view.layer.shadowOpacity = 0.10; view.layer.shadowOffset = CGSize(width: 0, height: 2); view.layer.shadowRadius = 3
    view.layer.borderColor = Palette.line.cgColor; view.layer.borderWidth = 1
    content.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(content)
    NSLayoutConstraint.activate([content.topAnchor.constraint(equalTo: view.topAnchor, constant: inset), content.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -inset), content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset), content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -inset)])
    return view
}
final class ActionButton: UIButton {
    private let shading = CAGradientLayer()
    var action: (() -> Void)?
    init(_ title: String, primary: Bool = false, symbol: String? = nil, accessory: String? = nil) {
        super.init(frame: .zero)
        setTitle(title, for: .normal); setTitleColor(primary ? Palette.card : Palette.wine, for: .normal)
        setTitleColor(Palette.muted, for: .disabled)
        titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.numberOfLines = 0; titleLabel?.textAlignment = .center
        backgroundColor = primary ? Palette.wine : Palette.card
        contentEdgeInsets = UIEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
        layer.cornerRadius = 9; layer.borderWidth = 1; layer.borderColor = (primary ? UIColor(hex: 0x70313B) : Palette.line).cgColor
        if primary {
            shading.colors = [UIColor(hex: 0x934B54).cgColor, Palette.wine.cgColor, UIColor(hex: 0x76353F).cgColor]
            shading.startPoint = CGPoint(x: 0, y: 0); shading.endPoint = CGPoint(x: 1, y: 1); shading.cornerRadius = 9
            layer.insertSublayer(shading, at: 0)
            layer.shadowColor = Palette.wine.cgColor; layer.shadowOpacity = 0.16; layer.shadowRadius = 3; layer.shadowOffset = CGSize(width: 0, height: 2)
        }
        if let symbol = symbol { setImage(UIImage(systemName: symbol), for: .normal); tintColor = primary ? Palette.card : Palette.wine; imageEdgeInsets.right = 8 }
        if let accessory = accessory {
            let icon = archiveSymbol(accessory, color: primary ? Palette.card : Palette.wine, size: 17)
            icon.translatesAutoresizingMaskIntoConstraints = false; addSubview(icon)
            NSLayoutConstraint.activate([icon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16), icon.centerYAnchor.constraint(equalTo: centerYAnchor)])
            contentEdgeInsets.right = 44; contentHorizontalAlignment = .left; titleLabel?.textAlignment = .left
        }
        heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() { super.layoutSubviews(); shading.frame = bounds }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.72 : (isEnabled ? 1 : 0.45) } }
    override var isEnabled: Bool { didSet { alpha = isEnabled ? 1 : 0.45 } }
    @objc private func tapped() { action?() }
}
class PaperScreen: UIViewController, UIScrollViewDelegate {
    let scroll = UIScrollView()
    let stack = vertical(spacing: 16)
    var scrollBottom: NSLayoutConstraint!
    private var savedScrollOffset = CGPoint.zero
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = Palette.paper
        let texture = UIImageView(image: UIImage(named: "PaperTextureV2")); texture.contentMode = .scaleAspectFill; texture.alpha = 0.58; texture.isUserInteractionEnabled = false; texture.isAccessibilityElement = false
        texture.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(texture)
        NSLayoutConstraint.activate([texture.topAnchor.constraint(equalTo: view.topAnchor), texture.bottomAnchor.constraint(equalTo: view.bottomAnchor), texture.leadingAnchor.constraint(equalTo: view.leadingAnchor), texture.trailingAnchor.constraint(equalTo: view.trailingAnchor)])
        // The scroll view is already constrained to the safe area; avoid a second navigation-bar inset.
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delegate = self
        scroll.alwaysBounceVertical = true; scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.addSubview(stack)
        scrollBottom = scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scrollBottom,
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 14), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24), stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)])
        NotificationCenter.default.addObserver(self, selector: #selector(fontChanged), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(navigationController?.viewControllers.first === self, animated: animated)
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Preserve intentional scrolling, not UIKit's automatic offset during navigation transitions.
        if scrollView.isDragging || scrollView.isDecelerating { savedScrollOffset = scrollView.contentOffset }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.layoutIfNeeded()
        let maximum = max(0, scroll.contentSize.height - scroll.bounds.height)
        scroll.setContentOffset(CGPoint(x: 0, y: min(max(0, savedScrollOffset.y), maximum)), animated: false)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory { fontChanged() }
    }
    @objc func fontChanged() { view.setNeedsLayout() }
    func clear() { stack.arrangedSubviews.forEach { $0.removeFromSuperview() } }
    func add(_ view: UIView) { stack.addArrangedSubview(view) }
    func message(_ title: String, _ text: String) {
        let alert = UIAlertController(title: title, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
}

/// Image assets are decorative; all game facts and controls remain native UIKit.
final class ArchiveIllustration: UIImageView {
    init(motif: Int = 0) {
        let names = ["TrainEngravingV2", "CardsEngravingV2", "TeaEngravingV2", "LettersEngravingV2"]
        super.init(image: UIImage(named: names[motif % names.count]))
        contentMode = .scaleAspectFill; clipsToBounds = true; layer.cornerRadius = 5
        isAccessibilityElement = false; isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }
}
class PaperSurface: UIView {
    private let texture = UIImageView(image: UIImage(named: "PaperTextureV2"))
    override init(frame: CGRect) {
        super.init(frame: frame); texture.contentMode = .scaleAspectFill; texture.alpha = 0.32
        texture.isUserInteractionEnabled = false; texture.isAccessibilityElement = false; texture.clipsToBounds = true
        addSubview(texture)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); texture.frame = bounds; texture.layer.cornerRadius = layer.cornerRadius }
}
func chapterArtwork(_ id: String) -> String {
    ["chapter01": "CardsEngravingV2", "chapter02": "TrainEngravingV2", "chapter03": "TeaEngravingV2", "chapter04": "LettersEngravingV2"][id] ?? "TrainEngravingV2"
}
func artworkView(_ name: String) -> UIImageView {
    let image = UIImageView(image: UIImage(named: name)); image.contentMode = .scaleAspectFill; image.clipsToBounds = true
    image.layer.cornerRadius = 5; image.isAccessibilityElement = false; image.isUserInteractionEnabled = false
    return image
}
final class IllustratedArchiveRow: UIControl {
    var action: (() -> Void)?
    init(title: String, detail: String, imageName: String, locked: Bool = false) {
        super.init(frame: .zero)
        let image = artworkView(imageName)
        NSLayoutConstraint.activate([image.widthAnchor.constraint(equalToConstant: 76), image.heightAnchor.constraint(equalToConstant: 68)])
        let copy = vertical([textLabel(title, .headline, serif: true), textLabel(detail, .caption1, color: Palette.muted)], spacing: 5)
        let arrow = UIImageView(image: UIImage(systemName: locked ? "lock.fill" : "chevron.right")); arrow.tintColor = Palette.muted; arrow.contentMode = .scaleAspectFit
        arrow.widthAnchor.constraint(equalToConstant: 14).isActive = true
        let content = horizontal([image, copy, arrow], spacing: 12); content.isUserInteractionEnabled = false
        let panel = paperPanel(content, inset: 9); panel.isUserInteractionEnabled = false
        panel.translatesAutoresizingMaskIntoConstraints = false; addSubview(panel)
        NSLayoutConstraint.activate([panel.leadingAnchor.constraint(equalTo: leadingAnchor),panel.trailingAnchor.constraint(equalTo: trailingAnchor),panel.topAnchor.constraint(equalTo: topAnchor),panel.bottomAnchor.constraint(equalTo: bottomAnchor)])
        isAccessibilityElement = true; accessibilityTraits = .button; accessibilityLabel = title + ", " + detail
        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.65 : 1 } }
    @objc private func tap() { action?() }
}
final class SuitMark: UIView {
    init() {
        super.init(frame: .zero); isAccessibilityElement = false; accessibilityElementsHidden = true
        layer.borderWidth = 0.6; layer.borderColor = Palette.muted.withAlphaComponent(0.45).cgColor
        widthAnchor.constraint(equalToConstant: 42).isActive = true; heightAnchor.constraint(equalToConstant: 46).isActive = true
        let top = horizontal([textLabel("♠", .title3),textLabel("♥", .title3, color: Palette.wine)],spacing: 0)
        let bottom = horizontal([textLabel("♦", .title3, color: Palette.wine),textLabel("♣", .title3)],spacing: 0)
        [top,bottom].forEach { $0.distribution = .fillEqually; $0.arrangedSubviews.forEach { if let label = $0 as? UILabel { label.textAlignment = .center;label.font = .systemFont(ofSize:20);label.adjustsFontForContentSizeCategory = false } } }
        let symbols = vertical([top,bottom],spacing:0); symbols.translatesAutoresizingMaskIntoConstraints = false; addSubview(symbols)
        NSLayoutConstraint.activate([symbols.leadingAnchor.constraint(equalTo:leadingAnchor,constant:2),symbols.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-2),symbols.topAnchor.constraint(equalTo:topAnchor),symbols.bottomAnchor.constraint(equalTo:bottomAnchor)])
    }
    required init?(coder: NSCoder) { fatalError() }
}
final class WaxSeal: UIView {
    override init(frame: CGRect) { super.init(frame:frame); backgroundColor = .clear; isAccessibilityElement = false; heightAnchor.constraint(equalToConstant:54).isActive = true }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        let seal = CGRect(x:bounds.midX-24,y:3,width:48,height:48)
        c.setShadow(offset:CGSize(width:0,height:2),blur:3,color:Palette.ink.withAlphaComponent(0.25).cgColor)
        c.setFillColor(Palette.wine.cgColor);c.fillEllipse(in:seal);c.setShadow(offset:.zero,blur:0)
        c.setStrokeColor(UIColor(hex:0xAF6D73).cgColor);c.setLineWidth(1.5);c.strokeEllipse(in:seal.insetBy(dx:3,dy:3))
        c.setStrokeColor(UIColor(hex:0x5E2630).cgColor);c.strokeEllipse(in:seal.insetBy(dx:6,dy:6))
        let check=UIBezierPath();check.move(to:CGPoint(x:bounds.midX-9,y:26));check.addLine(to:CGPoint(x:bounds.midX-2,y:33));check.addLine(to:CGPoint(x:bounds.midX+10,y:20));check.lineWidth=2;Palette.card.setStroke();check.stroke()
    }
}
