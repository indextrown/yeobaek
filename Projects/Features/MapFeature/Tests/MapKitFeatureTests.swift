import ComposableArchitecture
import Foundation
import Testing
@testable import MapFeature

@MainActor
@Suite("MapKit 현재 위치 Reducer")
struct MapKitFeatureTests {
    private let seoul = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
    private let other = MapFeatureCoordinate(latitude: 37.6, longitude: 127.1)

    @Test("현재 위치 이동은 기존 MapKit 화면의 확대 수준과 제한 시간을 보존한다")
    func policyPreservesExistingMapPresentation() {
        #expect(MapFeatureLocationPolicy.cameraSpan == 0.18)
        #expect(MapFeatureLocationPolicy.compatibilityTimeout == .seconds(10))
    }

    @Test("초기 상태는 요청과 사용자 안내가 없는 재시도 가능 상태다")
    func initialStateIsRetryableAndHasNoOutput() {
        let state = MapKitFeature.State()

        #expect(state.status == .idle)
        #expect(!state.isLoading)
        #expect(state.authorizationMessage == nil)
        #expect(state.alert == nil)
        #expect(state.cameraCommand == nil)
        #expect(state.requestCount == 0)
    }

    @Test("화면 활성화는 같은 Store에서 자동 요청을 한 번만 시작한다")
    func automaticRequestStartsOncePerStore() async {
        let store = makeStore(location: .immediate(seoul))

        await store.send(.onAppear) {
            $0.didStartAutomatically = true
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }
        await store.send(.onDisappear)
        await store.send(.onAppear)
    }

