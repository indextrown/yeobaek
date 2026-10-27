import Domain
import Foundation
import UIKit

/// 앱 실행 중 Mapbox 카메라, 현재 위치 요청과 주입된 혼잡도 화면 상태를 유지합니다.
@MainActor
public final class MapBoxSession {
    /// 지도 전환 후에도 조회 결과를 유지할 혼잡도 화면 모델입니다.
    let crowdViewModel: (any MapBoxCrowdViewModelProtocol)?

    /// 지도 위에 기존 혼잡도 범례 패널을 표시할지 정합니다. 앱 홈처럼 다른 화면이 요약을 맡으면 `false`입니다.
    public let showsCrowdPanel: Bool

    /// 화면 아래에서 내 위치 버튼까지의 거리입니다. 지도 위에 시트를 올리면 시트 높이만큼 키웁니다.
    public private(set) var controlsBottomInset: CGFloat

    /// 버튼 여백이 바뀌면 화면이 제약을 갱신하도록 알립니다.
    var controlsBottomInsetDidChange: ((CGFloat) -> Void)?

    /// 사용자가 지도에서 장소 영역을 눌렀을 때 장소 코드를 전달합니다.
    public var onSelectPlace: (@MainActor (Place.ID) -> Void)?

    private var didStartAutomatically = false
    public private(set) var requestCount = 0
    public private(set) var cameraIsCenteredOnCurrentLocation = false
    private(set) var cameraCoordinate = MapBoxCoordinate(
        latitude: 37.5665,
        longitude: 126.9780
    )
    private(set) var cameraZoom = MapBoxFeatureLocationPolicy.cameraZoom
    private var currentLocationTarget: MapBoxCoordinate?

    /// 화면을 새로 만들 때 이어서 표시할 마지막 카메라입니다.
    ///
    /// 조립 계층이 개별 좌표와 확대 수준을 따로 읽지 않도록 한 값으로 제공합니다.
    public var camera: MapBoxCameraSnapshot {
        MapBoxCameraSnapshot(
            coordinate: cameraCoordinate,
            zoom: cameraZoom
        )
    }

    /// 위치 요청 상태와 선택적인 혼잡도 표시 기능을 함께 보관합니다.
    ///
    /// - Parameters:
    ///   - crowdViewModel: App 또는 Demo에서 조립한 혼잡도 모델입니다. `nil`이면 기존 지도만 표시합니다.
    ///   - showsCrowdPanel: 지도 위 혼잡도 범례 패널 표시 여부입니다.
    ///   - controlsBottomInset: 화면 아래 안전 영역에서 내 위치 버튼까지의 거리입니다.
    public init(
        crowdViewModel: (any MapBoxCrowdViewModelProtocol)? = nil,
        showsCrowdPanel: Bool = true,
        controlsBottomInset: CGFloat = 68
    ) {
        self.crowdViewModel = crowdViewModel
        self.showsCrowdPanel = showsCrowdPanel
        self.controlsBottomInset = controlsBottomInset
    }

    /// 지도 위 시트 높이가 바뀌었을 때 내 위치 버튼 여백을 함께 옮깁니다.
    ///
    /// - Parameter inset: 화면 아래 안전 영역에서 내 위치 버튼까지의 새 거리입니다.
    public func updateControlsBottomInset(
        _ inset: CGFloat
    ) {
        controlsBottomInset = inset
        controlsBottomInsetDidChange?(inset)
    }

    /// 아직 자동 요청을 기록하지 않았다면 앱 수명에서 한 번만 기록합니다.
    ///
    /// - Returns: 이번 호출에서 자동 요청을 새로 기록했는지 여부입니다.
    @discardableResult
    func registerAutomaticRequestIfNeeded() -> Bool {
        guard !didStartAutomatically else { return false }
        didStartAutomatically = true
        requestCount += 1
        return true
    }

    /// 사용자가 요청한 위치 이동 횟수를 앱 실행 수명에 기록합니다.
    func registerManualRequest() {
        requestCount += 1
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
