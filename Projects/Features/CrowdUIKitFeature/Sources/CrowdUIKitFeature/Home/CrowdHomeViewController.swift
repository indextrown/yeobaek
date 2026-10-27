import CrowdPresentation
import RxExtension
import ThirdParty
import UIKit

/// UIKit 버전 홈의 수명 주기와 바인딩을 맡습니다. Mapbox 지도 화면을 자식으로 넣고 그 위에 홈 View를 겹칩니다.
public final class CrowdHomeViewController: UIViewController {
    private let screen: any CrowdHomeViewProtocol
    private let viewModel: any CrowdHomeViewModelProtocol
    private let mapViewController: UIViewController
    private let session: MapBoxSession
    private let onRoute: (CrowdUIKitRoute) -> Void
    private let disposeBag = DisposeBag()

    /// 홈 View, ViewModel, 지도 화면과 이동 처리를 주입받습니다.
    ///
    /// - Parameters:
    ///   - screen: 홈 표시와 입력을 맡는 View입니다.
    ///   - viewModel: 홈 입력을 상태와 이동으로 바꾸는 ViewModel입니다.
    ///   - mapViewController: 바탕에 넣을 Mapbox 지도 화면입니다.
    ///   - session: 지도 버튼 여백을 시트 높이에 맞출 지도 상태입니다.
    ///   - onRoute: 목록·상세로 이동할 때 호출할 동작입니다.
    public init(
        screen: any CrowdHomeViewProtocol,
        viewModel: any CrowdHomeViewModelProtocol,
        mapViewController: UIViewController,
        session: MapBoxSession,
        onRoute: @escaping (CrowdUIKitRoute) -> Void
    ) {
        self.screen = screen
        self.viewModel = viewModel
        self.mapViewController = mapViewController
        self.session = session
        self.onRoute = onRoute
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

    /// 주입받은 홈 View를 루트로 설치합니다.
    public override func loadView() {
        view = screen
    }

    /// 지도 화면을 넣고 Input과 Output을 한 번만 연결합니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        embedMap()
        bindViewModel()
    }

    /// 홈에서는 내비게이션 바를 숨깁니다.
    ///
    /// - Parameter animated: 화면 전환 애니메이션 여부입니다.
    public override func viewWillAppear(
        _ animated: Bool
    ) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    /// 목록·상세로 갈 때 내비게이션 바를 다시 보여 줍니다.
    ///
    /// - Parameter animated: 화면 전환 애니메이션 여부입니다.
    public override func viewWillDisappear(
        _ animated: Bool
    ) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    /// Mapbox 지도 화면을 자식으로 넣어 홈 View의 지도 자리에 채웁니다.
    private func embedMap() {
        addChild(mapViewController)
        let mapView = mapViewController.view!
        mapView.translatesAutoresizingMaskIntoConstraints = false
        screen.mapContainerView.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: screen.mapContainerView.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: screen.mapContainerView.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: screen.mapContainerView.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: screen.mapContainerView.bottomAnchor),
        ])
        mapViewController.didMove(toParent: self)
    }

    /// View 입력을 ViewModel에 전달하고 표시와 이동을 연결합니다.
    private func bindViewModel() {
        let output = viewModel.transform(
            input: CrowdHomeInput(
                viewDidAppear: rx.viewDidAppear.asObservable(),
                searchTapped: screen.searchTapped,
                showListTapped: screen.showListTapped,
                showAllTapped: screen.showAllTapped,
                categorySelected: screen.categorySelected,
                retryTapped: screen.retryTapped,
                placeSelected: screen.placeSelected
            ),
            disposeBag: disposeBag
        )

        output.viewData
            .drive(onNext: { [weak self] data in self?.screen.render(data) })
            .disposed(by: disposeBag)

        output.route
            .emit(onNext: { [weak self] route in self?.onRoute(route) })
            .disposed(by: disposeBag)

        screen.sheetHeightSettled
            .subscribe(onNext: { [weak self] height in
                self?.session.updateControlsBottomInset(CrowdSheetLayout.controlsInset(forSheetHeight: height))
            })
            .disposed(by: disposeBag)
    }
}
