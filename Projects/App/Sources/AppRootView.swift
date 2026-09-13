import Data
import SwiftUI
import MapBoxFeature
import MapFeature

struct AppRootView: View {
    private enum MapProvider: String, CaseIterable, Identifiable {
        case mapKit = "MapKit"
        case mapbox = "Mapbox"

        var id: Self { self }
    }

    @State private var selectedProvider: MapProvider = .mapKit
    @State private var mapKitSession = MapFeatureSession()
    @State private var mapboxSession = MapBoxSession(
        crowdViewModel: MapBoxCrowdViewModel(
            areas: CrowdMockData.areas,
            repository: MockCrowdRepository(),
            isMockData: true
        )
    )

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch selectedProvider {
                case .mapKit:
                    MapFeatureView(session: mapKitSession)
                case .mapbox:
                    MapBoxFeatureView(session: mapboxSession)
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
    AppRootView()
}
