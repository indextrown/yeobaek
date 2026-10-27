import Core
import CrowdPresentation
import Domain
import ThirdParty
import UIKit

/// 장소 행 하나에 표시할 값입니다.
public struct PlaceRowData: Equatable, Sendable {
    public let id: Place.ID
    public let name: String
    public let subtitle: String
    public let level: CongestionLevel

    /// 장소와 혼잡도로 행 데이터를 만듭니다.
    ///
    /// - Parameters:
    ///   - place: 장소입니다.
    ///   - snapshot: 받은 혼잡도입니다. 아직 없으면 `nil`입니다.
    public init(
        place: Place,
        snapshot: CrowdSnapshot?
    ) {
        id = place.id
        name = place.name
        subtitle = CrowdCopy.placeSubtitle(place, snapshot: snapshot)
        level = snapshot?.level ?? .unknown
    }
}

/// 혼잡도 단계를 색과 글자로 함께 보여 주는 배지입니다.
final class LevelBadgeView: UILabel {
    /// 빈 배지를 만듭니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        font = .preferredFont(forTextStyle: .caption1).bold()
        textAlignment = .center
        layer.cornerRadius = 8
        layer.masksToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: max(64, size.width + 16), height: size.height + 8)
    }

    /// 단계를 표시합니다.
    ///
    /// - Parameter level: 표시할 혼잡도 단계입니다.
    func render(
        _ level: CongestionLevel
    ) {
        text = CongestionPalette.title(level)
        textColor = CongestionPalette.text(level)
        backgroundColor = CongestionPalette.tint(level)
    }
}

/// 장소 이름, 보조 문구, 단계 배지를 한 줄로 보여 주는 표 셀입니다. 목록 화면에서 씁니다.
class PlaceRowCell: UITableViewCell {
    class var reuseIdentifier: String { "PlaceRowCell" }

    /// 행 위아래 여백입니다. SwiftUI `List` 행 높이와 맞춥니다.
    class var verticalPadding: CGFloat { 10 }

    private let bar = UIView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badge = LevelBadgeView(frame: .zero)

    /// 행 레이아웃을 구성합니다.
    ///
    /// - Parameters:
    ///   - style: 셀 스타일입니다.
    ///   - reuseIdentifier: 재사용 식별자입니다.
    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        bar.layer.cornerRadius = 2
        nameLabel.font = .preferredFont(forTextStyle: .body).bold()
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel

        let texts = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        texts.axis = .vertical
        texts.spacing = 2
        let row = UIStackView(arrangedSubviews: [bar, texts, UIView(), badge])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            bar.widthAnchor.constraint(equalToConstant: 4),
            bar.heightAnchor.constraint(equalToConstant: 32),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.verticalPadding),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Self.verticalPadding),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 행 데이터를 표시합니다.
    ///
    /// - Parameter data: 표시할 장소 행입니다.
    func render(
        _ data: PlaceRowData
    ) {
        bar.backgroundColor = CongestionPalette.fill(data.level)
        nameLabel.text = data.name
        subtitleLabel.text = data.subtitle
        badge.render(data.level)
        accessibilityLabel = "\(data.name), \(data.subtitle), \(CongestionPalette.title(data.level))"
    }
}

/// 홈 시트의 붐비는 순 행입니다. SwiftUI 시트 행처럼 여백 없이 56pt입니다.
final class SheetPlaceRowCell: PlaceRowCell {
    override class var reuseIdentifier: String { "SheetPlaceRowCell" }
    override class var verticalPadding: CGFloat { 0 }
}

/// 장소 분류를 고르는 가로 칩 목록입니다.
final class CategoryChipsView: UIScrollView {
    /// 사용자가 고른 분류입니다. 전체는 `nil`입니다.
    let categorySelected = PublishRelay<PlaceCategory?>()

    private let stack = UIStackView()
    private var buttons: [(PlaceCategory?, UIButton)] = []

