import CoreLocation
import Foundation

public struct MapFeatureCoordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    /// 위도와 경도로 지도 좌표를 만듭니다.
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

public enum MapFeatureAuthorization: Sendable {
    case notDetermined
    case authorized
    case denied
}

public enum MapFeatureLocationError: Error, Equatable, Sendable {
    case servicesDisabled
    case unavailable
    case invalidCoordinate
    case timedOut
}

@MainActor
public protocol MapLocationProviding: AnyObject, Sendable {
    func authorizationStatus() -> MapFeatureAuthorization
    func requestAuthorization() async throws -> MapFeatureAuthorization
    func requestLocation() async throws -> MapFeatureCoordinate
    func cancel()
}

@MainActor
public final class CoreMapLocationProvider: NSObject, MapLocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<MapFeatureAuthorization, Error>?
    private var locationContinuation: CheckedContinuation<MapFeatureCoordinate, Error>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    public func authorizationStatus() -> MapFeatureAuthorization {
        Self.authorization(from: manager.authorizationStatus)
    }

    public func requestAuthorization() async throws -> MapFeatureAuthorization {
        try Task.checkCancellation()
        if authorizationStatus() != .notDetermined { return authorizationStatus() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    public func requestLocation() async throws -> MapFeatureCoordinate {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                locationContinuation = continuation
                manager.requestLocation()
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    public func cancel() {
        manager.stopUpdatingLocation()
        let authorizationContinuation = self.authorizationContinuation
        self.authorizationContinuation = nil
        let locationContinuation = self.locationContinuation
        self.locationContinuation = nil
        authorizationContinuation?.resume(throwing: CancellationError())
        locationContinuation?.resume(throwing: CancellationError())
    }

    /// 권한 변경을 대기 중인 요청에 전달합니다.
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

    /// 권한 결과를 main actor에서 대기 중인 요청에 전달합니다.
    ///
    /// - Parameter status: Core Location callback이 전달한 권한 상태입니다.
    private func finishAuthorization(
        _ status: MapFeatureAuthorization
    ) {
        let continuation = authorizationContinuation
        authorizationContinuation = nil
        continuation?.resume(returning: status)
    }

    /// 단일 위치 조회 결과를 대기 중인 요청에 전달합니다.
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
                self?.finishLocation(.failure(MapFeatureLocationError.unavailable))
            }
            return
        }
        let featureCoordinate = MapFeatureCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        Task { @MainActor [weak self] in
            self?.finishLocation(.success(featureCoordinate))
        }
    }

    /// Core Location 오류를 정규화해 대기 중인 요청에 전달합니다.
    ///
    /// - Parameters:
    ///   - manager: 오류를 생성한 위치 관리자입니다.
    ///   - error: Core Location이 전달한 오류입니다.
    nonisolated public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        let normalizedError: MapFeatureLocationError
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

    /// 시스템 권한 상태를 Feature 상태로 변환합니다.
    ///
    /// - Parameter status: Core Location 권한 상태입니다.
    /// - Returns: UI와 ViewModel에서 사용하는 권한 상태입니다.
    nonisolated static func authorization(
        from status: CLAuthorizationStatus
    ) -> MapFeatureAuthorization {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    /// 위치 continuation을 한 번만 종료합니다.
    ///
    /// - Parameter result: 반환할 위치 또는 오류입니다.
    private func finishLocation(
        _ result: Result<MapFeatureCoordinate, Error>
    ) {
        let continuation = locationContinuation
        locationContinuation = nil
        continuation?.resume(with: result)
    }
}
