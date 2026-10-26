import ComposableArchitecture
import Foundation

/// MapKit 화면이 사용하는 위치 권한과 현재 위치 조회 의존성입니다.
///
/// 요청을 취소하면 실행 중인 권한·위치 대기도 함께 종료되어야 합니다.
@DependencyClient
public struct LocationClient: Sendable {
    /// 현재 위치 권한 상태를 즉시 반환합니다. Reducer가 main actor에서 호출합니다.
    public var authorizationStatus: @Sendable () -> MapFeatureAuthorization = { .notDetermined }
    /// 권한이 결정되지 않았을 때 시스템 권한 요청을 띄우고 결과를 기다립니다.
    public var requestAuthorization: @Sendable () async throws -> MapFeatureAuthorization
    /// 현재 위치 한 건을 조회합니다.
    public var requestLocation: @Sendable () async throws -> MapFeatureCoordinate
}

extension LocationClient: DependencyKey {
    public static var liveValue: LocationClient {
#if DEBUG
        if ProcessInfo.processInfo.environment["UITEST_LOCATION_SCENARIO"] == "success" {
            return .uiTestSuccess
        }
#endif
        return .coreLocation
    }

    public static let testValue = LocationClient()

    public static let previewValue = LocationClient(
        authorizationStatus: { .authorized },
        requestAuthorization: { .authorized },
        requestLocation: { MapFeatureCoordinate(latitude: 37.5665, longitude: 126.9780) }
    )

    /// 앱 실행 동안 하나의 `CLLocationManager`를 공유하는 Core Location 구현입니다.
    static var coreLocation: LocationClient {
        LocationClient(
            authorizationStatus: {
                MainActor.assumeIsolated { CoreMapLocationProvider.shared.authorizationStatus() }
            },
            requestAuthorization: { @MainActor in
                try await CoreMapLocationProvider.shared.requestAuthorization()
            },
            requestLocation: { @MainActor in
                try await CoreMapLocationProvider.shared.requestLocation()
            }
        )
    }

#if DEBUG
    /// UI 테스트에서 권한 팝업 없이 고정 좌표를 반환하는 구현입니다.
    static var uiTestSuccess: LocationClient {
        LocationClient(
            authorizationStatus: { .authorized },
            requestAuthorization: { .authorized },
            requestLocation: {
                try await Task.sleep(for: .milliseconds(300))
                return MapFeatureCoordinate(latitude: 37.5547, longitude: 126.9707)
            }
        )
    }
#endif
}

extension DependencyValues {
    /// MapKit 화면의 위치 의존성입니다.
    public var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

extension CoreMapLocationProvider {
    /// `LocationClient.liveValue`가 공유하는 위치 제공자입니다.
    static let shared = CoreMapLocationProvider()
}
