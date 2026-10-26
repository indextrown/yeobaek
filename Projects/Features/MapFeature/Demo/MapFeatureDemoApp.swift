import ComposableArchitecture
import MapFeature
import SwiftUI

@main
struct MapFeatureDemoApp: App {
    @State private var store = Store(initialState: MapKitFeature.State()) {
        MapKitFeature()
    }

    var body: some Scene {
        WindowGroup {
            MapFeatureView(store: store)
        }
    }
}
