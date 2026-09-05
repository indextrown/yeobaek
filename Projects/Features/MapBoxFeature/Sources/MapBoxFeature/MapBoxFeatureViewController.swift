import CoreLocation
import MapboxMaps
import RxCocoa
import RxSwift
import UIKit

/// Mapbox 지도와 현재 위치 UI를 UIKit으로 표시하고 Rx ViewModel의 출력을 렌더링합니다.
public final class MapBoxFeatureViewController: UIViewController {
    // MARK: - Dependencies

    /// 자동 위치 요청 여부와 마지막 지도 카메라를 유지하는 상태입니다.
    private let session: MapBoxSession

    /// 화면 입력을 위치 조회 상태와 출력으로 변환하는 Rx ViewModel입니다.
    private let viewModel: MapBoxFeatureViewModel

    // MARK: - UI

    /// Mapbox 지도와 카메라를 실제로 표시하는 UIKit View입니다.
    private let mapView: MapView

    /// 사용자가 현재 위치 이동을 요청하는 버튼입니다.
    private let locationButton = UIButton(type: .system)

    /// 위치 권한 또는 좌표 조회 중임을 표시합니다.
    private let progressView = UIActivityIndicatorView(style: .medium)

    /// 위치 권한이 거부됐을 때 안내 문구를 표시합니다.
    private let authorizationLabel = UILabel()

    // MARK: - Subscriptions

    /// Mapbox 카메라 이벤트 구독의 수명을 관리합니다.
    private var mapboxCancelables = Set<AnyCancelable>()

    /// ViewModel Output 구독의 수명을 ViewController와 함께 관리합니다.
    private var disposeBag = DisposeBag()

    // MARK: - Presentation State

    /// 동일한 위치 오류 알림을 중복으로 표시하지 않기 위한 식별자입니다.
    private var presentedAlertID: UUID?

    /// 앱 실행 중 유지할 지도 상태와 Rx ViewModel을 주입해 UIKit 화면을 만듭니다.
    ///
    /// - Parameters:
    ///   - session: 자동 요청 여부와 마지막 카메라를 보관하는 앱 수명 상태입니다.
    ///   - viewModel: 위치 요청과 화면 상태를 관리하는 Rx ViewModel입니다.
    public init(
        session: MapBoxSession,
        viewModel: MapBoxFeatureViewModel = MapBoxFeatureViewModel()
    ) {
        self.session = session
        self.viewModel = viewModel
        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(
                latitude: session.cameraCoordinate.latitude,
                longitude: session.cameraCoordinate.longitude
            ),
            zoom: session.cameraZoom,
            bearing: 0,
            pitch: 0
        )
        mapView = MapView(
            frame: .zero,
            mapInitOptions: MapInitOptions(
                cameraOptions: cameraOptions,
                styleURI: .standard
            )
        )
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

