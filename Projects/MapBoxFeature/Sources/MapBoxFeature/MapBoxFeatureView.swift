import CoreLocation
import SwiftUI
import ThirdParty

public struct MapBoxFeatureView: View {
    private let hasAccessToken: Bool

    public init() {
        let accessToken = Bundle.main.object(
            forInfoDictionaryKey: "MBXAccessToken"
        ) as? String

        hasAccessToken = accessToken?.hasPrefix("pk.") == true
    }

    public var body: some View {
        if hasAccessToken {
            MapboxMaps.Map(
                initialViewport: .camera(
                    center: CLLocationCoordinate2D(
                        latitude: 37.5665,
                        longitude: 126.9780
                    ),
                    zoom: 10.5,
                    bearing: 0,
                    pitch: 0
                )
            )
            .mapStyle(.standard)
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
