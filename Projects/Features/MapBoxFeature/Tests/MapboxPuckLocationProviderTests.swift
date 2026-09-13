import Foundation
import RxCocoa
import RxSwift
import Testing
@testable import MapBoxFeature

@MainActor
@Suite("Mapbox 위치 점과 현재 위치 이동 연결")
struct MapboxPuckLocationProviderTests {
    @Test("이미 표시된 대략적인 위치도 새 GPS 요청 없이 즉시 사용한다")
    func displayedLocationMovesImmediately() {
        // Given
        let sample = makeSample(accuracy: 2_000)
        let harness = PuckLocationHarness(latest: sample)

        // When
        harness.tap.onNext(())

        // Then
        #expect(harness.commands.map(\.coordinate) == [sample.coordinate])
        #expect(harness.states.last == .located)
        #expect(harness.authorization.locationRequestCount == 0)
        #expect(!harness.updates.hasObservers)
    }

    @Test("자동 조회 중 위치 점이 도착하면 한 번 이동하고 timeout을 취소한다")
    func arrivingPuckCompletesPendingRequest() async throws {
        // Given
        let harness = PuckLocationHarness(timeout: .milliseconds(30))
        let sample = makeSample()

        // When
        harness.appear.onNext(())
        harness.tap.onNext(())
        #expect(harness.updates.hasObservers)
        harness.updates.onNext(sample)
        harness.updates.onNext(makeSample())
        try await Task.sleep(for: .milliseconds(80))

        // Then
        #expect(harness.commands.map(\.coordinate) == [sample.coordinate])
        #expect(harness.states.last == .located)
        #expect(harness.alerts.isEmpty)
        #expect(!harness.updates.hasObservers)
        #expect(harness.authorization.locationRequestCount == 0)
    }

    @Test("이전 좌표와 잘못된 측정은 기다리고 새 위치만 사용한다")
    func staleAndInvalidLocationsDoNotMoveCamera() {
        // Given
        let stale = makeSample(timestamp: Date().addingTimeInterval(-60))
        let harness = PuckLocationHarness(latest: stale)

        // When
        harness.tap.onNext(())
        harness.updates.onNext(stale)
        harness.updates.onNext(makeSample(accuracy: -1))
        #expect(harness.commands.isEmpty)
        let fresh = makeSample()
        harness.updates.onNext(fresh)

        // Then
        #expect(harness.commands.map(\.coordinate) == [fresh.coordinate])
        #expect(harness.alerts.isEmpty)
    }

    @Test("화면을 나간 뒤 늦은 위치가 도착해도 이동하지 않는다")
    func disappearanceStopsObservingPuck() {
        // Given
        let harness = PuckLocationHarness()
        harness.tap.onNext(())

        // When
        harness.disappear.onNext(())
        harness.updates.onNext(makeSample())

        // Then
        #expect(!harness.updates.hasObservers)
        #expect(harness.commands.isEmpty)
        #expect(harness.alerts.isEmpty)
        #expect(harness.states.last == .idle)
    }

    @Test("위치 점 데이터가 남아 있어도 권한이 거부됐으면 이동하지 않는다")
    func cachedLocationDoesNotBypassPermission() {
        // Given
        let harness = PuckLocationHarness(latest: makeSample(), authorization: .denied)

        // When
        harness.tap.onNext(())

        // Then
        #expect(harness.states.last == .authorizationDenied)
        #expect(harness.commands.isEmpty)
        #expect(!harness.updates.hasObservers)
    }

    @Test("SDK도 위치를 주지 않으면 timeout으로 끝나며 다음 탭으로 재시도한다")
    func missingPuckTimesOutAndAllowsRetry() async throws {
        // Given
        let harness = PuckLocationHarness(timeout: .milliseconds(5))

        // When
        harness.tap.onNext(())
        try await Task.sleep(for: .milliseconds(30))
        #expect(harness.alerts == [.timeout])
        #expect(!harness.updates.hasObservers)
        harness.tap.onNext(())
        let sample = makeSample()
        harness.updates.onNext(sample)

        // Then
        #expect(harness.states.last == .located)
        #expect(harness.commands.map(\.coordinate) == [sample.coordinate])
    }

