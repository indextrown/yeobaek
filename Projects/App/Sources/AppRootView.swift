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

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch selectedProvider {
                case .mapKit:
                    MapFeatureView()
                case .mapbox:
                    MapBoxFeatureView()
                }
            }
            .ignoresSafeArea()

            Picker("지도 제공자", selection: $selectedProvider) {
                ForEach(MapProvider.allCases) { provider in
                    Text(provider.rawValue)
                        .tag(provider)
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
