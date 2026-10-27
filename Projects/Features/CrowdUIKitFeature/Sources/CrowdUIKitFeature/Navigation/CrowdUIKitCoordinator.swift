import Domain
import UIKit

/// UIKit 버전 화면을 만드는 방법입니다. 구체 타입 조립은 App의 DI Container가 맡습니다.
public struct CrowdUIKitScreens {
    public let makeHome: (_ onRoute: @escaping (CrowdUIKitRoute) -> Void) -> UIViewController
    public let makeList: (_ category: PlaceCategory?, _ onRoute: @escaping (CrowdUIKitRoute) -> Void) -> UIViewController
    public let makeDetail: (_ placeID: Place.ID) -> UIViewController?

    /// 화면 생성 방법을 묶습니다.
    ///
    /// - Parameters:
    ///   - makeHome: 홈 화면을 만듭니다.
    ///   - makeList: 분류를 받아 목록 화면을 만듭니다.
    ///   - makeDetail: 장소 코드를 받아 상세 화면을 만듭니다. 모르는 장소면 `nil`입니다.
    public init(
        makeHome: @escaping (_ onRoute: @escaping (CrowdUIKitRoute) -> Void) -> UIViewController,
        makeList: @escaping (_ category: PlaceCategory?, _ onRoute: @escaping (CrowdUIKitRoute) -> Void) -> UIViewController,
        makeDetail: @escaping (_ placeID: Place.ID) -> UIViewController?
    ) {
        self.makeHome = makeHome
        self.makeList = makeList
        self.makeDetail = makeDetail
    }
}

/// UIKit 버전의 홈·목록·상세 이동을 `UINavigationController`로 연결합니다.
///
/// SwiftUI 버전의 `NavigationStack`과 같은 순서로 화면을 쌓습니다.
@MainActor
public final class CrowdUIKitCoordinator {
    public let navigationController = UINavigationController()
    private let screens: CrowdUIKitScreens

    /// 화면 생성 방법으로 코디네이터를 만들고 홈을 루트로 둡니다.
    ///
    /// - Parameter screens: 홈·목록·상세 생성 방법입니다.
    public init(
        screens: CrowdUIKitScreens
    ) {
        self.screens = screens
        let home = screens.makeHome { [weak self] route in self?.route(route) }
        navigationController.setViewControllers([home], animated: false)
    }

    /// 목록 또는 상세 화면으로 이동합니다.
    ///
    /// - Parameter route: 이동할 화면입니다.
    public func route(
        _ route: CrowdUIKitRoute
    ) {
        switch route {
        case let .list(category):
            let list = screens.makeList(category) { [weak self] route in self?.route(route) }
            navigationController.pushViewController(list, animated: true)
        case let .detail(placeID):
            guard let detail = screens.makeDetail(placeID) else { return }
            navigationController.pushViewController(detail, animated: true)
        }
    }
}
