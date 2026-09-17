import CoreLocation
import Foundation
import RxCocoa
import RxSwift
import Testing
@testable import MapBoxFeature

@MainActor
@Suite("Mapbox Input Output ViewModel")
struct MapBoxFeatureViewModelTests {
    @Test("초기 Output은 idle 상태만 전달한다")
    func initialOutput() {
        // Given
        let harness = ViewModelHarness(provider: RxLocationProvider())

        // When
        let states = harness.states

        // Then
        #expect(states == [.idle])
        #expect(harness.cameraCommands.isEmpty)
        #expect(harness.alertKinds.isEmpty)
    }

    @Test("현재 위치 버튼 입력은 위치를 조회하고 카메라 명령을 출력한다")
    func currentLocationInputPublishesCameraCommand() {
        // Given
        let provider = RxLocationProvider()
        let harness = ViewModelHarness(provider: provider)
        let coordinate = MapBoxCoordinate(latitude: 37.5, longitude: 127)

        // When
        harness.currentLocationTapped.onNext(())
        provider.succeed(coordinate)

        // Then
        #expect(harness.states == [.idle, .locating, .located])
        #expect(harness.cameraCommands.map(\.coordinate) == [coordinate])
        #expect(provider.locationRequestCount == 1)
    }

    @Test("최초 화면 등장 입력도 현재 위치를 요청한다")
    func viewDidAppearInputRequestsLocation() {
        // Given
        let provider = RxLocationProvider()
        let harness = ViewModelHarness(provider: provider)

        // When
        harness.viewDidAppear.onNext(())

        // Then
        #expect(harness.states == [.idle, .locating])
        #expect(provider.locationRequestCount == 1)
    }

    @Test("미결정 권한은 권한 요청 후 위치 조회로 이어진다")
    func undeterminedAuthorizationContinuesToLocation() {
        // Given
        let provider = RxLocationProvider(authorization: .notDetermined)
        let harness = ViewModelHarness(provider: provider)

        // When
        harness.currentLocationTapped.onNext(())
        provider.resolveAuthorization(.authorized)

        // Then
        #expect(harness.states == [.idle, .requestingAuthorization, .locating])
        #expect(provider.authorizationRequestCount == 1)
        #expect(provider.locationRequestCount == 1)
    }

    @Test("거부된 권한은 위치를 조회하지 않고 거부 상태를 출력한다")
    func deniedAuthorizationDoesNotRequestLocation() {
        // Given
        let provider = RxLocationProvider(authorization: .denied)
        let harness = ViewModelHarness(provider: provider)

        // When
        harness.currentLocationTapped.onNext(())

        // Then
        #expect(harness.states == [.idle, .authorizationDenied])
        #expect(provider.locationRequestCount == 0)
    }

    @Test("위치 실패는 실패 상태와 일회성 알림을 출력한다")
    func failurePublishesAlertSignal() {
        // Given
        let provider = RxLocationProvider()
        let harness = ViewModelHarness(provider: provider)

        // When
        harness.currentLocationTapped.onNext(())
        provider.fail(MapBoxLocationError.unavailable)

        // Then
        #expect(harness.states == [.idle, .locating, .failed])
        #expect(harness.alertKinds == [.failure])
    }

    @Test("잘못된 좌표는 카메라 명령 없이 실패를 출력한다", arguments: [
        MapBoxCoordinate(latitude: 91, longitude: 127),
        MapBoxCoordinate(latitude: 0, longitude: 181),
        MapBoxCoordinate(latitude: .nan, longitude: 0),
        MapBoxCoordinate(latitude: 0, longitude: .infinity),
    ])
    func invalidCoordinateDoesNotMoveCamera(
        coordinate: MapBoxCoordinate
    ) {
        // Given
        let provider = RxLocationProvider()
        let harness = ViewModelHarness(provider: provider)

        // When
        harness.currentLocationTapped.onNext(())
        provider.succeed(coordinate)

        // Then
        #expect(harness.states == [.idle, .locating, .failed])
        #expect(harness.cameraCommands.isEmpty)
        #expect(harness.alertKinds == [.failure])
    }

