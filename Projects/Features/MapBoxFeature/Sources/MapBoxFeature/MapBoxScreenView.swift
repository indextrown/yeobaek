import Core
import CoreLocation
import Domain
import MapboxMaps
import RxCocoa
import RxRelay
import RxSwift
import UIKit

/// Mapbox 지도와 현재 위치·혼잡도 UI의 레이아웃과 표시를 담당하는 View입니다.
///
/// 위치를 조회하거나 혼잡도를 계산하지 않습니다. 사용자 입력을 공개하고 전달받은
/// 표시 데이터를 반영하며, 지도 SDK에만 있는 카메라 명령을 메서드로 제공합니다.
public final class MapBoxScreenView: UIView, MapBoxFeatureScreenProtocol {
    /// Mapbox 지도와 카메라를 실제로 표시하는 UIKit View입니다.
    private let mapView: MapView

    /// 사용자가 현재 위치 이동을 요청하는 버튼입니다.
    private let locationButton = UIButton(type: .system)

    /// 위치 권한 또는 좌표 조회 중임을 표시합니다.
    private let progressView = UIActivityIndicatorView(style: .medium)

    /// 위치 권한이 거부됐을 때 안내 문구를 표시합니다.
    private let authorizationLabel = UILabel()

    /// 위치 권한 안내 문구에만 material 배경을 제공합니다.
    private let authorizationBackgroundView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemMaterial)
    )

    /// 혼잡도 범례와 목업 안내를 지도 위에서 읽을 수 있게 표시합니다.
    private let crowdBackgroundView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemMaterial)
    )

    /// 혼잡도 범례의 제목입니다.
    private let crowdTitleLabel = UILabel()

    /// 실제 데이터와 구분되는 목업 안내 또는 혼잡도 조회 상태입니다.
    private let crowdStatusLabel = UILabel()

    /// 현재 위치를 바꾸지 않고 테스트 영역을 찾아볼 수 있는 별도 버튼입니다.
    private let showCrowdButton = UIButton(type: .system)

    /// 혼잡도 범례와 지도 채움을 사용하는 화면인지 나타냅니다.
    private let showsCrowdOverlay: Bool

    /// Mapbox 카메라와 스타일 이벤트 구독의 수명을 관리합니다.
    private var mapboxCancelables = Set<AnyCancelable>()

    /// View가 직접 처리하는 표시 전용 구독의 수명을 관리합니다.
    private let disposeBag = DisposeBag()

    /// Mapbox 카메라 변경을 화면 밖으로 전달합니다.
    private let cameraChangedRelay = PublishRelay<MapBoxCameraSnapshot>()

    /// 지도 스타일 로드 후 생성하는 혼잡도 표시 객체입니다.
    private var crowdRenderer: MapBoxCrowdRenderer?

    /// 스타일 로드 전에 도착한 결과도 나중에 표시하기 위해 보관합니다.
    private var renderedAreas: [MapBoxCrowdArea]?

    /// 사용자가 현재 위치 버튼을 누른 이벤트입니다.
    public var currentLocationTapped: Observable<Void> {
        locationButton.rx.tap.asObservable()
    }

    /// Mapbox가 실제로 표시한 카메라가 바뀐 이벤트입니다.
    public var cameraChanged: Observable<MapBoxCameraSnapshot> {
        cameraChangedRelay.asObservable()
    }

    /// 지도 초기 카메라와 혼잡도 사용 여부를 받아 화면을 구성합니다.
    ///
    /// - Parameters:
    ///   - initialCamera: 앱 수명 상태가 보관한 마지막 카메라입니다.
    ///   - showsCrowdOverlay: 혼잡도 범례와 채움을 표시하면 `true`입니다.
    public init(
        initialCamera: MapBoxCameraSnapshot,
        showsCrowdOverlay: Bool
    ) {
        self.showsCrowdOverlay = showsCrowdOverlay
        mapView = MapView(
            frame: .zero,
            mapInitOptions: MapInitOptions(
                cameraOptions: CameraOptions(
                    center: CLLocationCoordinate2D(
                        latitude: initialCamera.coordinate.latitude,
                        longitude: initialCamera.coordinate.longitude
                    ),
                    zoom: initialCamera.zoom,
                    bearing: 0,
                    pitch: 0
                ),
                styleURI: .standard
            )
        )
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        configureMapView()
        configureControls()
        configureCrowdOverlay()
        observeCamera()
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

    /// 위치 요청 상태와 혼잡도 상태를 화면에 반영합니다.
    ///
    /// 경계와 색상은 실제로 값이 바뀐 경우에만 다시 그립니다.
    ///
    /// - Parameter data: 두 ViewModel의 상태를 합친 화면 표시 데이터입니다.
    public func render(
        _ data: MapBoxScreenViewData
    ) {
        locationButton.isEnabled = true
        locationButton.setImage(
            data.isLocating ? nil : UIImage(systemName: "location.fill"),
            for: .normal
        )
        if data.isLocating {
            progressView.startAnimating()
        } else {
            progressView.stopAnimating()
        }

        authorizationLabel.text = data.authorizationMessage
        authorizationLabel.isHidden = data.authorizationMessage == nil
        authorizationBackgroundView.isHidden = data.authorizationMessage == nil

        guard let crowd = data.crowd else { return }
        crowdTitleLabel.text = crowd.title
        crowdStatusLabel.text = crowd.statusText
        showCrowdButton.setTitle(crowd.showAreasButtonTitle, for: .normal)
        guard renderedAreas != crowd.areas else { return }
        renderedAreas = crowd.areas
        drawCrowdAreas()
    }

    /// 지도 중심을 지정한 좌표로 이동합니다.
    ///
    /// - Parameters:
    ///   - coordinate: 이동할 중심 좌표입니다.
    ///   - zoom: 이동 후 적용할 확대 수준입니다.
    public func moveCamera(
        to coordinate: MapBoxCoordinate,
        zoom: Double
    ) {
        mapView.camera.ease(
            to: CameraOptions(
                center: CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ),
                zoom: zoom,
                bearing: 0,
                pitch: 0
            ),
            duration: 0.35
        )
    }

    /// 현재 위치 중심 여부를 Mapbox 지도 접근성 값에 반영합니다.
    ///
    /// - Parameter isCentered: 카메라가 현재 위치를 중심에 두고 있으면 `true`입니다.
    public func updateMapAccessibility(
        isCenteredOnCurrentLocation isCentered: Bool
    ) {
        mapView.accessibilityValue = isCentered ? "현재 위치 중심" : "사용자 이동 위치"
    }

    /// 지도 위치 점과 같은 원천을 사용하는 위치 제공자를 만듭니다.
    ///
    /// ViewModel이 이 View의 지도와 동일한 좌표를 쓰도록 조립 계층에 제공합니다.
    ///
    /// - Returns: 이 화면의 지도에 연결된 위치 제공자입니다.
    public func makeLocationProvider() -> any MapboxLocationProviding {
        MapboxPuckLocationProvider(mapView: mapView)
    }

    /// Mapbox 지도 View를 화면 전체에 배치하고 접근성 정보를 설정합니다.
    private func configureMapView() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.accessibilityIdentifier = "mapbox-map"
        mapView.location.options.puckType = .puck2D(.makeDefault())
        addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mapView.topAnchor.constraint(equalTo: topAnchor),
            mapView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        updateMapAccessibility(isCenteredOnCurrentLocation: false)
    }

    /// 현재 위치 버튼, 진행 표시기, 권한 안내 UI를 구성합니다.
    private func configureControls() {
        authorizationLabel.translatesAutoresizingMaskIntoConstraints = false
        authorizationLabel.font = .preferredFont(forTextStyle: .caption1)
        authorizationLabel.textColor = .label
        authorizationLabel.numberOfLines = 0
        authorizationLabel.textAlignment = .center
        authorizationLabel.accessibilityIdentifier = "mapbox-location-authorization-message"

        locationButton.translatesAutoresizingMaskIntoConstraints = false
        locationButton.configuration = .plain()
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

        authorizationBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        authorizationBackgroundView.layer.cornerRadius = 18
        authorizationBackgroundView.clipsToBounds = true
        authorizationBackgroundView.isHidden = true
        authorizationBackgroundView.contentView.addSubview(authorizationLabel)
        addSubview(authorizationBackgroundView)
        addSubview(locationButton)

        NSLayoutConstraint.activate([
            locationButton.widthAnchor.constraint(equalToConstant: 52),
            locationButton.heightAnchor.constraint(equalToConstant: 52),
            locationButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            locationButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -68),
            authorizationLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 250),
            authorizationLabel.leadingAnchor.constraint(
                equalTo: authorizationBackgroundView.contentView.leadingAnchor,
                constant: 12
            ),
            authorizationLabel.trailingAnchor.constraint(
                equalTo: authorizationBackgroundView.contentView.trailingAnchor,
                constant: -12
            ),
            authorizationLabel.topAnchor.constraint(
                equalTo: authorizationBackgroundView.contentView.topAnchor,
                constant: 10
            ),
            authorizationLabel.bottomAnchor.constraint(
                equalTo: authorizationBackgroundView.contentView.bottomAnchor,
                constant: -10
            ),
            authorizationBackgroundView.trailingAnchor.constraint(
                equalTo: locationButton.leadingAnchor,
                constant: -8
            ),
            authorizationBackgroundView.centerYAnchor.constraint(equalTo: locationButton.centerYAnchor),
        ])
    }

    /// 목업 안내, 혼잡도 범례와 전체 영역 보기 버튼을 구성합니다.
    private func configureCrowdOverlay() {
        guard showsCrowdOverlay else { return }

        crowdTitleLabel.font = .preferredFont(forTextStyle: .headline)
        crowdTitleLabel.adjustsFontForContentSizeCategory = true

        crowdStatusLabel.font = .preferredFont(forTextStyle: .caption1)
        crowdStatusLabel.adjustsFontForContentSizeCategory = true
        crowdStatusLabel.textColor = .secondaryLabel
        crowdStatusLabel.numberOfLines = 0
        crowdStatusLabel.accessibilityIdentifier = "mapbox-crowd-status"

        let stack = UIStackView(arrangedSubviews: [crowdTitleLabel, crowdStatusLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let groups: [[CongestionLevel]] = [[.relaxed, .normal, .busy], [.crowded, .unknown]]
        for levels in groups {
            let row = UIStackView()
            row.spacing = 10
            row.alignment = .center
            row.distribution = .fillEqually
            for level in levels {
                let dot = UIView()
                dot.backgroundColor = MapBoxCrowdStyle.color(for: level)
                dot.layer.cornerRadius = 4
                dot.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: 8),
                    dot.heightAnchor.constraint(equalToConstant: 8),
                ])
                let label = UILabel()
                label.text = MapBoxCrowdStyle.title(for: level)
                label.font = .preferredFont(forTextStyle: .caption2)
                label.adjustsFontForContentSizeCategory = true
                label.numberOfLines = 0
                let item = UIStackView(arrangedSubviews: [dot, label])
                item.spacing = 4
                item.alignment = .center
                row.addArrangedSubview(item)
            }
            stack.addArrangedSubview(row)
        }

        showCrowdButton.configuration = .plain()
        showCrowdButton.isEnabled = false
        showCrowdButton.accessibilityIdentifier = "mapbox-show-crowd-areas-button"
        stack.addArrangedSubview(showCrowdButton)

        crowdBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        crowdBackgroundView.layer.cornerRadius = 18
        crowdBackgroundView.clipsToBounds = true
        crowdBackgroundView.contentView.addSubview(stack)
        addSubview(crowdBackgroundView)
        NSLayoutConstraint.activate([
            crowdBackgroundView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            crowdBackgroundView.bottomAnchor.constraint(equalTo: locationButton.topAnchor, constant: -16),
            crowdBackgroundView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            crowdBackgroundView.trailingAnchor.constraint(
                lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor,
                constant: -16
            ),
            stack.leadingAnchor.constraint(equalTo: crowdBackgroundView.contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: crowdBackgroundView.contentView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: crowdBackgroundView.contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: crowdBackgroundView.contentView.bottomAnchor, constant: -8),
        ])

        showCrowdButton.rx.tap
            .bind(onNext: { [weak self] in self?.showCrowdAreas() })
            .disposed(by: disposeBag)

        mapView.mapboxMap.onStyleLoaded
            .observe { [weak self] _ in
                Task { @MainActor [weak self] in self?.prepareCrowdRenderer() }
            }
            .store(in: &mapboxCancelables)
        if mapView.mapboxMap.isStyleLoaded {
            prepareCrowdRenderer()
        }
    }

    /// 지도 스타일이 준비되면 마지막으로 받은 혼잡도를 표시합니다.
    private func prepareCrowdRenderer() {
        if crowdRenderer == nil {
            crowdRenderer = MapBoxCrowdRenderer(mapView: mapView)
        }
        drawCrowdAreas()
    }

    /// 보관 중인 경계와 혼잡도를 지도에 반영하고 버튼 활성화를 갱신합니다.
    private func drawCrowdAreas() {
        guard let renderedAreas else { return }
        crowdRenderer?.render(areas: renderedAreas)
        showCrowdButton.isEnabled = !(crowdRenderer?.coordinates.isEmpty ?? true)
    }

    /// 사용자가 요청했을 때만 모든 테스트 영역이 보이도록 카메라를 이동합니다.
    private func showCrowdAreas() {
        guard let coordinates = crowdRenderer?.coordinates, !coordinates.isEmpty else { return }
        let padding = UIEdgeInsets(
            top: safeAreaInsets.top + 80,
            left: 32,
            bottom: safeAreaInsets.bottom + crowdBackgroundView.bounds.height + 150,
            right: 32
        )
        guard let camera = try? mapView.mapboxMap.camera(
            for: coordinates,
            camera: CameraOptions(padding: .zero, bearing: 0, pitch: 0),
            coordinatesPadding: padding,
            maxZoom: 14,
            offset: nil
        ) else { return }
        mapView.camera.cancelAnimations()
        mapView.camera.ease(to: camera, duration: 0.35)
    }

    /// Mapbox 카메라 변경을 화면 밖에서 기록할 수 있게 전달합니다.
    private func observeCamera() {
        mapView.mapboxMap.onCameraChanged
            .observe { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.publishVisibleCamera()
                }
            }
            .store(in: &mapboxCancelables)
    }

    /// Mapbox가 실제로 표시 중인 카메라를 구독자에게 전달합니다.
    private func publishVisibleCamera() {
        let cameraState = mapView.mapboxMap.cameraState
        cameraChangedRelay.accept(
            MapBoxCameraSnapshot(
                coordinate: MapBoxCoordinate(
                    latitude: cameraState.center.latitude,
                    longitude: cameraState.center.longitude
                ),
                zoom: cameraState.zoom
            )
        )
    }
}
