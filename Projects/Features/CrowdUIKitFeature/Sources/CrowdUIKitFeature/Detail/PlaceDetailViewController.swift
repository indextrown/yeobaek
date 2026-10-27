import RxExtension
import ThirdParty
import UIKit

/// UIKit 상세 화면의 수명 주기와 바인딩을 맡습니다.
public final class PlaceDetailViewController: UIViewController {
    private let screen: any PlaceDetailViewProtocol
    private let viewModel: any PlaceDetailViewModelProtocol
    private let disposeBag = DisposeBag()

    /// 상세 View와 ViewModel을 주입받습니다.
    ///
    /// - Parameters:
    ///   - title: 내비게이션 제목으로 쓸 장소 이름입니다.
    ///   - screen: 상세 표시와 입력을 맡는 View입니다.
    ///   - viewModel: 상세 조회와 표시 데이터를 맡는 ViewModel입니다.
    public init(
        title: String,
        screen: any PlaceDetailViewProtocol,
        viewModel: any PlaceDetailViewModelProtocol
    ) {
        self.screen = screen
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.title = title
        navigationItem.largeTitleDisplayMode = .never
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

    /// 주입받은 상세 View를 루트로 설치합니다.
    public override func loadView() {
        view = screen
    }

    /// Input과 Output을 한 번만 연결하고 행사 링크를 엽니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        let output = viewModel.transform(
            input: PlaceDetailInput(
                viewDidAppear: rx.viewDidAppear.asObservable(),
                retryTapped: screen.retryTapped
            ),
            disposeBag: disposeBag
        )
        output.viewData
            .drive(onNext: { [weak self] data in self?.screen.render(data) })
            .disposed(by: disposeBag)
        screen.eventTapped
            .subscribe(onNext: { url in UIApplication.shared.open(url) })
            .disposed(by: disposeBag)
    }
}
