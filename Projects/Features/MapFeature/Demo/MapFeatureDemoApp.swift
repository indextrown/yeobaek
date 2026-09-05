import MapFeature
import SwiftUI

@main
struct MapFeatureDemoApp: App {
    @State private var session = MapFeatureSession()

    var body: some Scene {
        WindowGroup {
            MapFeatureView(session: session)
        }
    }
}
