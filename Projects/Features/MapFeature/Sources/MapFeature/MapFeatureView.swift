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
            
            CurrentLocationControls(
                authorizationMessage: store.authorizationMessage,
                isLoading: store.isLoading,
                failureKind: store.failureKind,
                onCurrentLocationTap: { store.send(.currentLocationButtonTapped) }
            )
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
}

/// 권한 안내 문구와 내 위치 버튼을 지도 오른쪽 아래에 배치합니다.
private struct CurrentLocationControls: View {
    let authorizationMessage: String?
    let isLoading: Bool
    let failureKind: MapKitFeature.State.FailureKind?
    let onCurrentLocationTap: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let authorizationMessage {
                Text(authorizationMessage)
                    .font(.caption)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier("mapkit-location-authorization-message")
            }
            Button(action: onCurrentLocationTap) {
                Group {
                    if isLoading {
                        ProgressView().accessibilityIdentifier("mapkit-current-location-progress")
                    } else {
                        Image(systemName: "location.fill")
                    }
                }
                .frame(width: 52, height: 52)
                .background(.regularMaterial, in: Circle())
                .accessibilityHidden(true)
            }
            .disabled(isLoading)
            .accessibilityLabel("내 위치로 이동")
            .accessibilityIdentifier("mapkit-current-location-button")
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 68)
        .overlay { LocationFailureAccessibilityMarker(failureKind: failureKind) }
        .zIndex(1)
    }
}

/// UI 테스트가 위치 조회 실패 종류를 확인할 수 있도록 보이지 않는 접근성 요소를 둡니다.
private struct LocationFailureAccessibilityMarker: View {
    let failureKind: MapKitFeature.State.FailureKind?

    var body: some View {
        if let failureKind {
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
}

#Preview {
    MapFeatureView(
        store: Store(initialState: MapKitFeature.State()) {
            MapKitFeature()
        }
    )
}
