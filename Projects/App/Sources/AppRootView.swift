import CrowdFeature
import MapBoxFeature
import SwiftUI

/// Mapbox 지도 위에 혼잡도 홈 시트를 올리고 목록·상세 이동을 연결하는 루트 화면입니다.
struct AppRootView: View {
    /// 홈 Store, 지도 세션과 화면 조립을 담당하는 앱 전역 컨테이너입니다.
    private let container: AppDIContainer

    /// 앱 전역 의존성을 주입해 루트 화면을 만듭니다.
    ///
    /// - Parameter container: 홈 Store와 지도 화면을 조립할 DI Container입니다.
    init(
        container: AppDIContainer
    ) {
        self.container = container
    }

    var body: some View {
        CrowdHomeView(
            store: container.crowdHomeStore,
            onSheetHeightChange: { container.mapBoxSession.updateControlsBottomInset($0) }
        ) {
            MapBoxFeatureView(
                session: container.mapBoxSession,
                makeViewController: {
                    container.makeMapBoxFeatureViewController()
                }
            )
        }
    }
}

#Preview {
    AppRootView(container: AppDIContainer())
}
