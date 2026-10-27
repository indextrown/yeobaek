import ComposableArchitecture
import Core
import CrowdPresentation
import CrowdSwiftUIFeature
import CrowdUIKitFeature
import Data
import Domain
import Foundation
import UIKit

/// 앱 전역 의존성을 만들고 화면에 연결하는 중앙 컨테이너입니다.
///
/// 같은 화면을 SwiftUI 버전과 UIKit 버전으로 각각 조립합니다. 두 버전은 같은 Repository
/// 인스턴스를 받으므로 어느 쪽을 쓰든 5분 캐시와 호출 공유 규칙이 같습니다.
@MainActor
final class AppDIContainer {
    /// 이번 실행에서 그릴 화면 구현입니다.
    let implementation: UIImplementation

    // MARK: - Repository

    // crowdHomeStore
    // crowdSnapshotStore
    /// 번들에 포함된 장소 목록과 경계입니다.
    private let places = BundledPlaceRepository()

    // makeMapBoxCrowdViewModel()
    /// 번들에서 읽은 장소와 경계입니다. 읽지 못하면 빈 목록을 사용합니다.
    private lazy var catalog: PlaceCatalog = {
        (try? places.loadCatalog()) ?? PlaceCatalog(places: [], areas: [])
    }()

    // crowdHomeStore
    // crowdSnapshotStore
    // makeDetailViewController(placeID:)
    /// 실행 환경에 맞는 혼잡도·상세 저장소입니다.
    private let crowdRepository: any CrowdRepository & PlaceDetailRepository

    /// 실행 환경에 맞는 저장소와 화면 구현을 고릅니다.
    ///
    /// - Parameter environment: UI 테스트 시나리오와 화면 구현을 읽을 환경 변수입니다.
    init(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        implementation = UIImplementation.resolve(environment: environment)
        let live = SeoulCrowdRepository(client: SeoulOpenAPIClient(apiKey: AppConfiguration.seoulAPIKey ?? ""))
#if DEBUG
        crowdRepository = environment["UITEST_CROWD_SCENARIO"] == "sample" ? SampleCrowdRepository() : live
#else
        crowdRepository = live
#endif
    }

    // MARK: - SwiftUI 버전

    // AppRootView
    /// 홈, 지도, 위치, 목록, 상세 이동 경로를 앱 실행 동안 유지하는 Store입니다.
    private(set) lazy var crowdHomeStore: StoreOf<CrowdHomeFeature> = {
        let client = CrowdClient.live(places: places, crowd: crowdRepository, details: crowdRepository)
        return Store(initialState: CrowdHomeFeature.State()) {
            CrowdHomeFeature()
        } withDependencies: {
            $0.crowdClient = client
        }
    }()

    // MARK: - UIKit 버전: State

    // makeHomeViewController(onRoute:)
    // makeListViewController(category:onRoute:)
    // makeDetailViewController(placeID:)
    /// UIKit 버전의 홈·목록·상세가 함께 보는 장소와 혼잡도 상태입니다.
    private lazy var crowdSnapshotStore = CrowdSnapshotStore(
        placeRepository: places,
        crowdRepository: crowdRepository
    )

    // MARK: - UIKit 버전: Session

    // makeHomeViewController(onRoute:)
    /// Mapbox 지도의 카메라, 자동 요청 여부와 혼잡도 결과를 앱 실행 동안 유지합니다.
    ///
    /// 혼잡도 요약은 홈 시트가 맡으므로 지도 위 범례 패널은 숨깁니다.
    private lazy var mapBoxSession = MapBoxSession(
        crowdViewModel: MapBoxCrowdViewModel(
            areas: catalog.areas,
            places: catalog.places,
            repository: crowdRepository,
            isMockData: false
        ),
        showsCrowdPanel: false,
        controlsBottomInset: CrowdSheetLayout.mapControlsBottomInset
    )

    // MARK: - UIKit 버전: Coordinator