    /// Mapbox 화면을 구성하고 ViewModel 및 카메라 이벤트를 연결합니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureMapView()
        configureControls()
        bindViewModel()
        observeCamera()
    }

    /// Mapbox 지도 View를 화면 전체에 배치하고 접근성 정보를 설정합니다.
    private func configureMapView() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.accessibilityIdentifier = "mapbox-map"
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        updateMapAccessibility()
    }

    /// 현재 위치 버튼, 진행 표시기, 권한 안내 UI를 구성합니다.
    private func configureControls() {
        authorizationLabel.font = .preferredFont(forTextStyle: .caption1)
        authorizationLabel.textColor = .label
        authorizationLabel.numberOfLines = 0
        authorizationLabel.textAlignment = .center
        authorizationLabel.accessibilityIdentifier = "mapbox-location-authorization-message"

        locationButton.translatesAutoresizingMaskIntoConstraints = false
        locationButton.backgroundColor = .secondarySystemBackground
        locationButton.tintColor = .label
        locationButton.layer.cornerRadius = 26
        locationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        locationButton.accessibilityLabel = "내 위치로 이동"
        locationButton.accessibilityIdentifier = "mapbox-current-location-button"

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.hidesWhenStopped = true
        progressView.accessibilityIdentifier = "mapbox-current-location-progress"
        locationButton.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.centerXAnchor.constraint(equalTo: locationButton.centerXAnchor),
            progressView.centerYAnchor.constraint(equalTo: locationButton.centerYAnchor),
        ])

        let controls = UIStackView(arrangedSubviews: [authorizationLabel, locationButton])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .horizontal
        controls.alignment = .center
        controls.spacing = 8
        controls.isLayoutMarginsRelativeArrangement = true
        controls.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 8)

        let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        background.translatesAutoresizingMaskIntoConstraints = false
        background.layer.cornerRadius = 30
        background.clipsToBounds = true
        background.contentView.addSubview(controls)
        view.addSubview(background)

        NSLayoutConstraint.activate([
            locationButton.widthAnchor.constraint(equalToConstant: 52),
            locationButton.heightAnchor.constraint(equalToConstant: 52),
            authorizationLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 250),
            controls.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            controls.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            controls.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            background.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            background.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -68),
        ])
    }

    /// UIKit 입력을 ViewModel Input에 연결하고 Output을 화면에 반영합니다.
    private func bindViewModel() {
        let viewDidAppear = rx.viewDidAppear
            .filter { [weak self] in
                self?.session.registerAutomaticRequestIfNeeded() == true
            }
        let currentLocationTapped = locationButton.rx.tap
            .do(onNext: { [weak self] in
                self?.session.registerManualRequest()
            })

        let output = viewModel.transform(
            input: MapBoxFeatureViewModel.Input(
                viewDidAppear: viewDidAppear,
                currentLocationTapped: currentLocationTapped,
                viewDidDisappear: rx.viewDidDisappear.asObservable()
            )
        )

        output.state
            .drive(onNext: { [weak self] state in
                self?.renderState(state)
            })
            .disposed(by: disposeBag)

        output.cameraCommand
            .emit(onNext: { [weak self] command in
                self?.moveCamera(to: command)
            })
            .disposed(by: disposeBag)

        output.alert
            .emit(onNext: { [weak self] alert in
                self?.renderAlert(alert)
            })
            .disposed(by: disposeBag)
    }

    /// Mapbox 카메라 변경을 구독해 마지막 화면 위치를 Session에 기록합니다.
    private func observeCamera() {
        mapView.mapboxMap.onCameraChanged
            .observe { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recordVisibleCamera()
                }
            }
            .store(in: &mapboxCancelables)
    }

    /// ViewModel Output의 상태를 위치 버튼과 권한 안내에 반영합니다.
    ///
    /// - Parameter state: 현재 위치 요청의 최신 진행 상태입니다.
    private func renderState(
        _ state: MapBoxFeatureViewModel.State
    ) {
        let isLoading = state == .requestingAuthorization || state == .locating
        let authorizationMessage = state == .authorizationDenied
            ? "위치 권한이 없어 현재 위치를 확인할 수 없습니다."
            : nil
        locationButton.isEnabled = !isLoading
        locationButton.setImage(
            isLoading ? nil : UIImage(systemName: "location.fill"),
            for: .normal
        )
        if isLoading {
            progressView.startAnimating()
        } else {
            progressView.stopAnimating()
        }
        authorizationLabel.text = authorizationMessage
        authorizationLabel.isHidden = authorizationMessage == nil
    }

    /// 현재 위치 명령을 Mapbox 카메라와 앱 수명 상태에 반영합니다.
    ///
    /// - Parameter command: ViewModel이 발행한 최신 카메라 이동 명령입니다.
    private func moveCamera(
        to command: MapBoxCameraCommand
    ) {
        session.expectCurrentLocationCamera(command.coordinate)
        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(
                latitude: command.coordinate.latitude,
                longitude: command.coordinate.longitude
            ),
            zoom: MapBoxFeatureLocationPolicy.cameraZoom,
            bearing: 0,
            pitch: 0
        )
        mapView.camera.ease(to: cameraOptions, duration: 0.35)
        session.recordCamera(
            coordinate: command.coordinate,
            zoom: MapBoxFeatureLocationPolicy.cameraZoom
        )
        updateMapAccessibility()
    }

    /// Mapbox가 실제로 표시 중인 카메라를 Session에 기록합니다.
    private func recordVisibleCamera() {
        let cameraState = mapView.mapboxMap.cameraState
        session.recordCamera(
            coordinate: MapBoxCoordinate(
                latitude: cameraState.center.latitude,
                longitude: cameraState.center.longitude
            ),
            zoom: cameraState.zoom
        )
        updateMapAccessibility()
    }

    /// 현재 위치 중심 여부를 Mapbox 지도 접근성 값에 반영합니다.
    private func updateMapAccessibility() {
        mapView.accessibilityValue = session.cameraIsCenteredOnCurrentLocation
            ? "현재 위치 중심"
            : "사용자 이동 위치"
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
