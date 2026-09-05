import ThirdParty
import UIKit

/// RxSwift Input/Output MVVM 카운터를 표시하는 UIKit 화면입니다.
public final class RxLabCounterViewController: UIViewController {
    /// 버튼 입력을 카운터 상태로 변환하는 ViewModel입니다.
    private let viewModel: RxLabCounterViewModel

    /// ViewController가 가진 Rx 구독의 수명을 관리합니다.
    private let disposeBag = DisposeBag()

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

    /// RxLab 카운터 화면에 사용할 ViewModel을 주입합니다.
    ///
    /// - Parameter viewModel: 버튼 입력과 카운터 출력을 연결할 ViewModel입니다.
    public init(
        viewModel: RxLabCounterViewModel = RxLabCounterViewModel()
    ) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    /// Storyboard 생성을 지원하지 않는 코드 기반 화면입니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 카운터 UI를 배치하고 Rx Input과 Output을 연결합니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        bindViewModel()
    }

    /// 실험 화면의 제목, 카운터 카드, 조작 버튼을 배치합니다.
    private func configureView() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.87, alpha: 1)

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
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 36),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -36),
            countLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 132),
            buttonStack.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    /// 버튼의 ControlEvent를 Input으로 전달하고 Driver를 UIKit에 연결합니다.
    private func bindViewModel() {
        let output = viewModel.transform(
            input: RxLabCounterViewModel.Input(
                decrementTapped: decrementButton.rx.tap.asObservable(),
                resetTapped: resetButton.rx.tap.asObservable(),
                incrementTapped: incrementButton.rx.tap.asObservable()
            )
        )

        output.countText
            .drive(countLabel.rx.text)
            .disposed(by: disposeBag)

        output.isDecrementEnabled
            .drive(decrementButton.rx.isEnabled)
            .disposed(by: disposeBag)

        output.isResetEnabled
            .drive(resetButton.rx.isEnabled)
            .disposed(by: disposeBag)
    }
}
