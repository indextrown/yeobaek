import CrowdPresentation
import CrowdUIKitFeature
import Data
import Domain
import UIKit

/// UIKit 버전 혼잡도 화면만 독립 실행하는 Demo 앱입니다. 네트워크 없이 예시 혼잡도를 씁니다.
@main
final class CrowdUIKitFeatureDemoApp: UIResponder, UIApplicationDelegate {
    /// 단일 창 Scene을 연결합니다.
    ///
    /// - Parameters:
    ///   - application: 실행 중인 앱입니다.
    ///   - connectingSceneSession: 연결할 Scene 세션입니다.
    ///   - options: Scene 연결 옵션입니다.
    /// - Returns: Demo Scene 설정입니다.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = CrowdUIKitDemoSceneDelegate.self
        return configuration
    }
}

/// Demo 창에 UIKit 버전 화면 흐름을 올립니다.
final class CrowdUIKitDemoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: CrowdUIKitCoordinator?

    /// 예시 저장소로 UIKit 버전 홈을 조립해 창에 올립니다.
    ///
    /// - Parameters:
    ///   - scene: 연결된 Scene입니다.
    ///   - session: Scene 세션입니다.
    ///   - connectionOptions: 연결 옵션입니다.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let places = BundledPlaceRepository()
        let catalog = (try? places.loadCatalog()) ?? PlaceCatalog(places: [], areas: [])
        let repository = SampleCrowdRepository()
        let store = CrowdSnapshotStore(placeRepository: places, crowdRepository: repository)
        let mapSession = MapBoxSession(
            crowdViewModel: MapBoxCrowdViewModel(areas: catalog.areas, places: catalog.places, repository: repository, isMockData: true),
            showsCrowdPanel: false,
            controlsBottomInset: CrowdSheetLayout.mapControlsBottomInset
        )
        let coordinator = CrowdUIKitCoordinator(screens: CrowdUIKitScreens(
            makeHome: { onRoute in
                let map: UIViewController = MapboxAccess.configure()
                    ? MapBoxFeatureViewController(session: mapSession)
                    : MapboxTokenGuideViewController()
                return CrowdHomeViewController(
                    screen: CrowdHomeScreenView(frame: .zero),
                    viewModel: CrowdHomeViewModel(store: store),
                    mapViewController: map,
                    session: mapSession,
                    onRoute: onRoute
                )
            },
            makeList: { category, onRoute in
                PlaceListViewController(
                    screen: PlaceListScreenView(frame: .zero),
                    viewModel: PlaceListViewModel(store: store, initialCategory: category),
                    onRoute: onRoute
                )
            },
            makeDetail: { placeID in
                guard let place = store.currentState.places.first(where: { $0.id == placeID }) else { return nil }
                return PlaceDetailViewController(
                    title: place.name,
                    screen: PlaceDetailScreenView(frame: .zero),
                    viewModel: PlaceDetailViewModel(place: place, repository: repository, store: store)
                )
            }
        ))
        mapSession.onSelectPlace = { [weak coordinator] placeID in coordinator?.route(.detail(placeID)) }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = coordinator.navigationController
        window.makeKeyAndVisible()
        self.window = window
        self.coordinator = coordinator
    }
}