    @Test("수동 요청은 최초 자동 요청 권리를 소모하지 않는다")
    func manualRequestDoesNotConsumeAutomaticRequest() async {
        let store = makeStore(location: .immediate(seoul))

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }
        await store.send(.onAppear) {
            $0.didStartAutomatically = true
            $0.requestCount = 2
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 1)
        }
        await store.send(.onAppear)
    }

    @Test("자동 요청이 권한 거부로 끝나도 재진입은 반복하지 않는다")
    func deniedAutomaticRequestIsNotRepeated() async {
        let probe = LocationProbe()
        let store = makeStore(authorization: .denied, location: .counting(probe))

        await store.send(.onAppear) {
            $0.didStartAutomatically = true
            $0.requestCount = 1
            $0.status = .authorizationDenied
        }
        #expect(store.state.authorizationMessage != nil)
        await store.send(.onDisappear)
        await store.send(.onAppear)
        #expect(probe.locationRequests.value == 0)
    }

    @Test("자동 요청이 위치 실패로 끝나도 재진입은 반복하지 않는다")
    func failedAutomaticRequestIsNotRepeated() async {
        let store = makeStore(location: .failing(.unavailable))

        await store.send(.onAppear) {
            $0.didStartAutomatically = true
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.failure) {
            $0.failed(.failure)
        }
        await store.send(.onDisappear)
        await store.send(.onAppear)
    }

    @Test("자동 요청 timeout 뒤에도 재진입은 반복하지 않는다")
    func timedOutAutomaticRequestIsNotRepeated() async {
        let clock = TestClock()
        let probe = LocationProbe()
        let store = makeStore(location: .hanging(probe), clock: clock)

        await store.send(.onAppear) {
            $0.didStartAutomatically = true
            $0.requestCount = 1
            $0.status = .locating
        }
        await clock.advance(by: MapFeatureLocationPolicy.compatibilityTimeout)
        await store.receive(\.locationResponse.failure) {
            $0.failed(.timeout)
        }
        await store.send(.onDisappear)
        await store.send(.onAppear)
        #expect(probe.locationRequests.value == 1)
        #expect(probe.cancellations.value == 1)
    }

    @Test("권한 미결정이면 응답을 기다린 뒤 위치를 조회한다")
    func undeterminedAuthorizationIsResolvedFirst() async {
        let store = makeStore(
            authorization: .notDetermined,
            requestAuthorization: { .authorized },
            location: .immediate(seoul)
        )

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .requestingAuthorization
        }
        await store.receive(\.authorizationResponse) {
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }
    }

    @Test("권한 요청의 거부 응답은 위치를 조회하지 않고 재시도도 권한을 다시 묻지 않는다")
    func deniedAuthorizationResponseDoesNotRequestLocation() async {
        let authorization = LockIsolated(MapFeatureAuthorization.notDetermined)
        let probe = LocationProbe()
        let store = makeStore(
            authorization: { authorization.value },
            requestAuthorization: {
                authorization.setValue(.denied)
                return .denied
            },
            location: .counting(probe)
        )

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .requestingAuthorization
        }
        await store.receive(\.authorizationResponse) {
            $0.status = .authorizationDenied
        }
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 2
        }
        #expect(probe.locationRequests.value == 0)
    }

    @Test("권한 요청 실패는 카메라를 유지하고 재시도 성공까지 처리한다")
    func authorizationFailurePreservesCameraAndRetrySucceeds() async {
        let authorization = LockIsolated(MapFeatureAuthorization.authorized)
        let authorizationResult = LockIsolated<Result<MapFeatureAuthorization, MapFeatureLocationError>>(
            .failure(.unavailable)
        )
        let coordinate = LockIsolated(seoul)
        let store = makeStore(
            authorization: { authorization.value },
            requestAuthorization: { try authorizationResult.value.get() },
            location: LocationBehavior { coordinate.value }
        )

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }

        authorization.setValue(.notDetermined)
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 2
            $0.status = .requestingAuthorization
        }
        await store.receive(\.locationResponse.failure) {
            $0.failed(.failure)
        }
        #expect(store.state.cameraCommand?.coordinate == seoul)

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
            $0.failureKind = nil
        }
        authorizationResult.setValue(.success(.authorized))
        coordinate.setValue(other)
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 3
            $0.status = .requestingAuthorization
        }
        await store.receive(\.authorizationResponse) {
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.other, commandID: 1)
        }
    }

    @Test("권한 거부 뒤 외부에서 허용되면 버튼 재시도로 위치를 조회한다")
    func retryAfterAuthorizationBecomesGrantedRequestsLocation() async {
        let authorization = LockIsolated(MapFeatureAuthorization.denied)
        let store = makeStore(
            authorization: { authorization.value },
            location: .immediate(seoul)
        )

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .authorizationDenied
        }
        authorization.setValue(.authorized)
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 2
            $0.status = .locating
        }
        #expect(store.state.authorizationMessage == nil)
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }
    }

    @Test("요청 중 입력은 무시한다")
    func concurrentInputWhileLoadingIsIgnored() async {
        let probe = LocationProbe()
        let store = makeStore(location: .hanging(probe))

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.send(.currentLocationButtonTapped)
        await store.send(.currentLocationButtonTapped)
        await store.send(.onDisappear) {
            $0.status = .idle
        }
        #expect(probe.locationRequests.value == 1)
    }

    @Test("같은 좌표에도 매번 새 카메라 명령을 만든다")
    func successPublishesFreshCommands() async {
        let store = makeStore(location: .immediate(seoul))

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 2
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 1)
        }
    }

    @Test("잘못된 좌표는 실패 alert를 만들고 카메라 명령을 만들지 않는다", arguments: [
        MapFeatureCoordinate(latitude: 91, longitude: 127),
        MapFeatureCoordinate(latitude: 0, longitude: 181),
        MapFeatureCoordinate(latitude: .nan, longitude: 0),
        MapFeatureCoordinate(latitude: 0, longitude: .infinity),
        MapFeatureCoordinate(latitude: -.infinity, longitude: 0),
    ])
    func invalidCoordinateFails(
        coordinate: MapFeatureCoordinate
    ) async {
        let store = makeStore(location: .immediate(coordinate))
        store.exhaustivity = .off

        await store.send(.currentLocationButtonTapped)
        await store.receive(\.locationResponse.success)

        #expect(store.state.status == .failed)
        #expect(store.state.failureKind == .failure)
        #expect(store.state.cameraCommand == nil)
        #expect(!store.state.isLoading)
    }

    @Test("유효 좌표의 경계값은 카메라 명령을 만든다", arguments: [
        MapFeatureCoordinate(latitude: -90, longitude: -180),
        MapFeatureCoordinate(latitude: 90, longitude: 180),
    ])
    func coordinateBoundariesAreAccepted(
        coordinate: MapFeatureCoordinate
    ) async {
        let store = makeStore(location: .immediate(coordinate))

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: coordinate, commandID: 0)
        }
    }

    @Test("위치 서비스 오류는 일반 실패로 정규화하고 기존 카메라 명령을 유지한다")
    func serviceFailurePreservesPreviousCameraCommand() async {
        let result = LockIsolated<Result<MapFeatureCoordinate, MapFeatureLocationError>>(.success(seoul))
        let store = makeStore(location: LocationBehavior { try result.value.get() })

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }
        result.setValue(.failure(.servicesDisabled))
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 2
            $0.status = .locating
        }
        await store.receive(\.locationResponse.failure) {
            $0.failed(.failure)
        }
        #expect(store.state.cameraCommand?.coordinate == seoul)
    }

    @Test("위치가 오지 않으면 timeout alert를 표시하고 요청을 취소하며 재시도를 허용한다")
    func timeoutEndsLoadingCancelsRequestAndAllowsRetry() async {
        let clock = TestClock()
        let probe = LocationProbe()
        let store = makeStore(location: .hanging(probe), clock: clock)

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await clock.advance(by: .seconds(9))
        await clock.advance(by: .seconds(1))
        await store.receive(\.locationResponse.failure) {
            $0.failed(.timeout)
        }
        #expect(probe.cancellations.value == 1)

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
            $0.failureKind = nil
        }
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 2
            $0.status = .locating
        }
        await store.send(.onDisappear) {
            $0.status = .idle
        }
    }

    @Test("화면 이탈은 위치 요청을 취소하고 늦은 결과를 막으며 재시도를 허용한다")
    func disappearCancelsRequestAndAllowsRetry() async {
        let probe = LocationProbe()
        let store = makeStore(location: .hanging(probe))

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.send(.onDisappear) {
            $0.status = .idle
        }
        #expect(probe.cancellations.value == 1)

        await store.send(.locationResponse(.success(seoul)))
        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 2
            $0.status = .locating
        }
        await store.send(.onDisappear) {
            $0.status = .idle
        }
    }

    @Test("권한 요청 중 화면 이탈은 사용자 안내 없이 요청을 취소한다")
    func disappearWhileAuthorizingProducesNoUserFacingError() async {
        let cancelled = LockIsolated(false)
        let store = makeStore(
            authorization: .notDetermined,
            requestAuthorization: {
                try await withTaskCancellationHandler {
                    try await Task.never()
                } onCancel: {
                    cancelled.setValue(true)
                }
            },
            location: .immediate(seoul)
        )

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .requestingAuthorization
        }
        await store.send(.onDisappear) {
            $0.status = .idle
        }
        await store.send(.authorizationResponse(.authorized))
        #expect(cancelled.value)
        #expect(store.state.alert == nil)
        #expect(store.state.authorizationMessage == nil)
    }

    @Test("실제 카메라 callback이 목표 좌표에 있어야 현재 위치 중심으로 표시하고 카메라를 보존한다")
    func cameraCallbackConfirmsCurrentLocation() async {
        let store = makeStore(location: .immediate(seoul))

        await store.send(.currentLocationButtonTapped) {
            $0.requestCount = 1
            $0.status = .locating
        }
        await store.receive(\.locationResponse.success) {
            $0.located(at: self.seoul, commandID: 0)
        }
        await store.send(.cameraChanged(other, span: 0.12)) {
            $0.cameraCoordinate = self.other
            $0.cameraSpan = 0.12
            $0.cameraIsCenteredOnCurrentLocation = false
        }
        await store.send(.cameraChanged(seoul, span: MapFeatureLocationPolicy.cameraSpan)) {
            $0.cameraCoordinate = self.seoul
            $0.cameraSpan = MapFeatureLocationPolicy.cameraSpan
            $0.cameraIsCenteredOnCurrentLocation = true
        }
    }

    @Test("현재 위치 요청 전의 카메라 이동은 중심 상태로 표시하지 않는다")
    func cameraChangeWithoutTargetIsNotCentered() async {
        let store = makeStore(location: .immediate(seoul))

        await store.send(.cameraChanged(seoul, span: 0.1)) {
            $0.cameraCoordinate = self.seoul
            $0.cameraSpan = 0.1
        }
    }

    /// 테스트용 의존성을 주입한 TestStore를 만듭니다.
    ///
    /// - Parameters:
    ///   - authorization: 현재 권한 상태를 반환하는 클로저입니다.
    ///   - requestAuthorization: 권한 요청 결과를 반환하는 클로저입니다.
    ///   - location: 위치 요청 동작입니다.
    ///   - clock: 제한 시간 계산에 사용할 시계입니다.
    /// - Returns: 초기 상태의 TestStore입니다.
    private func makeStore(
        authorization: @escaping @Sendable () -> MapFeatureAuthorization,
        requestAuthorization: @escaping @Sendable () async throws -> MapFeatureAuthorization = { .authorized },
        location: LocationBehavior,
        clock: some Clock<Duration> = TestClock()
    ) -> TestStoreOf<MapKitFeature> {
        TestStore(initialState: MapKitFeature.State()) {
            MapKitFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .incrementing
            $0.locationClient = LocationClient(
                authorizationStatus: authorization,
                requestAuthorization: requestAuthorization,
                requestLocation: location.request
            )
        }
    }

    /// 고정 권한 상태로 TestStore를 만듭니다.
    ///
    /// - Parameters:
    ///   - authorization: 테스트 동안 유지할 권한 상태입니다.
    ///   - requestAuthorization: 권한 요청 결과를 반환하는 클로저입니다.
    ///   - location: 위치 요청 동작입니다.
    ///   - clock: 제한 시간 계산에 사용할 시계입니다.
    /// - Returns: 초기 상태의 TestStore입니다.
    private func makeStore(
        authorization: MapFeatureAuthorization = .authorized,
        requestAuthorization: @escaping @Sendable () async throws -> MapFeatureAuthorization = { .authorized },
        location: LocationBehavior,
        clock: some Clock<Duration> = TestClock()
    ) -> TestStoreOf<MapKitFeature> {
        makeStore(
            authorization: { authorization },
            requestAuthorization: requestAuthorization,
            location: location,
            clock: clock
        )
    }
}