    // AppRootView
    /// UIKit 버전의 화면 이동을 맡습니다. 루트 `UINavigationController`를 App에 넘깁니다.
    private(set) lazy var crowdUIKitCoordinator: CrowdUIKitCoordinator = {
        let coordinator = CrowdUIKitCoordinator(screens: CrowdUIKitScreens(
            makeHome: { [unowned self] onRoute in makeHomeViewController(onRoute: onRoute) },
            makeList: { [unowned self] category, onRoute in makeListViewController(category: category, onRoute: onRoute) },
            makeDetail: { [unowned self] placeID in makeDetailViewController(placeID: placeID) }
        ))
        mapBoxSession.onSelectPlace = { [weak coordinator] placeID in
            coordinator?.route(.detail(placeID))
        }
        return coordinator
    }()

    // MARK: - UIKit 버전: ViewController

    // crowdUIKitCoordinator
    /// UIKit 홈을 조립합니다. 토큰이 없으면 지도 자리에 안내 화면을 넣습니다.
    ///
    /// - Parameter onRoute: 목록·상세로 이동할 때 호출할 동작입니다.
    /// - Returns: Mapbox 지도를 자식으로 가진 홈 화면입니다.
    private func makeHomeViewController(
        onRoute: @escaping (CrowdUIKitRoute) -> Void
    ) -> UIViewController {
        CrowdHomeViewController(
            screen: CrowdHomeScreenView(frame: .zero),
            viewModel: CrowdHomeViewModel(store: crowdSnapshotStore),
            mapViewController: MapboxAccess.configure() ? makeMapBoxFeatureViewController() : MapboxTokenGuideViewController(),
            session: mapBoxSession,
            onRoute: onRoute
        )
    }

    // crowdUIKitCoordinator
    /// UIKit 목록을 조립합니다.
    ///
    /// - Parameters:
    ///   - category: 처음 선택할 분류입니다. 전체면 `nil`입니다.
    ///   - onRoute: 상세로 이동할 때 호출할 동작입니다.
    /// - Returns: 목록 화면입니다.
    private func makeListViewController(
        category: PlaceCategory?,
        onRoute: @escaping (CrowdUIKitRoute) -> Void
    ) -> UIViewController {
        PlaceListViewController(
            screen: PlaceListScreenView(frame: .zero),
            viewModel: PlaceListViewModel(store: crowdSnapshotStore, initialCategory: category),
            onRoute: onRoute
        )
    }

    // crowdUIKitCoordinator
    /// UIKit 상세를 조립합니다.
    ///
    /// - Parameter placeID: 보여 줄 장소 코드입니다.
    /// - Returns: 상세 화면이며, 모르는 장소 코드면 `nil`입니다.
    private func makeDetailViewController(
        placeID: Place.ID
    ) -> UIViewController? {
        guard let place = crowdSnapshotStore.currentState.places.first(where: { $0.id == placeID }) else { return nil }
        return PlaceDetailViewController(
            title: place.name,
            screen: PlaceDetailScreenView(frame: .zero),
            viewModel: PlaceDetailViewModel(place: place, repository: crowdRepository, store: crowdSnapshotStore)
        )
    }

    // makeHomeViewController(onRoute:)
    /// Mapbox 지도 화면의 View와 ViewModel을 조립합니다.
    ///
    /// 위치 제공자는 화면이 소유한 지도 위치 점과 같은 원천을 사용해야 하므로
    /// View를 먼저 만들고 그 제공자로 ViewModel을 만듭니다.
    ///
    /// - Returns: 새로 조립한 Mapbox 화면 ViewController입니다.
    private func makeMapBoxFeatureViewController() -> MapBoxFeatureViewController {
        let screen = MapBoxScreenView(
            initialCamera: mapBoxSession.camera,
            showsCrowdOverlay: true,
            showsCrowdPanel: mapBoxSession.showsCrowdPanel,
            controlsBottomInset: mapBoxSession.controlsBottomInset
        )
        return MapBoxFeatureViewController(
            session: mapBoxSession,
            screen: screen,
            viewModel: MapBoxFeatureViewModel(screenProvider: screen.makeLocationProvider())
        )
    }
}
