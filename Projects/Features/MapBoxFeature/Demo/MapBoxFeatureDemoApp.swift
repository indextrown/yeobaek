import Data
import MapBoxFeature
import SwiftUI

@main
struct MapBoxFeatureDemoApp: App {
    @State private var session = MapBoxSession(
        crowdViewModel: MapBoxCrowdViewModel(
            areas: CrowdMockData.areas,
            repository: MockCrowdRepository(),
            isMockData: true
        )
    )

    var body: some Scene {
        WindowGroup {
            MapBoxFeatureView(session: session)
        }
    }
}
