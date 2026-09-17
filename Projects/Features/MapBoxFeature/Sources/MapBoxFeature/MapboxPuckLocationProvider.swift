import CoreLocation
import Foundation
import MapboxMaps
import RxSwift

/// 지도 위치 점과 이동 요청이 함께 사용하는 위치 측정값입니다.
struct MapBoxLocationSample: Sendable {
    /// 위치를 측정한 좌표입니다.
    let coordinate: MapBoxCoordinate

    /// 좌표가 실제로 측정된 시각입니다.
    let timestamp: Date

    /// 미터 단위 오차이며, SDK가 제공하지 않으면 nil입니다.
    let horizontalAccuracy: Double?

    /// 지도 SDK의 위치 측정값을 보관합니다.
    ///
    /// - Parameters:
    ///   - coordinate: 위치 점이 표시할 좌표입니다.
    ///   - timestamp: 좌표의 측정 시각입니다.
    ///   - horizontalAccuracy: 미터 단위 오차이며, 알 수 없으면 nil입니다.
    init(
        coordinate: MapBoxCoordinate,
        timestamp: Date,
        horizontalAccuracy: Double?
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }

    /// 오래되거나 잘못된 측정을 제외하고 대략적인 위치도 허용합니다.
    ///
    /// - Parameter date: 위치의 유효 기간을 판단할 현재 시각입니다.
    /// - Returns: 최근 30초 이내의 유효한 좌표이며, 사용할 수 없으면 nil입니다.
    func usableCoordinate(
        at date: Date = Date()
    ) -> MapBoxCoordinate? {
        guard coordinate.isValid,
              (0...30).contains(date.timeIntervalSince(timestamp)) else { return nil }
        if let horizontalAccuracy,
           !horizontalAccuracy.isFinite || horizontalAccuracy < 0 { return nil }
        return coordinate
    }
}

/// Mapbox 위치 점의 좌표와 갱신 이벤트를 현재 위치 요청에 제공합니다.
final class MapboxPuckLocationProvider: MapboxLocationProviding {
    /// 위치 권한 요청만 담당하며, 별도 좌표 측정을 시작하지 않습니다.
    private let authorizationProvider: any MapboxLocationProviding

    /// 구독 시점에 지도 SDK가 이미 보유한 최신 측정값을 읽습니다.
    private let latestSample: @MainActor () -> MapBoxLocationSample?

    /// 지도 위치 점에 새로 전달되는 측정값입니다.
    private let locationUpdates: Observable<MapBoxLocationSample>

    /// 지도와 같은 위치 원천을 사용하도록 제공자를 만듭니다.
    ///
    /// - Parameter mapView: 현재 위치 점을 표시하는 지도입니다.
    convenience init(
        mapView: MapView
    ) {
        let updates = Observable<MapBoxLocationSample>.create { [weak mapView] observer in
            guard let mapView else {
                observer.onError(MapBoxLocationError.unavailable)
                return Disposables.create()
            }
            let observation = mapView.location.onLocationChange.observe { locations in
                for location in locations.reversed() {
                    observer.onNext(Self.sample(from: location))
                }
            }
            return Disposables.create { observation.cancel() }
        }
        self.init(
            authorizationProvider: CoreMapboxLocationProvider(),
            latestSample: { [weak mapView] in
                mapView?.location.latestLocation.map { Self.sample(from: $0) }
            },
            locationUpdates: updates.observe(on: MainScheduler.instance)
        )
    }

    /// 위치 원천과 권한 처리를 주입해 센서 없이 요청 흐름을 재현할 수 있게 합니다.
    ///
    /// - Parameters:
    ///   - authorizationProvider: 현재 권한과 권한 요청 결과를 제공할 객체입니다.
    ///   - latestSample: 구독할 때 읽을 최신 측정값입니다.
    ///   - locationUpdates: 최신 위치가 없을 때 기다릴 위치 갱신 스트림입니다.
    init(
        authorizationProvider: any MapboxLocationProviding,
        latestSample: @escaping @MainActor () -> MapBoxLocationSample?,
        locationUpdates: Observable<MapBoxLocationSample>
    ) {
        self.authorizationProvider = authorizationProvider
        self.latestSample = latestSample
        self.locationUpdates = locationUpdates
    }

    func authorizationStatus() -> MapBoxAuthorization {
        authorizationProvider.authorizationStatus()
    }

    func requestAuthorization() -> Single<MapBoxAuthorization> {
        authorizationProvider.requestAuthorization()
    }

    /// 이미 표시 중인 최근 좌표를 반환하거나 다음 유효한 SDK 위치 한 건을 기다립니다.
    ///
    /// - Returns: 현재 위치 좌표 한 건을 전달하는 스트림입니다.
    func requestLocation() -> Single<MapBoxCoordinate> {
        Single.deferred { [weak self] in
            guard let self else { return .error(MapBoxLocationError.unavailable) }
            guard self.authorizationStatus() == .authorized else {
                return .error(MapBoxLocationError.servicesDisabled)
            }
            if let coordinate = self.latestSample()?.usableCoordinate() {
                return .just(coordinate)
            }
            return self.locationUpdates
                .compactMap { $0.usableCoordinate() }
                .take(1)
                .asSingle()
        }
    }

    /// 권한 요청을 취소합니다. 위치 관찰은 Rx 구독 해제와 함께 종료됩니다.
    func cancel() {
        authorizationProvider.cancel()
    }

    /// SDK 위치를 지도와 무관한 측정값으로 변환합니다.
    ///
    /// - Parameter location: 지도 SDK가 전달한 위치입니다.
    /// - Returns: 좌표와 측정 시각, 정확도를 보존한 측정값입니다.
    nonisolated private static func sample(
        from location: Location
    ) -> MapBoxLocationSample {
        MapBoxLocationSample(
            coordinate: MapBoxCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy
        )
    }
}
