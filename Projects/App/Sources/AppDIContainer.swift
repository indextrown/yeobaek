import Data
import Domain
import MapBoxFeature
import MapFeature

/// 앱 전역 의존성을 만들고 화면에 연결하는 중앙 컨테이너입니다.
///
/// 화면은 이 컨테이너를 통해서만 Repository 구현을 전달받습니다. 목업을 실제 API
/// 구현으로 바꿀 때 이 파일의 Repository 프로퍼티만 교체하면 됩니다.
@MainActor
final class AppDIContainer {
    // MARK: - Repository

    // makeMapBoxCrowdViewModel()
    /// 아직 서울시 API 구현이 연결되지 않아 목업 저장소를 사용합니다.
    private let crowdRepository: any CrowdRepository = MockCrowdRepository()

    // MARK: - Session

    // AppRootView
    /// MapKit 지도의 카메라와 위치 요청 상태를 앱 실행 동안 유지합니다.
    private(set) lazy var mapKitSession = MapFeatureSession()

    // AppRootView
    // makeMapBoxFeatureViewController()
    /// Mapbox 지도의 카메라, 자동 요청 여부와 혼잡도 결과를 앱 실행 동안 유지합니다.
    private(set) lazy var mapBoxSession: MapBoxSession = {
        MapBoxSession(crowdViewModel: makeMapBoxCrowdViewModel())
    }()

    // MARK: - ViewModel

    // mapBoxSession
    /// Mapbox 화면에서 사용할 혼잡도 ViewModel을 만듭니다.
    ///
    /// - Returns: 목업 경계와 목업 저장소를 연결한 혼잡도 ViewModel입니다.
    private func makeMapBoxCrowdViewModel() -> MapBoxCrowdViewModel {
        MapBoxCrowdViewModel(
            areas: CrowdMockData.areas,
            repository: crowdRepository,
            isMockData: true
        )
    }

    // makeMapBoxFeatureViewController()
    /// Mapbox 화면에서 사용할 위치 조회 ViewModel을 만듭니다.
    ///
    /// - Parameter screen: 위치 원천을 제공할 화면 View입니다.
    /// - Returns: 화면의 지도 위치 점에 연결한 위치 ViewModel입니다.
    private func makeMapBoxFeatureViewModel(
        screen: any MapBoxFeatureScreenProtocol
    ) -> any MapBoxFeatureViewModelProtocol {
        MapBoxFeatureViewModel(screenProvider: screen.makeLocationProvider())
    }

    // MARK: - View

    // makeMapBoxFeatureViewController()
    /// Mapbox 화면의 View 구현체를 만듭니다.
    ///
    /// - Returns: 마지막 카메라를 이어받고 혼잡도 범례를 표시하는 View입니다.
    private func makeMapBoxScreen() -> any MapBoxFeatureScreenProtocol {
        MapBoxScreenView(
            initialCamera: mapBoxSession.camera,
            showsCrowdOverlay: true
        )
    }

    // MARK: - ViewController

    // AppRootView
    /// Mapbox 화면의 View와 ViewModel을 조립합니다.
    ///
    /// 위치 제공자는 화면이 소유한 지도 위치 점과 같은 원천을 사용해야 하므로
    /// View를 먼저 만들고 그 제공자로 ViewModel을 만듭니다.
    ///
    /// - Returns: 새로 조립한 Mapbox 화면 ViewController입니다.
    func makeMapBoxFeatureViewController() -> MapBoxFeatureViewController {
        let screen = makeMapBoxScreen()

        return MapBoxFeatureViewController(
            session: mapBoxSession,
            screen: screen,
            viewModel: makeMapBoxFeatureViewModel(screen: screen)
        )
    }
}