    /// 테스트에서 위치 시각과 정확도를 제어할 측정값을 만듭니다.
    ///
    /// - Parameters:
    ///   - timestamp: 측정 시각이며, 기본값은 현재 시각입니다.
    ///   - accuracy: 미터 단위 오차이며, nil은 SDK가 정확도를 제공하지 않은 경우입니다.
    /// - Returns: 같은 좌표에서 측정한 테스트 위치입니다.
    private func makeSample(
        timestamp: Date = Date(),
        accuracy: Double? = 50
    ) -> MapBoxLocationSample {
        MapBoxLocationSample(
            coordinate: MapBoxCoordinate(latitude: 37.5, longitude: 127),
            timestamp: timestamp,
            horizontalAccuracy: accuracy
        )
    }
}

@MainActor
private final class PuckLocationHarness {
    let appear = PublishSubject<Void>()
    let tap = PublishSubject<Void>()
    let disappear = PublishSubject<Void>()
    let updates = PublishSubject<MapBoxLocationSample>()
    let authorization: AuthorizationOnlyProvider
    private(set) var states: [MapBoxFeatureViewModel.State] = []
    private(set) var commands: [MapBoxCameraCommand] = []
    private(set) var alerts: [MapBoxAlert.Kind] = []
    private let viewModel: MapBoxFeatureViewModel
    private let disposeBag = DisposeBag()

    /// 지도 SDK의 위치 갱신을 직접 제어하는 테스트 화면을 만듭니다.
    ///
    /// - Parameters:
    ///   - latest: 이미 지도에 표시된 측정값이며, 없으면 nil입니다.
    ///   - authorization: 최초 권한 상태입니다.
    ///   - timeout: SDK 위치를 기다릴 최대 시간입니다.
    init(
        latest: MapBoxLocationSample? = nil,
        authorization: MapBoxAuthorization = .authorized,
        timeout: RxTimeInterval = .seconds(1)
    ) {
        self.authorization = AuthorizationOnlyProvider(status: authorization)
        let provider = MapboxPuckLocationProvider(
            authorizationProvider: self.authorization,
            latestSample: { latest },
            locationUpdates: updates.asObservable()
        )
        viewModel = MapBoxFeatureViewModel(provider: provider, timeout: timeout)
        let output = viewModel.transform(input: MapBoxFeatureViewModel.Input(
            viewDidAppear: appear.asObservable(),
            currentLocationTapped: tap.asObservable(),
            viewDidDisappear: disappear.asObservable()
        ))
        output.state.drive(onNext: { [weak self] in self?.states.append($0) })
            .disposed(by: disposeBag)
        output.cameraCommand.emit(onNext: { [weak self] in self?.commands.append($0) })
            .disposed(by: disposeBag)
        output.alert.emit(onNext: { [weak self] in self?.alerts.append($0.kind) })
            .disposed(by: disposeBag)
    }
}

@MainActor
private final class AuthorizationOnlyProvider: MapboxLocationProviding {
    let status: MapBoxAuthorization
    private(set) var locationRequestCount = 0

    /// 위치를 요청하지 않아야 하는 권한 전용 테스트 제공자를 만듭니다.
    ///
    /// - Parameter status: 반환할 권한 상태입니다.
    init(
        status: MapBoxAuthorization
    ) {
        self.status = status
    }

    func authorizationStatus() -> MapBoxAuthorization { status }
    func requestAuthorization() -> Single<MapBoxAuthorization> { .just(status) }
    func requestLocation() -> Single<MapBoxCoordinate> {
        locationRequestCount += 1
        return .never()
    }
    func cancel() {}
}
