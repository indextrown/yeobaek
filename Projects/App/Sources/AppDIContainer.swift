import ComposableArchitecture
import Core
import CrowdFeature
import Data
import Domain
import Foundation
import MapBoxFeature

/// 앱 전역 의존성을 만들고 화면에 연결하는 중앙 컨테이너입니다.
///
/// 화면은 이 컨테이너를 통해서만 Repository 구현을 전달받습니다. 지도(Mapbox)와
/// 홈·목록·상세(TCA)가 같은 혼잡도 저장소를 공유해서 같은 장소를 두 번 호출하지 않고
/// 5분 캐시를 함께 씁니다.
@MainActor
final class AppDIContainer {
    // MARK: - Repository

    // makeMapBoxCrowdViewModel()
    // crowdHomeStore
    /// 번들에 포함된 장소 목록과 경계입니다.
    private let places = BundledPlaceRepository()

    // makeMapBoxCrowdViewModel()
    /// 번들에서 읽은 장소와 경계입니다. 읽지 못하면 빈 목록을 사용합니다.
    private lazy var catalog: PlaceCatalog = {
        (try? places.loadCatalog()) ?? PlaceCatalog(places: [], areas: [])
    }()

    // makeMapBoxCrowdViewModel()
    // crowdHomeStore
    /// 실행 환경에 맞는 혼잡도·상세 저장소입니다.
    private let crowdRepository: any CrowdRepository & PlaceDetailRepository

    /// 실행 환경에 맞는 저장소를 고릅니다.
    ///
    /// - Parameter environment: UI 테스트 시나리오를 읽을 환경 변수입니다.
    init(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let live = SeoulCrowdRepository(client: SeoulOpenAPIClient(apiKey: AppConfiguration.seoulAPIKey ?? ""))
#if DEBUG
        crowdRepository = environment["UITEST_CROWD_SCENARIO"] == "sample" ? SampleCrowdRepository() : live
#else
        crowdRepository = live
#endif
    }

    // MARK: - Store

    // AppRootView
    // mapBoxSession
    /// 홈, 목록, 상세 이동 경로를 앱 실행 동안 유지하는 Store입니다.
    private(set) lazy var crowdHomeStore: StoreOf<CrowdHomeFeature> = {
        let client = CrowdClient.live(places: places, crowd: crowdRepository, details: crowdRepository)
        return Store(initialState: CrowdHomeFeature.State()) {
            CrowdHomeFeature()
        } withDependencies: {
            $0.crowdClient = client
        }
    }()

    // MARK: - Session

    // AppRootView
    // makeMapBoxFeatureViewController()
    /// Mapbox 지도의 카메라, 자동 요청 여부와 혼잡도 결과를 앱 실행 동안 유지합니다.
    ///
    /// 혼잡도 요약은 홈 시트가 맡으므로 지도 위 범례 패널은 숨깁니다.
    private(set) lazy var mapBoxSession: MapBoxSession = {
        let session = MapBoxSession(
            crowdViewModel: makeMapBoxCrowdViewModel(),
            showsCrowdPanel: false,
            controlsBottomInset: CrowdHomeLayout.mapControlsBottomInset
        )
        let store = crowdHomeStore
        session.onSelectPlace = { placeID in
            store.send(.placeTapped(placeID))
        }
        return session
    }()

    // MARK: - ViewModel

    // mapBoxSession
    /// Mapbox 화면에서 사용할 혼잡도 ViewModel을 만듭니다.
    ///
    /// - Returns: 번들 경계와 혼잡도 저장소를 연결한 혼잡도 ViewModel입니다.
    private func makeMapBoxCrowdViewModel() -> MapBoxCrowdViewModel {
        MapBoxCrowdViewModel(
            areas: catalog.areas,
            places: catalog.places,
            repository: crowdRepository,
            isMockData: false
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
    /// - Returns: 마지막 카메라를 이어받고 혼잡도 채움만 표시하는 View입니다.
    private func makeMapBoxScreen() -> any MapBoxFeatureScreenProtocol {
        MapBoxScreenView(
            initialCamera: mapBoxSession.camera,
            showsCrowdOverlay: true,
            showsCrowdPanel: mapBoxSession.showsCrowdPanel,
            controlsBottomInset: mapBoxSession.controlsBottomInset
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
