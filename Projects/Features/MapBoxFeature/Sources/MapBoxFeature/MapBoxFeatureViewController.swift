import CoreLocation
import MapboxMaps
import RxSwift
import UIKit

/// Mapbox 지도와 현재 위치 UI를 UIKit으로 표시하고 Rx ViewModel의 출력을 렌더링합니다.
@MainActor
public final class MapBoxFeatureViewController: UIViewController {
    private let session: MapBoxSession
    private let viewModel: MapBoxFeatureViewModel
    private let mapView: MapView
    private let locationButton = UIButton(type: .system)
    private let progressView = UIActivityIndicatorView(style: .medium)
    private let authorizationLabel = UILabel()
    private var mapboxCancelables = Set<AnyCancelable>()
    private var disposeBag = DisposeBag()
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

    public override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .systemBackground
        view = rootView
        configureMapView()
        configureControls()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        observeCamera()
    }

    /// 화면이 나타날 때 앱 수명에서 한 번만 현재 위치를 자동으로 요청합니다.
    ///
    /// - Parameter animated: 화면 전환 애니메이션 여부입니다.
    public override func viewDidAppear(
        _ animated: Bool
    ) {
        super.viewDidAppear(animated)
        session.startAutomatically(viewModel.moveToCurrentLocation)
    }

    /// 화면이 사라질 때 진행 중인 위치 요청과 Rx 구독을 정리합니다.
    ///
    /// - Parameter animated: 화면 전환 애니메이션 여부입니다.
    public override func viewDidDisappear(
        _ animated: Bool
    ) {
        super.viewDidDisappear(animated)
        viewModel.cancel()
    }

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

    private func bindViewModel() {
        locationButton.addTarget(
            self,
            action: #selector(didTapCurrentLocation),
            for: .touchUpInside
        )

        viewModel.stateObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.renderState()
            })
            .disposed(by: disposeBag)

        viewModel.cameraCommandObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] command in
                self?.moveCamera(to: command)
            })
            .disposed(by: disposeBag)

        viewModel.alertObservable
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] alert in
                self?.renderAlert(alert)
            })
            .disposed(by: disposeBag)
    }

    private func observeCamera() {
        mapView.mapboxMap.onCameraChanged
            .observe { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recordVisibleCamera()
                }
            }
            .store(in: &mapboxCancelables)
    }

    @objc private func didTapCurrentLocation() {
        session.startManually(viewModel.moveToCurrentLocation)
    }

    private func renderState() {
        let isLoading = viewModel.isLoading
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
        authorizationLabel.text = viewModel.authorizationMessage
        authorizationLabel.isHidden = viewModel.authorizationMessage == nil
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

    private func updateMapAccessibility() {
        mapView.accessibilityValue = session.cameraIsCenteredOnCurrentLocation
            ? "현재 위치 중심"
            : "사용자 이동 위치"
    }

    /// ViewModel의 알림 상태를 UIKit 경고창으로 표시하거나 닫습니다.
    ///
    /// - Parameter alert: 표시할 위치 오류이며 `nil`이면 현재 경고창을 닫습니다.
    private func renderAlert(
        _ alert: MapBoxAlert?
    ) {
        guard let alert else {
            presentedAlertID = nil
            if presentedViewController is UIAlertController {
                dismiss(animated: true)
            }
            return
        }
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
        alertController.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.viewModel.dismissAlert()
        })
        present(alertController, animated: true)
    }
}
