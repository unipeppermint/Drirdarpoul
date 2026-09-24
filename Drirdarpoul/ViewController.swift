import UIKit

final class ViewController: UIViewController, UINavigationControllerDelegate {
    private var viewControllers: [UINavigationController] = []
    private var selectedIndex = 0
    private let content = UIView()
    private let bottomBar = PaperSurface()
    private var contentBottom: NSLayoutConstraint!
    private var tabButtons: [ArchiveTabButton] = []
    private var store: AppStore?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.paper
        do {
            let appStore = try AppStore(); store = appStore
            let pages: [(UIViewController, String, String)] = [(HomeViewController(store: appStore), "档案", "folder"), (CollectionViewController(store: appStore), "收藏", "star"), (SettingsViewController(store: appStore), "设置", "gearshape")]
            viewControllers = pages.map { controller, title, symbol in
                let nav = UINavigationController(rootViewController: controller)
                nav.delegate = self
                nav.navigationBar.tintColor = Palette.wine
                let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = Palette.paper; appearance.shadowColor = .clear
                appearance.titleTextAttributes = [.foregroundColor: Palette.ink, .font: archiveFont(.headline, serif: true)]
                nav.navigationBar.standardAppearance = appearance; nav.navigationBar.scrollEdgeAppearance = appearance; nav.navigationBar.compactAppearance = appearance
                return nav
            }
            configureTabs(pages: pages)
            NotificationCenter.default.addObserver(self, selector: #selector(updateText), name: .init("CardTraceTextChanged"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(flush), name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(updateText), name: UIContentSizeCategory.didChangeNotification, object: nil)
            updateText()
        } catch {
            let label = textLabel("档案暂时无法打开\n\(error.localizedDescription)", .body, color: Palette.wine)
            label.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(label)
            NSLayoutConstraint.activate([label.centerYAnchor.constraint(equalTo: view.centerYAnchor), label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)])
        }
    }
    private func configureTabs(pages: [(UIViewController, String, String)]) {
        content.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = Palette.paper
        view.addSubview(content); view.addSubview(bottomBar)
        let divider = UIView(); divider.backgroundColor = Palette.line
        divider.translatesAutoresizingMaskIntoConstraints = false; bottomBar.addSubview(divider)
        let row = UIStackView(); row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false; bottomBar.addSubview(row)
        for (index, page) in pages.enumerated() {
            let button = ArchiveTabButton(title: page.1, symbol: page.2)
            button.tag = index; button.accessibilityIdentifier = "tab.\(index)"
            button.addTarget(self, action: #selector(selectTab(_:)), for: .touchUpInside)
            row.addArrangedSubview(button); tabButtons.append(button)
        }
        contentBottom = content.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.topAnchor), content.leadingAnchor.constraint(equalTo: view.leadingAnchor), content.trailingAnchor.constraint(equalTo: view.trailingAnchor), contentBottom,
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor), bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor), bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -58),
            divider.topAnchor.constraint(equalTo: bottomBar.topAnchor), divider.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor), divider.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor), divider.heightAnchor.constraint(equalToConstant: 0.5),
            row.topAnchor.constraint(equalTo: bottomBar.topAnchor), row.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor), row.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor), row.heightAnchor.constraint(equalToConstant: 58)
        ])
        showTab(0)
    }
    @objc private func selectTab(_ sender: ArchiveTabButton) { showTab(sender.tag) }
    private func showTab(_ index: Int) {
        if let old = children.first {
            guard old !== viewControllers[index] else { return }
            old.willMove(toParent: nil); old.view.removeFromSuperview(); old.removeFromParent()
        }
        selectedIndex = index
        let nav = viewControllers[index]
        addChild(nav); nav.view.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(nav.view)
        NSLayoutConstraint.activate([nav.view.topAnchor.constraint(equalTo: content.topAnchor), nav.view.bottomAnchor.constraint(equalTo: content.bottomAnchor), nav.view.leadingAnchor.constraint(equalTo: content.leadingAnchor), nav.view.trailingAnchor.constraint(equalTo: content.trailingAnchor)])
        nav.didMove(toParent: self)
        tabButtons.enumerated().forEach { $0.element.isSelected = $0.offset == index }
        updateBar(for: nav.topViewController)
        updateText()
    }
    private func updateBar(for controller: UIViewController?) {
        let hidden = controller?.hidesBottomBarWhenPushed == true
        bottomBar.isHidden = hidden
        contentBottom.isActive = false
        contentBottom = content.bottomAnchor.constraint(equalTo: hidden ? view.bottomAnchor : bottomBar.topAnchor)
        contentBottom.isActive = true
    }
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        guard navigationController === viewControllers[selectedIndex] else { return }
        updateBar(for: viewController)
    }
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        guard navigationController === viewControllers[selectedIndex] else { return }
        updateBar(for: viewController)
    }
    @objc private func updateText() {
        let system = UIApplication.shared.preferredContentSizeCategory
        let size = system.isAccessibilityCategory ? system : UIContentSizeCategory.accessibilityMedium
        for child in children { setOverrideTraitCollection(store?.settings.largerText == true ? UITraitCollection(preferredContentSizeCategory: size) : nil, forChild: child) }
    }
    @objc private func flush() { _ = store?.saves.saveNow() }
    deinit { NotificationCenter.default.removeObserver(self) }
}

/// Fixed, full-width paper navigation matching the product prototype on every supported OS.
private final class ArchiveTabButton: UIControl {
    private let icon = UIImageView()
    private let caption = UILabel()
    private let symbol: String
    init(title: String, symbol: String) {
        self.symbol = symbol
        super.init(frame: .zero)
        isAccessibilityElement = true; accessibilityLabel = title
        icon.contentMode = .scaleAspectFit
        caption.text = title; caption.font = .systemFont(ofSize: 11); caption.textAlignment = .center
        icon.translatesAutoresizingMaskIntoConstraints = false; caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon); addSubview(caption)
        NSLayoutConstraint.activate([icon.centerXAnchor.constraint(equalTo: centerXAnchor), icon.topAnchor.constraint(equalTo: topAnchor, constant: 9), icon.widthAnchor.constraint(equalToConstant: 23), icon.heightAnchor.constraint(equalToConstant: 23), caption.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 4), caption.centerXAnchor.constraint(equalTo: centerXAnchor)])
        updateAppearance()
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isSelected: Bool { didSet { updateAppearance() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.6 : 1 } }
    private func updateAppearance() {
        let color = isSelected ? Palette.wine : Palette.muted
        icon.image = UIImage(systemName: symbol + (isSelected && symbol != "gearshape" ? ".fill" : ""), withConfiguration: UIImage.SymbolConfiguration(pointSize: 21, weight: .regular))
        icon.tintColor = color; caption.textColor = color
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
