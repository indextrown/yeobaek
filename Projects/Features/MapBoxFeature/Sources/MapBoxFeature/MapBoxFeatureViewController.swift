import Foundation
import RxCocoa
import RxExtension
import RxSwift
import UIKit

/// Mapbox 화면의 수명 주기와 Rx 바인딩만 담당하는 ViewController입니다.
///
/// UIKit 컨트롤이나 지도 SDK 객체를 직접 참조하지 않습니다. 표시는 주입받은
/// `MapBoxScreenView`가, 상태 계산은 주입받은 ViewModel이 맡습니다.
public final class MapBoxFeatureViewController: UIViewController {
    /// 자동 위치 요청 여부와 마지막 지도 카메라를 유지하는 상태입니다.
    private let session: MapBoxSession

    /// 지도와 컨트롤을 표시하고 입력 이벤트를 공개하는 View입니다.
    private let screen: any MapBoxFeatureScreenProtocol

    /// 화면 입력을 위치 조회 상태와 출력으로 변환하는 Rx ViewModel입니다.
    private let viewModel: any MapBoxFeatureViewModelProtocol

    /// 지도 전환 후에도 조회 결과를 유지하는 혼잡도 ViewModel입니다.
    private let crowdViewModel: (any MapBoxCrowdViewModelProtocol)?

    /// ViewModel Output 구독의 수명을 ViewController와 함께 관리합니다.
    private let disposeBag = DisposeBag()

    /// 동일한 위치 오류 알림을 중복으로 표시하지 않기 위한 식별자입니다.
    private var presentedAlertID: UUID?

    /// 앱 수명 상태, 화면 View와 Rx ViewModel을 주입해 Mapbox 화면을 만듭니다.
    ///
    /// - Parameters:
    ///   - session: 자동 요청 여부와 마지막 카메라를 보관하는 앱 수명 상태입니다.
    ///   - screen: 지도와 컨트롤을 표시할 View입니다.
    ///   - viewModel: 위치 조회 입력을 상태로 변환할 ViewModel입니다.
    public init(
        session: MapBoxSession,
        screen: any MapBoxFeatureScreenProtocol,
        viewModel: any MapBoxFeatureViewModelProtocol
    ) {
        self.session = session
        self.screen = screen
        self.viewModel = viewModel
        self.crowdViewModel = session.crowdViewModel
        super.init(nibName: nil, bundle: nil)
    }

    /// 앱 수명 상태만으로 기본 View와 ViewModel을 조립해 화면을 만듭니다.
    ///
    /// Demo와 Preview처럼 DI Container를 거치지 않는 실행 환경에서 사용합니다.
    ///
    /// - Parameter session: 자동 요청 여부와 마지막 카메라를 보관하는 앱 수명 상태입니다.
    public convenience init(
        session: MapBoxSession
    ) {
        let screen = MapBoxScreenView(
            initialCamera: session.camera,
            showsCrowdOverlay: session.crowdViewModel != nil
        )
        self.init(
            session: session,
            screen: screen,
            viewModel: MapBoxFeatureViewModel(screenProvider: screen.makeLocationProvider())
        )
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

    /// 위치와 혼잡도 Output을 한 번만 연결합니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        bindCamera()
    }

    /// 두 ViewModel의 Output을 하나의 표시 데이터로 합쳐 View에 전달합니다.
    private func bindViewModel() {
        let viewDidAppear = rx.viewDidAppear
            .filter { [weak self] in
                self?.session.registerAutomaticRequestIfNeeded() == true
            }
        let currentLocationTapped = screen.currentLocationTapped
            .do(onNext: { [weak self] in
                self?.session.registerManualRequest()
            })

        let output = viewModel.transform(
            input: MapBoxFeatureInput(
                viewDidAppear: viewDidAppear,
                currentLocationTapped: currentLocationTapped,
                viewDidDisappear: rx.viewDidDisappear.asObservable()
            ),
            disposeBag: disposeBag
        )

        let isMockData = crowdViewModel?.isMockData ?? false
        let crowdState: Driver<MapBoxCrowdState?>
        if let crowdViewModel {
            crowdState = crowdViewModel.transform(
                input: MapBoxCrowdInput(
                    viewDidAppear: rx.viewDidAppear.asObservable(),
                    viewDidDisappear: rx.viewDidDisappear.asObservable()
                ),
                disposeBag: disposeBag
            )
            .state
            .map { Optional($0) }
        } else {
            crowdState = .just(nil)
        }

        /// 위치 상태와 혼잡도 상태를 합쳐 화면 표시를 한 번에 갱신합니다.
        Driver.combineLatest(output.state, crowdState) { location, crowd in
            MapBoxScreenViewData.make(
                location: location,
                crowd: crowd,
                isMockData: isMockData
            )
        }
        .distinctUntilChanged()
        .drive(onNext: { [weak self] data in
            self?.screen.render(data)
        })
        .disposed(by: disposeBag)

        /// 일회성 카메라 명령을 구독해 지도를 현재 위치로 이동합니다.
        output.cameraCommand
            .emit(onNext: { [weak self] command in
                self?.moveCamera(to: command)
            })
            .disposed(by: disposeBag)

        /// 일회성 알림 이벤트를 구독해 위치 조회 오류를 표시합니다.
        output.alert
            .emit(onNext: { [weak self] alert in
                self?.renderAlert(alert)
            })
            .disposed(by: disposeBag)
    }

    /// Mapbox 카메라 변경을 구독해 마지막 화면 위치를 Session에 기록합니다.
    private func bindCamera() {
        screen.cameraChanged
            .bind(onNext: { [weak self] snapshot in
                guard let self else { return }
                self.session.recordCamera(
                    coordinate: snapshot.coordinate,
                    zoom: snapshot.zoom
                )
                self.screen.updateMapAccessibility(
                    isCenteredOnCurrentLocation: self.session.cameraIsCenteredOnCurrentLocation
                )
            })
            .disposed(by: disposeBag)
    }

    /// 현재 위치 명령을 Mapbox 카메라와 앱 수명 상태에 반영합니다.
    ///
    /// - Parameter command: ViewModel이 발행한 최신 카메라 이동 명령입니다.
    private func moveCamera(
        to command: MapBoxCameraCommand
    ) {
        session.expectCurrentLocationCamera(command.coordinate)
        screen.moveCamera(
            to: command.coordinate,
            zoom: MapBoxFeatureLocationPolicy.cameraZoom
        )
        session.recordCamera(
            coordinate: command.coordinate,
            zoom: MapBoxFeatureLocationPolicy.cameraZoom
        )
        screen.updateMapAccessibility(
            isCenteredOnCurrentLocation: session.cameraIsCenteredOnCurrentLocation
        )
    }

    /// ViewModel의 일회성 알림 이벤트를 UIKit 경고창으로 표시합니다.
    ///
    /// - Parameter alert: 한 번 표시할 위치 오류입니다.
    private func renderAlert(
        _ alert: MapBoxAlert
    ) {
        guard presentedAlertID != alert.id else { return }
        presentedAlertID = alert.id

        let alertController = UIAlertController(
            title: "위치 조회 실패",
            message: alert.message,
            preferredStyle: .alert
        )
        alertController.view.accessibilityIdentifier = alert.kind == .timeout
            ? "mapbox-location-timeout-alert"
            : "mapbox-location-error-alert"
        alertController.addAction(
            UIAlertAction(
                title: "확인",
                style: .default,
                handler: { [weak self] _ in
                    self?.presentedAlertID = nil
                }
            )
        )
        present(alertController, animated: true)
    }
}
