import MapKit
import SwiftUI

public struct MapFeatureView: View {
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: 37.5665,
                longitude: 126.9780
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.18,
                longitudeDelta: 0.18
            )
        )
    )

    public init() {}

    public var body: some View {
        Map(position: $cameraPosition)
            .mapStyle(.standard(elevation: .realistic))
    }
}

#Preview {
    MapFeatureView()
}
