import MapBoxFeature
import SwiftUI

@main
struct MapBoxFeatureDemoApp: App {
    @State private var session = MapBoxSession()

    var body: some Scene {
        WindowGroup {
            MapBoxFeatureView(session: session)
        }
    }
}
