import MapFeature
import SwiftUI

@main
struct MapFeatureDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MapFeatureView()
                .ignoresSafeArea()
        }
    }
}