    @Test("요청 중 연속 입력은 flatMapFirst에 의해 무시된다")
    func concurrentInputsKeepSingleRequest() {
        // Given
        let provider = RxLocationProvider()
        let harness = ViewModelHarness(provider: provider)

        // When
        harness.viewDidAppear.onNext(())
        harness.currentLocationTapped.onNext(())
        harness.currentLocationTapped.onNext(())

        // Then
        #expect(provider.locationRequestCount == 1)
        #expect(harness.states == [.idle, .locating])
    }

    @Test("화면 이탈 입력은 진행 중인 요청을 취소하고 idle을 출력한다")
    func disappearanceCancelsRequest() {
        // Given
        let provider = RxLocationProvider()
        let harness = ViewModelHarness(provider: provider)

        // When
        harness.currentLocationTapped.onNext(())
        harness.viewDidDisappear.onNext(())

        // Then
        #expect(provider.wasDisposed)
        #expect(provider.cancelCount == 1)
        #expect(harness.states == [.idle, .locating, .idle])
    }

    @Test("위치가 오지 않으면 timeout 알림을 출력한다")
    func timeoutPublishesAlert() async throws {
        // Given
        let provider = RxLocationProvider()
        let harness = ViewModelHarness(
            provider: provider,
            timeout: .milliseconds(1)
        )

        // When
        harness.currentLocationTapped.onNext(())
        try await Task.sleep(for: .milliseconds(30))

        // Then
        #expect(harness.states == [.idle, .locating, .failed])
        #expect(harness.alertKinds == [.timeout])
        #expect(provider.wasDisposed)
    }

    @Test("Core Location 권한 상태를 Feature 권한으로 변환한다")
    func coreLocationAuthorizationMapping() {
        #expect(CoreMapboxLocationProvider.authorization(from: .notDetermined) == .notDetermined)
        #expect(CoreMapboxLocationProvider.authorization(from: .authorizedWhenInUse) == .authorized)
        #expect(CoreMapboxLocationProvider.authorization(from: .authorizedAlways) == .authorized)
        #expect(CoreMapboxLocationProvider.authorization(from: .denied) == .denied)
        #expect(CoreMapboxLocationProvider.authorization(from: .restricted) == .denied)
    }
}

@MainActor
@Suite("MapBoxSession")
struct MapBoxSessionTests {
    @Test("자동 요청은 앱 수명에서 한 번만 실행한다")
    func automaticRequestRunsOnce() {
        // Given
        let session = MapBoxSession()

        // When
        let firstRequest = session.registerAutomaticRequestIfNeeded()
        let secondRequest = session.registerAutomaticRequestIfNeeded()

        // Then
        #expect(firstRequest)
        #expect(!secondRequest)
        #expect(session.requestCount == 1)
    }

    @Test("수동 요청은 입력마다 횟수를 기록한다")
    func manualRequestRecordsEveryInput() {
        // Given
        let session = MapBoxSession()

        // When
        session.registerManualRequest()
        session.registerManualRequest()

        // Then
        #expect(session.requestCount == 2)
    }

    @Test("실제 카메라가 목표 좌표에 도달하면 현재 위치 중심으로 기록한다")
    func cameraCallbackConfirmsCurrentLocation() {
        // Given
        let session = MapBoxSession()
        let target = MapBoxCoordinate(latitude: 37.5, longitude: 127)

        // When
        session.expectCurrentLocationCamera(target)
        session.recordCamera(
            coordinate: target,
            zoom: MapBoxFeatureLocationPolicy.cameraZoom
        )

        // Then
        #expect(session.cameraIsCenteredOnCurrentLocation)
        #expect(session.cameraCoordinate == target)
        #expect(session.cameraZoom == MapBoxFeatureLocationPolicy.cameraZoom)
    }
}

