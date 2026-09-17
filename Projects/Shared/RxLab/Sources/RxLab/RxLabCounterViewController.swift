import ThirdParty
import UIKit

/// RxSwift Input/Output MVVM 카운터의 수명 주기와 바인딩만 담당하는 화면입니다.
///
/// UIKit 컨트롤을 직접 참조하지 않습니다. 주입받은 View가 표시를,
/// 주입받은 ViewModel이 상태 계산을 맡습니다.
public final class RxLabCounterViewController: UIViewController {
    /// 입력 이벤트를 공개하고 표시 데이터를 렌더링하는 View입니다.
    private let screen: any RxLabCounterViewProtocol

    /// 버튼 입력을 카운터 상태로 변환하는 ViewModel입니다.
    private let viewModel: any RxLabCounterViewModelProtocol

    /// ViewController가 가진 Rx 구독의 수명을 관리합니다.
    private let disposeBag = DisposeBag()

    /// 카운터 화면에 사용할 View와 ViewModel 구현체를 주입받습니다.
    ///
    /// - Parameters:
    ///   - screen: 카운터를 표시하고 버튼 이벤트를 공개할 View입니다.
    ///   - viewModel: 버튼 입력을 카운터 상태로 변환할 ViewModel입니다.
    public init(
        screen: any RxLabCounterViewProtocol = RxLabCounterScreenView(frame: .zero),
        viewModel: any RxLabCounterViewModelProtocol = RxLabCounterViewModel()
    ) {
        self.screen = screen
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

    /// 주입받은 View를 화면의 루트로 설치합니다.
    public override func loadView() {
        view = screen
    }

    /// Rx Input과 Output을 한 번만 연결합니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    /// View의 ControlEvent를 Input으로 전달하고 Driver를 `render`에 연결합니다.
    private func bindViewModel() {
        let output = viewModel.transform(
            input: RxLabCounterInput(
                decrementTapped: screen.decrementTapped,
                resetTapped: screen.resetTapped,
                incrementTapped: screen.incrementTapped
            ),
            disposeBag: disposeBag
        )

        output.viewData
            .drive(onNext: { [weak self] data in
                self?.screen.render(data)
            })
            .disposed(by: disposeBag)
    }
}
