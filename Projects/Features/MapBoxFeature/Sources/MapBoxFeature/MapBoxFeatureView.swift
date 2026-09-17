import Core
import MapboxMaps
import SwiftUI

/// UIKit으로 구현한 Mapbox 화면을 SwiftUI 앱과 Demo에 연결합니다.
public struct MapBoxFeatureView: View {
    private let session: MapBoxSession
    private let makeViewController: (@MainActor () -> MapBoxFeatureViewController)?
    private let hasAccessToken: Bool

    /// 앱 수명 상태와 토큰 판정 경계를 주입해 Mapbox 화면을 만듭니다.
    ///
    /// - Parameters:
    ///   - session: 앱 실행 중 자동 요청 여부와 마지막 카메라를 보관하는 상태입니다.
    ///   - accessToken: 테스트 또는 앱 설정에서 전달할 공개 Mapbox 토큰입니다.
    ///   - makeViewController: DI Container가 조립한 화면을 전달할 때 사용하며, `nil`이면 기본 조립을 사용합니다.
    public init(
        session: MapBoxSession,
        accessToken: String? = AppConfiguration.mapboxAccessToken,
        makeViewController: (@MainActor () -> MapBoxFeatureViewController)? = nil
    ) {
        self.session = session
        self.makeViewController = makeViewController
        guard let accessToken,
              accessToken.hasPrefix("pk.") else {
            hasAccessToken = false
            return
        }

        MapboxOptions.accessToken = accessToken
        hasAccessToken = true
    }

    /// 기본 앱 수명 상태와 AppConfiguration의 Mapbox 토큰으로 화면을 만듭니다.
    public init() {
        self.init(session: MapBoxSession())
    }

    public var body: some View {
        if hasAccessToken {
            UIViewControllerRepresentableContainer(
                makeContent: {
                    if let makeViewController {
                        return makeViewController()
                    }
                    return MapBoxFeatureViewController(session: session)
                }
            )
            .ignoresSafeArea()
        } else {
            ContentUnavailableView(
                "Mapbox 토큰이 필요해요",
                systemImage: "key.horizontal",
                description: Text(
                    "MAPBOX_ACCESS_TOKEN 빌드 설정에 공개 액세스 토큰을 추가해 주세요."
                )
            )
        }
    }
}

#Preview {
    MapBoxFeatureView()
}
