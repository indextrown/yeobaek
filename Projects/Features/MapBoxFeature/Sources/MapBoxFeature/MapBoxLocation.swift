import CoreLocation
import Foundation
import RxSwift

public struct MapBoxCoordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    /// 위도와 경도로 Mapbox 좌표를 만듭니다.
    ///
    /// - Parameters:
    ///   - latitude: 위도 값입니다.
    ///   - longitude: 경도 값입니다.
    public init(
        latitude: Double,
        longitude: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var isValid: Bool {
        latitude.isFinite
            && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }
}

public enum MapBoxAuthorization: Equatable, Sendable { case notDetermined, authorized, denied }
public enum MapBoxLocationError: Error, Sendable { case servicesDisabled, unavailable, invalidCoordinate }

@MainActor
public protocol MapboxLocationProviding: AnyObject {
    func authorizationStatus() -> MapBoxAuthorization
    func requestAuthorization() -> Single<MapBoxAuthorization>
    func requestLocation() -> Single<MapBoxCoordinate>
    func cancel()
}

@MainActor
public final class CoreMapboxLocationProvider: NSObject, MapboxLocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationObserver: ((SingleEvent<MapBoxAuthorization>) -> Void)?
    private var authorizationRequestID: UUID?
    private var locationObserver: ((SingleEvent<MapBoxCoordinate>) -> Void)?
    private var locationRequestID: UUID?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func authorizationStatus() -> MapBoxAuthorization {
        Self.authorization(from: manager.authorizationStatus)
    }

    public func requestAuthorization() -> Single<MapBoxAuthorization> {
        if authorizationStatus() != .notDetermined { return .just(authorizationStatus()) }
        return Single.create { [weak self] observer in
            guard let self else { return Disposables.create() }
            let requestID = UUID()
            self.authorizationObserver = observer
            self.authorizationRequestID = requestID
            self.manager.requestWhenInUseAuthorization()
            return Disposables.create { [weak self] in
                Task { @MainActor in
                    self?.discardAuthorizationObserver(for: requestID)
                }
            }
        }
    }

    public func requestLocation() -> Single<MapBoxCoordinate> {
        return Single.create { [weak self] observer in
            guard let self else { return Disposables.create() }
            let requestID = UUID()
            self.locationObserver = observer
            self.locationRequestID = requestID
            self.manager.requestLocation()
            return Disposables.create { [weak self] in
                Task { @MainActor in
                    self?.discardLocationObserver(for: requestID)
                }
            }
        }
    }

    public func cancel() {
        manager.stopUpdatingLocation()
        authorizationObserver = nil
        authorizationRequestID = nil
        locationObserver = nil
        locationRequestID = nil
    }

    /// 권한 변경을 Rx 요청에 전달합니다.
    ///
    /// - Parameter manager: 권한 상태가 바뀐 위치 관리자입니다.
    nonisolated public func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let status = Self.authorization(from: manager.authorizationStatus)
        guard status != .notDetermined else { return }
        Task { @MainActor [weak self] in
            self?.finishAuthorization(status)
        }
    }

    /// 권한 결과를 main actor에서 Rx 요청에 전달합니다.
    ///
    /// - Parameter status: Core Location callback이 전달한 권한 상태입니다.
    private func finishAuthorization(
        _ status: MapBoxAuthorization
    ) {
        let observer = authorizationObserver
        authorizationObserver = nil
        authorizationRequestID = nil
        observer?(.success(status))
    }

    /// 위치 결과를 Rx 요청에 전달합니다.
    ///
    /// - Parameters:
    ///   - manager: 결과를 생성한 위치 관리자입니다.
    ///   - locations: 최신 위치 후보입니다.
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let coordinate = locations.last?.coordinate else {
            Task { @MainActor [weak self] in
                self?.finishLocation(.failure(MapBoxLocationError.unavailable))
            }
            return
        }
        let featureCoordinate = MapBoxCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        Task { @MainActor [weak self] in
            self?.finishLocation(.success(featureCoordinate))
        }
    }

    /// Core Location 오류를 Rx 요청에 전달합니다.
    ///
    /// - Parameters:
    ///   - manager: 오류를 생성한 위치 관리자입니다.
    ///   - error: Core Location이 전달한 오류입니다.
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        let normalizedError: MapBoxLocationError
        if let locationError = error as? CLError,
           locationError.code == .denied {
            normalizedError = .servicesDisabled
        } else {
            normalizedError = .unavailable
        }
        Task { @MainActor [weak self] in
            self?.finishLocation(.failure(normalizedError))
        }
    }

    /// 시스템 권한 상태를 Feature 상태로 바꿉니다.
    ///
    /// - Parameter status: Core Location 권한 상태입니다.
    /// - Returns: Rx 위치 흐름이 사용하는 권한 상태입니다.
    nonisolated static func authorization(
        from status: CLAuthorizationStatus
    ) -> MapBoxAuthorization {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    /// 위치 observer를 한 번만 종료합니다.
    ///
    /// - Parameter result: 반환할 위치 또는 오류입니다.
    private func finishLocation(
        _ result: Result<MapBoxCoordinate, Error>
    ) {
        let observer = locationObserver
        locationObserver = nil
        locationRequestID = nil
        switch result {
        case .success(let coordinate): observer?(.success(coordinate))
        case .failure(let error): observer?(.failure(error))
        }
    }

    /// 동일 요청의 dispose일 때만 권한 observer를 제거합니다.
    ///
    /// - Parameter requestID: dispose된 권한 요청의 식별자입니다.
    private func discardAuthorizationObserver(
        for requestID: UUID
    ) {
        guard authorizationRequestID == requestID else { return }
        authorizationObserver = nil
        authorizationRequestID = nil
    }

    /// 동일 요청의 dispose일 때만 위치 observer를 제거합니다.
    ///
    /// - Parameter requestID: dispose된 위치 요청의 식별자입니다.
    private func discardLocationObserver(
        for requestID: UUID
    ) {
        guard locationRequestID == requestID else { return }
        manager.stopUpdatingLocation()
        locationObserver = nil
        locationRequestID = nil
    }
}
