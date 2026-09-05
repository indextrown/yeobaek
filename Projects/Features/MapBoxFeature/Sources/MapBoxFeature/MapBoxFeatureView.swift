import CoreLocation
import MapboxMaps
import Core
import SwiftUI

public struct MapBoxFeatureView: View {
    private let hasAccessToken: Bool
    @State private var session: MapBoxFeatureSession

    /// 앱 수명 상태와 토큰 판정 경계를 주입해 Mapbox 화면을 만듭니다.
    ///
    /// - Parameters:
    ///   - session: 앱 실행 중 자동 요청 여부를 보관하는 상태입니다.
    ///   - accessToken: 테스트 또는 앱 설정에서 전달할 공개 Mapbox 토큰입니다.
    @MainActor
    public init(
        session: MapBoxFeatureSession,
        accessToken: String? = AppConfiguration.mapboxAccessToken
    ) {
        _session = State(initialValue: session)
        guard let accessToken,
              accessToken.hasPrefix("pk.") else {
            hasAccessToken = false
            return
        }

        MapboxOptions.accessToken = accessToken
        hasAccessToken = true
    }

    @MainActor
    public init() {
        self.init(session: MapBoxFeatureSession())
    }

    public var body: some View {
        if hasAccessToken {
            MapBoxMapContent(session: session)
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

@MainActor
private struct MapBoxMapContent: View {
    @State var session: MapBoxFeatureSession
    @State private var viewModel: MapBoxFeatureViewModel
    @State private var viewport: Viewport

    /// 앱 실행 수명의 마지막 Mapbox 카메라와 함께 지도 콘텐츠를 만듭니다.
    ///
    /// - Parameter session: 자동 요청 여부와 마지막 실제 카메라를 보관하는 상태입니다.
    init(
        session: MapBoxFeatureSession
    ) {
        _session = State(initialValue: session)
        _viewModel = State(initialValue: MapBoxFeatureViewModel())
        _viewport = State(initialValue: .camera(
            center: CLLocationCoordinate2D(
                latitude: session.cameraCoordinate.latitude,
                longitude: session.cameraCoordinate.longitude
            ),
            zoom: session.cameraZoom,
            bearing: 0,
            pitch: 0
        ))
    }

    var body: some View {
        map
    }

    private var map: some View {
        ZStack(alignment: .bottomTrailing) {
            MapboxMaps.Map(viewport: $viewport)
                .mapStyle(.standard)
                .onCameraChanged { event in
                    let coordinate = MapBoxCoordinate(
                        latitude: event.cameraState.center.latitude,
                        longitude: event.cameraState.center.longitude
                    )
                    let zoom = event.cameraState.zoom
                    Task { @MainActor in
                        session.recordCamera(
                            coordinate: coordinate,
                            zoom: zoom
                        )
                    }
                }
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("mapbox-map")
                .accessibilityValue(
                    session.cameraIsCenteredOnCurrentLocation
                        ? "현재 위치 중심"
                        : "사용자 이동 위치"
                )

            controls
        }
            .onChange(of: viewModel.cameraCommand) { _, command in
                guard let command else { return }
                session.expectCurrentLocationCamera(command.coordinate)
                viewport = .camera(
                    center: CLLocationCoordinate2D(
                        latitude: command.coordinate.latitude,
                        longitude: command.coordinate.longitude
                    ),
                    zoom: MapBoxFeatureLocationPolicy.cameraZoom,
                    bearing: 0,
                    pitch: 0
                )
                // viewport binding이 명령을 수락한 시점을 접근성에 즉시 반영하고,
                // 이후 SDK callback이 사용자 이동 여부를 다시 확정합니다.
                session.recordCamera(
                    coordinate: command.coordinate,
                    zoom: MapBoxFeatureLocationPolicy.cameraZoom
                )
            }
            .onAppear {
                session.startAutomatically(viewModel.moveToCurrentLocation)
            }
            .onDisappear { viewModel.cancel() }
            .alert(item: alertBinding) { alert in
                Alert(
                    title: Text("위치 조회 실패"),
                    message: Text(alert.message),
                    dismissButton: .default(Text("확인"))
                )
            }
    }

    private var alertBinding: Binding<MapBoxAlert?> {
        Binding(
            get: { viewModel.alert },
            set: { _ in viewModel.dismissAlert() }
        )
    }

    @ViewBuilder
    private var alertAccessibilityStatus: some View {
        if let alert = viewModel.alert {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(alertAccessibilityIdentifier(for: alert))
        }
    }

    private var controls: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let message = viewModel.authorizationMessage {
                Text(message)
                    .font(.caption)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier("mapbox-location-authorization-message")
            }
            Button {
                session.startManually(viewModel.moveToCurrentLocation)
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().accessibilityIdentifier("mapbox-current-location-progress")
                    } else {
                        Image(systemName: "location.fill")
                    }
                }
                .frame(width: 52, height: 52)
                .background(.regularMaterial, in: Circle())
                .accessibilityHidden(true)
            }
            .disabled(viewModel.isLoading)
            .accessibilityLabel("내 위치로 이동")
            .accessibilityIdentifier("mapbox-current-location-button")
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.horizontal, 16)
        // Mapbox의 오른쪽 아래 지도 정보 ornament가 44pt 영역을 사용합니다.
        .padding(.bottom, 68)
        .overlay { alertAccessibilityStatus }
        .zIndex(1)
    }

    /// 위치 오류 종류에 대응하는 접근성 식별자를 반환합니다.
    ///
    /// - Parameter alert: 화면에 표시 중인 위치 오류입니다.
    /// - Returns: timeout과 일반 실패를 구분하는 접근성 식별자입니다.
    private func alertAccessibilityIdentifier(
        for alert: MapBoxAlert
    ) -> String {
        alert.kind == .timeout
            ? "mapbox-location-timeout-alert"
            : "mapbox-location-error-alert"
    }

}

#Preview {
    MapBoxFeatureView()
}
