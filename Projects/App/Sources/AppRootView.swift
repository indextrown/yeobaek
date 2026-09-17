import MapBoxFeature
import MapFeature
import SwiftUI

struct AppRootView: View {
    private enum MapProvider: String, CaseIterable, Identifiable {
        case mapKit = "MapKit"
        case mapbox = "Mapbox"

        var id: Self { self }
    }

    /// 지도 세션과 화면 조립을 담당하는 앱 전역 컨테이너입니다.
    private let container: AppDIContainer

    @State private var selectedProvider: MapProvider = .mapKit

    /// 앱 전역 의존성을 주입해 루트 화면을 만듭니다.
    ///
    /// - Parameter container: 지도 세션과 화면을 조립할 DI Container입니다.
    init(
        container: AppDIContainer
    ) {
        self.container = container
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch selectedProvider {
                case .mapKit:
                    MapFeatureView(session: container.mapKitSession)
                case .mapbox:
                    MapBoxFeatureView(
                        session: container.mapBoxSession,
                        makeViewController: {
                            container.makeMapBoxFeatureViewController()
                        }
                    )
                }
            }

            Picker("지도 제공자", selection: $selectedProvider) {
                ForEach(MapProvider.allCases) { provider in
                    Text(provider.rawValue)
                        .tag(provider)
                        .accessibilityIdentifier(provider.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

#Preview {
    AppRootView(container: AppDIContainer())
}