@MainActor
private final class ViewModelHarness {
    let viewDidAppear = PublishSubject<Void>()
    let currentLocationTapped = PublishSubject<Void>()
    let viewDidDisappear = PublishSubject<Void>()
    private(set) var states: [MapBoxFeatureViewModel.State] = []
    private(set) var cameraCommands: [MapBoxCameraCommand] = []
    private(set) var alertKinds: [MapBoxAlert.Kind] = []
    private let viewModel: MapBoxFeatureViewModel
    private let disposeBag = DisposeBag()

    /// 입력 Subject를 ViewModel에 연결하고 모든 Output을 기록합니다.
    ///
    /// - Parameters:
    ///   - provider: 테스트가 직접 제어할 위치 제공자입니다.
    ///   - timeout: 테스트에서 사용할 위치 조회 제한 시간입니다.
    init(
        provider: RxLocationProvider,
        timeout: RxTimeInterval = MapBoxFeatureLocationPolicy.compatibilityTimeout
    ) {
        viewModel = MapBoxFeatureViewModel(
            provider: provider,
            timeout: timeout
        )
        let output = viewModel.transform(
            input: MapBoxFeatureViewModel.Input(
                viewDidAppear: viewDidAppear.asObservable(),
                currentLocationTapped: currentLocationTapped.asObservable(),
                viewDidDisappear: viewDidDisappear.asObservable()
            ),
            disposeBag: disposeBag
        )
        output.state
            .drive(onNext: { [weak self] state in
                self?.states.append(state)
            })
            .disposed(by: disposeBag)
        output.cameraCommand
            .emit(onNext: { [weak self] command in
                self?.cameraCommands.append(command)
            })
            .disposed(by: disposeBag)
        output.alert
            .emit(onNext: { [weak self] alert in
                self?.alertKinds.append(alert.kind)
            })
            .disposed(by: disposeBag)
    }
}

private final class RxLocationProvider: MapboxLocationProviding {
    var authorization: MapBoxAuthorization
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0
    private(set) var cancelCount = 0
    private(set) var wasDisposed = false
    private var authorizationObserver: ((SingleEvent<MapBoxAuthorization>) -> Void)?
    private var locationObserver: ((SingleEvent<MapBoxCoordinate>) -> Void)?

    /// 초기 권한 상태로 테스트 제공자를 만듭니다.
    ///
    /// - Parameter authorization: 최초 권한 확인에서 반환할 상태입니다.
    init(
        authorization: MapBoxAuthorization = .authorized
    ) {
        self.authorization = authorization
    }

    func authorizationStatus() -> MapBoxAuthorization {
        authorization
    }

    func requestAuthorization() -> Single<MapBoxAuthorization> {
        authorizationRequestCount += 1
        return Single.create { [weak self] observer in
            self?.authorizationObserver = observer
            return Disposables.create { [weak self] in
                self?.authorizationObserver = nil
            }
        }
    }

    func requestLocation() -> Single<MapBoxCoordinate> {
        locationRequestCount += 1
        wasDisposed = false
        return Single.create { [weak self] observer in
            self?.locationObserver = observer
            return Disposables.create { [weak self] in
                self?.wasDisposed = true
                self?.locationObserver = nil
            }
        }
    }

    func cancel() {
        cancelCount += 1
        authorizationObserver = nil
        locationObserver = nil
    }

    /// 권한 요청을 지정한 상태로 끝냅니다.
    ///
    /// - Parameter authorization: 권한 요청에서 반환할 상태입니다.
    func resolveAuthorization(
        _ authorization: MapBoxAuthorization
    ) {
        self.authorization = authorization
        authorizationObserver?(.success(authorization))
        authorizationObserver = nil
    }

    /// 위치 요청을 성공시킵니다.
    ///
    /// - Parameter coordinate: 반환할 좌표입니다.
    func succeed(
        _ coordinate: MapBoxCoordinate
    ) {
        locationObserver?(.success(coordinate))
        locationObserver = nil
    }

    /// 위치 요청을 실패시킵니다.
    ///
    /// - Parameter error: 반환할 오류입니다.
    func fail(
        _ error: Error
    ) {
        locationObserver?(.failure(error))
        locationObserver = nil
    }
}
