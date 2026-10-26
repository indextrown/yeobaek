import ComposableArchitecture
import MapKit
import SwiftUI

public struct MapFeatureView: View {
    @Bindable private var store: StoreOf<MapKitFeature>
    @State private var cameraPosition: MapCameraPosition

    /// 앱 실행 동안 유지되는 Store로 MapKit 화면을 만듭니다.
    ///
    /// - Parameter store: 위치 요청과 카메라 상태를 관리하는 Store입니다.
    @MainActor
    public init(
        store: StoreOf<MapKitFeature>
    ) {
        self.store = store
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: store.cameraCoordinate.latitude,
                longitude: store.cameraCoordinate.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: store.cameraSpan,
                longitudeDelta: store.cameraSpan
            )
        )))
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
            }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea()
                .onMapCameraChange(frequency: .onEnd) { context in
                    let coordinate = MapFeatureCoordinate(
                        latitude: context.region.center.latitude,
                        longitude: context.region.center.longitude
                    )
                    let span = context.region.span.latitudeDelta
                    // 지도 갱신 도중 상태를 바꾸지 않도록 다음 main actor 턴에 전달합니다.
                    Task { @MainActor in
                        store.send(.cameraChanged(coordinate, span: span))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("mapkit-map")
                .accessibilityValue(
                    store.cameraIsCenteredOnCurrentLocation
                        ? "현재 위치 중심"
                        : "사용자 이동 위치"
                )

            controls
        }
            .onChange(of: store.cameraCommand) { _, command in
                guard let command else { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(
                            latitude: command.coordinate.latitude,
                            longitude: command.coordinate.longitude
                        ),
                        span: MKCoordinateSpan(
                            latitudeDelta: MapFeatureLocationPolicy.cameraSpan,
                            longitudeDelta: MapFeatureLocationPolicy.cameraSpan
                        )
                    ))
                }
            }
            .onAppear { store.send(.onAppear) }
            .onDisappear { store.send(.onDisappear) }
            .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var alertAccessibilityStatus: some View {
        if let failureKind = store.failureKind {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(
                    failureKind == .timeout
                        ? "mapkit-location-timeout-alert"
                        : "mapkit-location-error-alert"
                )
        }
    }

    private var controls: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let message = store.authorizationMessage {
                Text(message)
                    .font(.caption)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier("mapkit-location-authorization-message")
            }
            Button {
                store.send(.currentLocationButtonTapped)
            } label: {
                Group {
                    if store.isLoading {
                        ProgressView().accessibilityIdentifier("mapkit-current-location-progress")
                    } else {
                        Image(systemName: "location.fill")
                    }
                }
                .frame(width: 52, height: 52)
                .background(.regularMaterial, in: Circle())
                .accessibilityHidden(true)
            }
            .disabled(store.isLoading)
            .accessibilityLabel("내 위치로 이동")
            .accessibilityIdentifier("mapkit-current-location-button")
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 68)
        .overlay { alertAccessibilityStatus }
        .zIndex(1)
    }

}

#Preview {
    MapFeatureView(
        store: Store(initialState: MapKitFeature.State()) {
            MapKitFeature()
        }
    )
}