/// 위치 요청 횟수와 취소 횟수를 기록합니다.
private final class LocationProbe: Sendable {
    let locationRequests = LockIsolated(0)
    let cancellations = LockIsolated(0)
}

/// 테스트에서 사용할 위치 요청 동작입니다.
private struct LocationBehavior: Sendable {
    let request: @Sendable () async throws -> MapFeatureCoordinate

    /// 위치 요청 클로저로 동작을 만듭니다.
    ///
    /// - Parameter request: 위치를 반환하거나 오류를 던지는 클로저입니다.
    init(
        request: @escaping @Sendable () async throws -> MapFeatureCoordinate
    ) {
        self.request = request
    }

    /// 즉시 좌표를 반환하는 동작입니다.
    ///
    /// - Parameter coordinate: 반환할 좌표입니다.
    /// - Returns: 위치 요청 동작입니다.
    static func immediate(
        _ coordinate: MapFeatureCoordinate
    ) -> Self {
        Self { coordinate }
    }

    /// 즉시 오류를 던지는 동작입니다.
    ///
    /// - Parameter error: 던질 위치 오류입니다.
    /// - Returns: 위치 요청 동작입니다.
    static func failing(
        _ error: MapFeatureLocationError
    ) -> Self {
        Self { throw error }
    }

