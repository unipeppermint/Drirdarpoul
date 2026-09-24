import UIKit

struct CardItem {
    let card: String?
    let slot: Int?
    let caption: String
    let fixed: Bool
    var selected = false
    var highlighted = false
}
private final class CardFace: PaperSurface {
    let emptyBorder = CAShapeLayer()
    override init(frame: CGRect) {
        super.init(frame:frame)
        emptyBorder.fillColor = UIColor.clear.cgColor
        emptyBorder.strokeColor = Palette.muted.withAlphaComponent(0.5).cgColor
        emptyBorder.lineDashPattern = [4,4];emptyBorder.lineWidth = 0.8
        layer.addSublayer(emptyBorder)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews();emptyBorder.frame = bounds
        emptyBorder.path = UIBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),cornerRadius:5).cgPath
    }
}
final class CardCell: UICollectionViewCell {
    private let caption = textLabel("", .caption1, color: Palette.muted, serif: true)
    private let rank = textLabel("", .caption1)
    private let suit = textLabel("", .largeTitle)
    private let lowerRank = textLabel("", .caption1)
    private let fixedMark = textLabel("·", .caption1, color: Palette.wine)
    private let face = CardFace(frame: .zero)
    private var faceWidth: NSLayoutConstraint!
    override init(frame: CGRect) {
        super.init(frame: frame)
        caption.textAlignment = .center; caption.numberOfLines = 1; caption.adjustsFontSizeToFitWidth = true
        rank.numberOfLines = 2; rank.textAlignment = .center
        lowerRank.numberOfLines = 2; lowerRank.textAlignment = .center; lowerRank.transform = CGAffineTransform(rotationAngle: .pi)
        suit.textAlignment = .center
        face.backgroundColor = Palette.card; face.layer.cornerRadius = 5
        face.layer.shadowColor = Palette.ink.cgColor; face.layer.shadowOffset = CGSize(width: 0, height: 2); face.layer.shadowRadius = 2
        [rank,suit,lowerRank,fixedMark].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; face.addSubview($0) }
        NSLayoutConstraint.activate([rank.leadingAnchor.constraint(equalTo:face.leadingAnchor,constant:5),rank.topAnchor.constraint(equalTo:face.topAnchor,constant:4),suit.centerXAnchor.constraint(equalTo:face.centerXAnchor),suit.centerYAnchor.constraint(equalTo:face.centerYAnchor),lowerRank.trailingAnchor.constraint(equalTo:face.trailingAnchor,constant:-5),lowerRank.bottomAnchor.constraint(equalTo:face.bottomAnchor,constant:-4),fixedMark.trailingAnchor.constraint(equalTo:face.trailingAnchor,constant:-7),fixedMark.topAnchor.constraint(equalTo:face.topAnchor,constant:3)])
        let content = vertical([caption,face],spacing:4);content.alignment = .center
        content.translatesAutoresizingMaskIntoConstraints = false;contentView.addSubview(content)
        faceWidth = face.widthAnchor.constraint(equalToConstant:72);faceWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([content.topAnchor.constraint(equalTo:contentView.topAnchor),content.bottomAnchor.constraint(equalTo:contentView.bottomAnchor,constant:-4),content.leadingAnchor.constraint(equalTo:contentView.leadingAnchor,constant:3),content.trailingAnchor.constraint(equalTo:contentView.trailingAnchor,constant:-3),caption.widthAnchor.constraint(equalTo:content.widthAnchor),face.widthAnchor.constraint(lessThanOrEqualTo:content.widthAnchor),faceWidth])
        isAccessibilityElement = true;accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError() }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        faceWidth.constant = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 108 : 72
    }
    func show(_ item: CardItem, readOnly: Bool, context: String, remove: (() -> Void)?) {
        caption.text = item.caption
        if let id = item.card {
            let card = Card(id:id); rank.text = "\(card.rank)\n\(card.symbol)"; lowerRank.text = rank.text; suit.text = card.symbol
            rank.textColor = card.isRed ? Palette.wine : Palette.ink;suit.textColor = rank.textColor;lowerRank.textColor = rank.textColor
            accessibilityLabel = "\(item.caption)，\(card.spoken)，\(item.fixed ? "已知固定牌" : "可移动")"
        } else {
            rank.text = nil;lowerRank.text = nil;suit.text = "?";suit.textColor = Palette.muted.withAlphaComponent(0.6);accessibilityLabel = "\(item.caption)，空位"
        }
        fixedMark.isHidden = !item.fixed
        face.emptyBorder.isHidden = item.card != nil || item.selected
        face.layer.shadowOpacity = item.card == nil ? 0 : 0.14
        face.backgroundColor = item.card == nil || item.highlighted ? Palette.wash.withAlphaComponent(0.5) : Palette.card
        face.layer.borderWidth = item.selected ? 2 : (item.card == nil ? 0 : 0.7);face.layer.borderColor = (item.selected ? Palette.wine : Palette.line).cgColor
        accessibilityValue = item.selected ? "已选中" : nil
        if readOnly { accessibilityLabel = "\(context)，\(item.caption)，" + (item.card.map { Card(id:$0).spoken } ?? "尚未回放") }
        else { accessibilityLabel = context + "，" + (accessibilityLabel ?? "") }
        accessibilityHint = readOnly ? "点按可定位复盘到这一手" : item.fixed ? "公开事实，不可移动" : "点选牌后，再点选目标位置；也可以拖拽"
        accessibilityCustomActions = remove.map { callback in [UIAccessibilityCustomAction(name:"移回待归位牌",actionHandler:{ _ in callback();return true })] }
        accessibilityIdentifier = item.slot.map { "slot.\($0)" } ?? "pool.\(item.card ?? "empty")"
        faceWidth.constant = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 108 : 72
    }
}
final class CardGrid: UICollectionView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    var items: [CardItem] = [] { didSet { reloadData(); invalidateIntrinsicContentSize(); setNeedsLayout() } }
    var onTap: ((CardItem) -> Void)?
    var onDropCard: ((String, Int?) -> Void)?
    var onRemove: ((String) -> Void)?
    var allowsEditing = true
    var accessibilityContext = "待归位牌"
    private var sizeConstraint: NSLayoutConstraint!
    private var columns: Int { traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 2 : 3 }
    private var itemHeight: CGFloat { traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 185 : 125 }
    init() {
        let layout = UICollectionViewFlowLayout(); layout.minimumInteritemSpacing = 8; layout.minimumLineSpacing = 12
        super.init(frame: .zero, collectionViewLayout: layout)
        backgroundColor = .clear; isScrollEnabled = false; dataSource = self; delegate = self; dragDelegate = self; dropDelegate = self
        dragInteractionEnabled = true; register(CardCell.self, forCellWithReuseIdentifier: "card")
        sizeConstraint = heightAnchor.constraint(equalToConstant: 125); sizeConstraint.isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        let rows = CGFloat((items.count + columns - 1) / columns)
        let height = rows == 0 ? 0 : rows * itemHeight + (rows - 1) * 12
        if sizeConstraint.constant != height { sizeConstraint.constant = height }
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection); collectionViewLayout.invalidateLayout(); reloadData(); setNeedsLayout()
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = dequeueReusableCell(withReuseIdentifier: "card", for: indexPath) as! CardCell
        let item = items[indexPath.item]
        let remove: (() -> Void)? = item.card != nil && item.slot != nil && !item.fixed && allowsEditing ? { [weak self] in self?.onRemove?(item.card!) } : nil
        cell.show(item, readOnly: !allowsEditing, context: accessibilityContext, remove: remove); return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: max(44, (bounds.width - CGFloat(columns - 1)*8)/CGFloat(columns)), height: itemHeight)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { onTap?(items[indexPath.item]) }
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = items[indexPath.item]
        guard allowsEditing, !item.fixed, let card = item.card else { return [] }
        let drag = UIDragItem(itemProvider: NSItemProvider(object: card as NSString)); drag.localObject = card; return [drag]
    }
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool { allowsEditing && session.localDragSession != nil }
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard let index = destinationIndexPath, index.item < items.count, !items[index.item].fixed else { return UICollectionViewDropProposal(operation: .forbidden) }
        return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
    }
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let index = coordinator.destinationIndexPath, index.item < items.count, !items[index.item].fixed,
              let drag = coordinator.items.first, let card = drag.dragItem.localObject as? String else { return }
        // State commits once, independent of animation completion or cancellation.
        coordinator.drop(drag.dragItem, toItemAt: index); onDropCard?(card, items[index.item].slot)
    }
}
