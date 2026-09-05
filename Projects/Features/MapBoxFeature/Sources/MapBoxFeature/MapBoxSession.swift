import Foundation

/// 앱 실행 중 Mapbox 카메라와 현재 위치 요청 상태를 유지합니다.
@MainActor
public final class MapBoxSession {
    private var didStartAutomatically = false
    public private(set) var requestCount = 0
    public private(set) var cameraIsCenteredOnCurrentLocation = false
    private(set) var cameraCoordinate = MapBoxCoordinate(
        latitude: 37.5665,
        longitude: 126.9780
    )
    private(set) var cameraZoom = MapBoxFeatureLocationPolicy.cameraZoom
    private var currentLocationTarget: MapBoxCoordinate?
    public init() {}

    /// 아직 자동 실행하지 않았다면 요청 동작을 한 번 수행합니다.
    ///
    /// - Parameter request: 최초 화면 활성화 시 수행할 위치 요청입니다.
    /// - Returns: 이번 호출에서 요청을 시작했는지 여부입니다.
    @discardableResult
    func startAutomatically(
        _ request: () -> Void
    ) -> Bool {
        guard !didStartAutomatically else { return false }
        didStartAutomatically = true
        requestCount += 1
        request()
        return true
    }

    /// 사용자가 요청한 위치 이동을 실행하고 앱 실행 수명의 요청 횟수를 기록합니다.
    ///
    /// - Parameter request: 내 위치 버튼 입력으로 수행할 위치 요청입니다.
    func startManually(
        _ request: () -> Void
    ) {
        requestCount += 1
        request()
    }

    /// 현재 위치 카메라 명령의 목표 좌표를 기록합니다.
    ///
    /// - Parameter coordinate: 실제 카메라 callback에서 확인할 목표 좌표입니다.
    func expectCurrentLocationCamera(
        _ coordinate: MapBoxCoordinate
    ) {
        currentLocationTarget = coordinate
        cameraIsCenteredOnCurrentLocation = isCameraCentered(on: coordinate)
    }

    /// Mapbox가 실제로 표시한 카메라를 앱 실행 수명 동안 보관합니다.
    ///
    /// - Parameters:
    ///   - coordinate: Mapbox 카메라 callback이 보고한 중심 좌표입니다.
    ///   - zoom: Mapbox 카메라 callback이 보고한 확대 수준입니다.
    func recordCamera(
        coordinate: MapBoxCoordinate,
        zoom: Double
    ) {
        cameraCoordinate = coordinate
        cameraZoom = zoom
        let isCentered = currentLocationTarget.map {
            abs($0.latitude - coordinate.latitude) <= 0.000_1
                && abs($0.longitude - coordinate.longitude) <= 0.000_1
        } ?? false
        if cameraIsCenteredOnCurrentLocation != isCentered {
            cameraIsCenteredOnCurrentLocation = isCentered
        }
    }

    /// 마지막 Mapbox callback의 중심이 목표 좌표와 일치하는지 확인합니다.
    ///
    /// - Parameter coordinate: 현재 위치 이동 명령의 목표 좌표입니다.
    /// - Returns: 실제로 기록된 카메라가 목표 좌표의 허용 오차 안에 있으면 `true`입니다.
    private func isCameraCentered(
        on coordinate: MapBoxCoordinate
    ) -> Bool {
        abs(coordinate.latitude - cameraCoordinate.latitude) <= 0.000_1
            && abs(coordinate.longitude - cameraCoordinate.longitude) <= 0.000_1
    }
}