    /// 요청 횟수만 기록하고 즉시 좌표를 반환하는 동작입니다.
    ///
    /// - Parameter probe: 요청 횟수를 기록할 객체입니다.
    /// - Returns: 위치 요청 동작입니다.
    static func counting(
        _ probe: LocationProbe
    ) -> Self {
        Self {
            probe.locationRequests.withValue { $0 += 1 }
            return MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        }
    }

    /// 취소될 때까지 응답하지 않고 요청·취소 횟수를 기록하는 동작입니다.
    ///
    /// - Parameter probe: 요청과 취소 횟수를 기록할 객체입니다.
    /// - Returns: 위치 요청 동작입니다.
    static func hanging(
        _ probe: LocationProbe
    ) -> Self {
        Self {
            probe.locationRequests.withValue { $0 += 1 }
            return try await withTaskCancellationHandler {
                try await Task.never()
            } onCancel: {
                probe.cancellations.withValue { $0 += 1 }
            }
        }
    }
}

private extension MapKitFeature.State {
    /// 위치 조회 성공 뒤 기대하는 상태로 바꿉니다.
    ///
    /// - Parameters:
    ///   - coordinate: 카메라 명령의 목표 좌표입니다.
    ///   - commandID: `UUIDGenerator.incrementing`이 만든 순번입니다.
    mutating func located(
        at coordinate: MapFeatureCoordinate,
        commandID: Int
    ) {
        status = .located
        cameraCommand = MapFeatureCameraCommand(
            coordinate: coordinate,
            commandID: UUID(commandID)
        )
        currentLocationTarget = coordinate
        cameraCoordinate = coordinate
        cameraSpan = MapFeatureLocationPolicy.cameraSpan
        cameraIsCenteredOnCurrentLocation = true
    }

    /// 위치 조회 실패 뒤 기대하는 상태로 바꿉니다.
    ///
    /// - Parameter kind: 일반 실패 또는 제한 시간 초과입니다.
    mutating func failed(
        _ kind: FailureKind
    ) {
        status = .failed
        failureKind = kind
        alert = MapKitFeature.failureAlert(kind)
    }
}
