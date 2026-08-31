import MapBoxFeature
import SwiftUI

@main
struct MapBoxFeatureDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MapBoxFeatureView()
                .ignoresSafeArea()
        }
    }
}
