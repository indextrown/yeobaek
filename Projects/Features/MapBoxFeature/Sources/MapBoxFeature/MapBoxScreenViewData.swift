import Core
import Foundation
import RxSwift

/// Mapbox 지도 카메라가 실제로 표시 중인 위치입니다.
public struct MapBoxCameraSnapshot: Equatable, Sendable {
    /// 지도 중심 좌표입니다.
    public let coordinate: MapBoxCoordinate

    /// 지도 확대 수준입니다.
    public let zoom: Double

    /// 지도 SDK가 보고한 카메라 상태를 보관합니다.
    ///
    /// - Parameters:
    ///   - coordinate: 지도 중심 좌표입니다.
    ///   - zoom: 지도 확대 수준입니다.
    public init(
        coordinate: MapBoxCoordinate,
        zoom: Double
    ) {
        self.coordinate = coordinate
        self.zoom = zoom
    }
}

/// Mapbox 화면이 표시할 값만 담은 표시 데이터입니다.
///
/// 위치 요청 상태와 혼잡도 상태를 하나로 합쳐 View에 전달합니다. 두 ViewModel의
/// Output을 ViewController가 합성하므로 View는 어느 ViewModel에서 온 값인지 몰라도 됩니다.
public struct MapBoxScreenViewData: Equatable {
    /// 혼잡도 범례와 지도 채움에 함께 쓰는 표시 데이터입니다.
    public struct Crowd: Equatable {
        /// 범례 제목입니다. 목업 여부에 따라 달라집니다.
        public let title: String

        /// 목업 안내와 조회 진행 상황을 합친 문구입니다.
        public let statusText: String

        /// 전체 영역 보기 버튼에 표시할 문구입니다.
        public let showAreasButtonTitle: String

        /// 지도에 채울 경계와 장소별 혼잡도입니다.
        public let areas: [MapBoxCrowdArea]

        /// 범례와 지도에 함께 반영할 값을 묶습니다.
        ///
        /// - Parameters:
        ///   - title: 범례 제목입니다.
        ///   - statusText: 목업 안내와 조회 상황을 합친 문구입니다.
        ///   - showAreasButtonTitle: 전체 영역 보기 버튼 문구입니다.
        ///   - areas: 지도에 채울 경계와 혼잡도입니다.
        public init(
            title: String,
            statusText: String,
            showAreasButtonTitle: String,
            areas: [MapBoxCrowdArea]
        ) {
            self.title = title
            self.statusText = statusText
            self.showAreasButtonTitle = showAreasButtonTitle
            self.areas = areas
        }
    }

    /// 위치 권한 확인이나 좌표 조회가 진행 중이면 `true`입니다.
    public let isLocating: Bool

    /// 권한이 거부됐을 때 표시할 안내 문구이며, 표시하지 않으면 `nil`입니다.
    public let authorizationMessage: String?

    /// 혼잡도 기능을 사용하지 않으면 `nil`입니다.
    public let crowd: Crowd?

    /// Mapbox 화면에 표시할 값을 묶습니다.
    ///
    /// - Parameters:
    ///   - isLocating: 위치 조회가 진행 중이면 `true`입니다.
    ///   - authorizationMessage: 권한 안내 문구이며, 표시하지 않으면 `nil`입니다.
    ///   - crowd: 혼잡도 표시 데이터이며, 기능을 사용하지 않으면 `nil`입니다.
    public init(
        isLocating: Bool,
        authorizationMessage: String?,
        crowd: Crowd?
    ) {
        self.isLocating = isLocating
        self.authorizationMessage = authorizationMessage
        self.crowd = crowd
    }

    /// 두 ViewModel의 최신 상태를 화면 표시 데이터로 합칩니다.
    ///
    /// - Parameters:
    ///   - location: 현재 위치 요청의 최신 진행 상태입니다.
    ///   - crowd: 혼잡도 조회의 최신 상태이며, 기능을 사용하지 않으면 `nil`입니다.
    ///   - isMockData: 실제 관측값이 아닌 테스트 데이터이면 `true`입니다.
    /// - Returns: View가 그대로 표시할 수 있는 화면 데이터입니다.
    public static func make(
        location: MapBoxLocationState,
        crowd: MapBoxCrowdState?,
        isMockData: Bool
    ) -> MapBoxScreenViewData {
        MapBoxScreenViewData(
            isLocating: location == .requestingAuthorization || location == .locating,
            authorizationMessage: location == .authorizationDenied
                ? "위치 권한이 없어 현재 위치를 확인할 수 없습니다."
                : nil,
            crowd: crowd.map { state in
                Crowd(
                    title: isMockData ? "목업 혼잡도" : "지역 혼잡도",
                    statusText: statusText(for: state, isMockData: isMockData),
                    showAreasButtonTitle: isMockData ? "목업 지역 보기" : "전체 지역 보기",
                    areas: state.areas
                )
            }
        )
    }

    /// 목업 안내에 조회 진행 상황을 덧붙인 범례 문구를 만듭니다.
    ///
    /// - Parameters:
    ///   - state: 혼잡도 조회의 최신 상태입니다.
    ///   - isMockData: 실제 관측값이 아닌 테스트 데이터이면 `true`입니다.
    /// - Returns: 범례 아래에 표시할 한국어 안내 문구입니다.
    private static func statusText(
        for state: MapBoxCrowdState,
        isMockData: Bool
    ) -> String {
        let notice = isMockData
            ? "테스트용 경계와 혼잡도입니다. 실제 관측값이 아닙니다."
            : "색상은 지역별 혼잡도를 나타냅니다."
        if state.isLoading {
            return notice + "\n혼잡도를 불러오는 중입니다."
        }
        if state.unavailableCount > 0 {
            return notice + "\n일부 조회에 실패해 회색으로 표시합니다. 화면을 다시 열면 재시도합니다."
        }
        return notice
    }
}

/// Mapbox 화면 View가 공개하는 입력, 표시 데이터와 지도 명령을 고정합니다.
///
/// 지도 SDK 객체를 노출하지 않습니다. 카메라 이동처럼 상태로 표현할 수 없는 동작은
/// `render` 대신 별도 명령 메서드로 공개합니다.
public protocol MapBoxFeatureScreenProtocol: ViewType where ViewData == MapBoxScreenViewData {
    /// 사용자가 현재 위치 버튼을 누른 이벤트입니다.
    var currentLocationTapped: Observable<Void> { get }

    /// 지도가 실제로 표시한 카메라가 바뀐 이벤트입니다.
    var cameraChanged: Observable<MapBoxCameraSnapshot> { get }

    /// 지도 중심을 지정한 좌표로 이동합니다.
    ///
    /// - Parameters:
    ///   - coordinate: 이동할 중심 좌표입니다.
    ///   - zoom: 이동 후 적용할 확대 수준입니다.
    func moveCamera(
        to coordinate: MapBoxCoordinate,
        zoom: Double
    )

    /// 현재 위치 중심 여부를 지도 접근성 값에 반영합니다.
    ///
    /// - Parameter isCentered: 카메라가 현재 위치를 중심에 두고 있으면 `true`입니다.
    func updateMapAccessibility(
        isCenteredOnCurrentLocation isCentered: Bool
    )

    /// 화면의 지도와 같은 원천을 사용하는 위치 제공자를 만듭니다.
    ///
    /// - Returns: 이 화면의 지도에 연결된 위치 제공자입니다.
    func makeLocationProvider() -> any MapboxLocationProviding
}
