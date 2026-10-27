import Core
import CrowdSwiftUIFeature
import SwiftUI

/// 설정한 화면 구현(SwiftUI 또는 UIKit)으로 혼잡도 화면 전체를 그리는 루트 화면입니다.
///
/// 두 구현은 섞지 않습니다. UIKit 버전은 루트 내비게이션 하나만 `UIViewControllerRepresentable`로 감쌉니다.
struct AppRootView: View {
    /// 두 구현의 Store, 코디네이터와 화면 조립을 담당하는 앱 전역 컨테이너입니다.
    private let container: AppDIContainer

    /// 앱 전역 의존성을 주입해 루트 화면을 만듭니다.
    ///
    /// - Parameter container: 화면 구현과 의존성을 고른 DI Container입니다.
    init(
        container: AppDIContainer
    ) {
        self.container = container
    }

    var body: some View {
        switch container.implementation {
        case .swiftUI:
            CrowdHomeView(store: container.crowdHomeStore)
        case .uiKit:
            UIViewControllerRepresentableContainer(
                makeContent: { container.crowdUIKitCoordinator.navigationController }
            )
            .ignoresSafeArea()
        }
    }
}

#Preview {
    AppRootView(container: AppDIContainer())
}
