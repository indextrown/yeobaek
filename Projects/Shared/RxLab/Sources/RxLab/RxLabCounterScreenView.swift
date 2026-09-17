import ThirdParty
import UIKit

/// RxLab 카운터의 레이아웃과 표시를 담당하는 UIKit View입니다.
///
/// 카운터 값을 계산하거나 ViewModel을 보관하지 않습니다. 버튼 이벤트를 공개하고
/// 전달받은 표시 데이터를 그대로 반영하기만 합니다.
public final class RxLabCounterScreenView: UIView, RxLabCounterViewProtocol {
    /// 현재 카운터 값을 크게 표시합니다.
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 104, weight: .bold)
        label.textColor = UIColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 1)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.accessibilityIdentifier = "rx-lab-counter-value"
        return label
    }()

    /// 카운터 값을 1만큼 줄이는 버튼입니다.
    private let decrementButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "감소"
        configuration.image = UIImage(systemName: "minus")
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor(red: 0.16, green: 0.35, blue: 0.38, alpha: 1)
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "rx-lab-counter-decrement"
        return button
    }()

    /// 카운터 값을 처음 값으로 되돌리는 버튼입니다.
    private let resetButton: UIButton = {
        var configuration = UIButton.Configuration.gray()
        configuration.title = "초기화"
        configuration.cornerStyle = .capsule
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "rx-lab-counter-reset"
        return button
    }()

    /// 카운터 값을 1만큼 늘리는 버튼입니다.
    private let incrementButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "증가"
        configuration.image = UIImage(systemName: "plus")
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor(red: 0.94, green: 0.38, blue: 0.18, alpha: 1)
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "rx-lab-counter-increment"
        return button
    }()

    public var decrementTapped: Observable<Void> {
        decrementButton.rx.tap.asObservable()
    }

    public var resetTapped: Observable<Void> {
        resetButton.rx.tap.asObservable()
    }

    public var incrementTapped: Observable<Void> {
        incrementButton.rx.tap.asObservable()
    }

    /// 실험 화면의 제목, 카운터 카드와 조작 버튼을 배치합니다.
    ///
    /// - Parameter frame: View의 초기 프레임입니다.
    public override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        configureLayout()
    }

    /// 코드로만 생성하므로 아카이브에서 복원할 수 없습니다.
    ///
    /// - Parameter coder: 사용하지 않는 아카이브 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    /// ViewModel이 만든 카운터 상태를 표시합니다.
    ///
    /// - Parameter data: 표시할 카운터 문구와 버튼 활성화 상태입니다.
    public func render(
        _ data: RxLabCounterViewData
    ) {
        countLabel.text = data.countText
        decrementButton.isEnabled = data.isDecrementEnabled
        resetButton.isEnabled = data.isResetEnabled
    }

    /// 카드 배경과 스택 레이아웃을 구성합니다.
    private func configureLayout() {
        backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.87, alpha: 1)

        let eyebrowLabel = UILabel()
        eyebrowLabel.text = "RX LAB"
        eyebrowLabel.font = .systemFont(ofSize: 14, weight: .heavy)
        eyebrowLabel.textColor = UIColor(red: 0.94, green: 0.38, blue: 0.18, alpha: 1)
        eyebrowLabel.textAlignment = .center

        let titleLabel = UILabel()
        titleLabel.text = "Input이 들어오면\nOutput이 바뀌어요"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let buttonStack = UIStackView(
            arrangedSubviews: [decrementButton, resetButton, incrementButton]
        )
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 10

        let contentStack = UIStackView(
            arrangedSubviews: [eyebrowLabel, titleLabel, countLabel, buttonStack]
        )
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 24

        let cardView = UIView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 32
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowRadius = 24
        cardView.layer.shadowOffset = CGSize(width: 0, height: 12)
        cardView.addSubview(contentStack)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 36),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -36),
            countLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 132),
            buttonStack.heightAnchor.constraint(equalToConstant: 52),
        ])
    }
}
