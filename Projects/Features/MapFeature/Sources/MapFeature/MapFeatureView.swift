import MapKit
import SwiftUI

public struct MapFeatureView: View {
    @State private var session: MapFeatureSession
    @State private var viewModel: MapFeatureViewModel
    @State private var cameraPosition: MapCameraPosition

    /// 앱 수명 자동 실행 상태와 함께 MapKit 화면을 만듭니다.
    ///
    /// - Parameters:
    ///   - session: 앱 실행 중 자동 요청 여부를 보관하는 상태입니다.
    ///   - viewModel: 위치 요청과 화면 상태를 관리하는 ViewModel입니다.
    @MainActor
    public init(
        session: MapFeatureSession,
        viewModel: MapFeatureViewModel
    ) {
        _session = State(initialValue: session)
        _viewModel = State(initialValue: viewModel)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: session.cameraCoordinate.latitude,
                longitude: session.cameraCoordinate.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: session.cameraSpan,
                longitudeDelta: session.cameraSpan
            )
        )))
    }

    /// 앱 수명 자동 실행 상태와 기본 위치 ViewModel로 MapKit 화면을 만듭니다.
    ///
    /// - Parameter session: 앱 실행 중 자동 요청 여부를 보관하는 상태입니다.
    @MainActor
    public init(
        session: MapFeatureSession
    ) {
        self.init(
            session: session,
            viewModel: MapFeatureViewModel()
        )
    }

    @MainActor
    public init() {
        self.init(session: MapFeatureSession())
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
                    Task { @MainActor in
                        session.recordCamera(
                            coordinate: coordinate,
                            span: span
                        )
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("mapkit-map")
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
                // SwiftUI가 명령을 수락한 즉시 접근성 상태를 갱신하고,
                // 이후 실제 카메라 callback이 사용자 이동 여부를 다시 확정합니다.
                session.recordCamera(
                    coordinate: command.coordinate,
                    span: MapFeatureLocationPolicy.cameraSpan
                )
            }
            .onAppear {
                session.startAutomatically(viewModel.moveToCurrentLocation)
            }
            .onDisappear { viewModel.cancel() }
            .alert(item: Binding(
                get: { viewModel.alert },
                set: { _ in viewModel.dismissAlert() }
            )) { alert in
                Alert(
                    title: Text("위치 조회 실패"),
                    message: Text(alert.message),
                    dismissButton: .default(Text("확인"))
                )
            }
    }

    @ViewBuilder
    private var alertAccessibilityStatus: some View {
        if let alert = viewModel.alert {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(
                    alert.kind == .timeout
                        ? "mapkit-location-timeout-alert"
                        : "mapkit-location-error-alert"
                )
        }
    }

    private var controls: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let message = viewModel.authorizationMessage {
                Text(message)
                    .font(.caption)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier("mapkit-location-authorization-message")
            }
            Button {
                session.startManually(viewModel.moveToCurrentLocation)
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().accessibilityIdentifier("mapkit-current-location-progress")
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
    MapFeatureView()
}