    /// 전체와 공식 분류 다섯 개의 칩을 만듭니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        showsHorizontalScrollIndicator = false
        clipsToBounds = false
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -2),
            stack.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor, constant: -4),
        ])
        let categories: [PlaceCategory?] = [nil] + PlaceCategory.allCases
        for category in categories {
            let button = UIButton(type: .system)
            button.setTitle(category?.rawValue ?? CrowdCopy.allCategories, for: .normal)
            button.titleLabel?.font = .preferredFont(forTextStyle: .footnote).bold()
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            button.layer.cornerRadius = 17
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.1
            button.layer.shadowRadius = 2
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            button.addAction(UIAction { [weak self] _ in self?.categorySelected.accept(category) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append((category, button))
        }
        render(selected: nil)
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 선택한 분류를 강조합니다.
    ///
    /// - Parameter selected: 선택한 분류입니다. 전체는 `nil`입니다.
    func render(
        selected: PlaceCategory?
    ) {
        for (category, button) in buttons {
            let isSelected = category == selected
            button.backgroundColor = isSelected ? .label : .systemBackground
            button.setTitleColor(isSelected ? .systemBackground : .label, for: .normal)
            button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }
}

/// 단계별 장소 수를 막대와 범례로 보여 줍니다.
final class LevelDistributionView: UIView {
    private let bar = UIView()
    private let legend = UIStackView()
    private var counts: [CrowdRanking.LevelCount] = []
    private var segments: [UIView] = []

    /// 막대와 범례를 배치합니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        bar.layer.cornerRadius = 5
        bar.clipsToBounds = true
        legend.spacing = 12
        let stack = UIStackView(arrangedSubviews: [bar, legend])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 10),
            bar.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        isAccessibilityElement = true
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 단계별 장소 수를 표시합니다.
    ///
    /// - Parameter counts: 표시 순서의 단계별 장소 수입니다.
    func render(
        _ counts: [CrowdRanking.LevelCount]
    ) {
        guard counts != self.counts else { return }
        self.counts = counts
        segments.forEach { $0.removeFromSuperview() }
        segments = counts.filter { $0.count > 0 }.map { item in
            let view = UIView()
            view.backgroundColor = CongestionPalette.fill(item.level)
            bar.addSubview(view)
            return view
        }
        legend.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in counts where item.level != .unknown || item.count > 0 {
            let dot = UIView()
            dot.backgroundColor = CongestionPalette.fill(item.level)
            dot.layer.cornerRadius = 4
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            let title = UILabel()
            title.text = CongestionPalette.title(item.level)
            title.font = .preferredFont(forTextStyle: .caption1)
            title.textColor = .secondaryLabel
            let count = UILabel()
            count.text = "\(item.count)"
            count.font = .preferredFont(forTextStyle: .caption1).bold()
            let entry = UIStackView(arrangedSubviews: [dot, title, count])
            entry.alignment = .center
            entry.spacing = 5
            legend.addArrangedSubview(entry)
        }
        accessibilityLabel = counts.map { "\(CongestionPalette.title($0.level)) \($0.count)곳" }.joined(separator: ", ")
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let visible = counts.filter { $0.count > 0 }
        let total = max(1, counts.reduce(0) { $0 + $1.count })
        let available = bar.bounds.width - CGFloat(max(0, visible.count - 1)) * 2
        var x: CGFloat = 0
        for (item, segment) in zip(visible, segments) {
            let width = max(3, available * CGFloat(item.count) / CGFloat(total))
            segment.frame = CGRect(x: x, y: 0, width: width, height: bar.bounds.height)
            x += width + 2
        }
    }
}

/// 상세 화면의 흰색 섹션 카드입니다. 제목, 오른쪽 보조 문구, 내용 스택을 가집니다.
class SectionCardView: UIView {
    /// 섹션 내용을 쌓는 세로 스택입니다.
    let content = UIStackView()

    /// 제목과 보조 문구로 섹션을 만듭니다.
    ///
    /// - Parameters:
    ///   - title: 섹션 제목입니다.
    ///   - trailing: 제목 오른쪽 보조 문구입니다. 없으면 `nil`입니다.
    init(
        title: String,
        trailing: String? = nil
    ) {
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.accessibilityTraits = .header
        let trailingLabel = UILabel()
        trailingLabel.text = trailing
        trailingLabel.font = .preferredFont(forTextStyle: .footnote)
        trailingLabel.textColor = .secondaryLabel
        let header = UIStackView(arrangedSubviews: [titleLabel, UIView(), trailingLabel])
        content.axis = .vertical
        content.spacing = 14
        content.addArrangedSubview(header)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UIFont {
    /// 같은 크기의 굵은 글꼴을 반환합니다.
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

extension UILabel {
    /// 글꼴, 색, 줄 수를 정해 라벨을 만듭니다.
    ///
    /// - Parameters:
    ///   - text: 표시할 문구입니다.
    ///   - style: 동적 글꼴 스타일입니다.
    ///   - color: 글자색입니다.
    ///   - isBold: 굵게 표시하면 `true`입니다.
    ///   - lines: 최대 줄 수입니다. 0이면 제한하지 않습니다.
    convenience init(
        text: String?,
        style: UIFont.TextStyle,
        color: UIColor = .label,
        isBold: Bool = false,
        lines: Int = 1
    ) {
        self.init(frame: .zero)
        self.text = text
        font = isBold ? .preferredFont(forTextStyle: style).bold() : .preferredFont(forTextStyle: style)
        adjustsFontForContentSizeCategory = true
        textColor = color
        numberOfLines = lines
    }
}
