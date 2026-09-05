import CoreLocation
import Foundation
import RxSwift
import Testing
@testable import MapBoxFeature

@MainActor
@Suite("Mapbox 현재 위치 ViewModel")
struct MapBoxFeatureViewModelTests {
    @Test("현재 위치 이동은 기존 Mapbox 화면의 확대 수준을 보존한다")
    func cameraPolicyPreservesExistingMapPresentation() {
        #expect(MapBoxFeatureLocationPolicy.cameraZoom == 10.5)
        #expect(MapBoxFeatureLocationPolicy.compatibilityTimeout == .seconds(10))
    }

    @Test("실제 Mapbox 카메라 callback이 목표 좌표에 도달해야 현재 위치 중심으로 표시한다")
    func cameraCallbackConfirmsCurrentLocationAndPersistsManualCamera() {
        let session = MapBoxSession()
        let target = MapBoxCoordinate(latitude: 37.5, longitude: 127)
        session.expectCurrentLocationCamera(target)

        session.recordCamera(
            coordinate: MapBoxCoordinate(latitude: 37.6, longitude: 127.1),
            zoom: 12
        )
        #expect(!session.cameraIsCenteredOnCurrentLocation)
        #expect(session.cameraCoordinate == MapBoxCoordinate(latitude: 37.6, longitude: 127.1))
        #expect(session.cameraZoom == 12)

        session.recordCamera(coordinate: target, zoom: MapBoxFeatureLocationPolicy.cameraZoom)
        #expect(session.cameraIsCenteredOnCurrentLocation)
    }

    @Test("이미 실제 카메라가 목표 좌표에 있으면 같은 위치 명령도 중심 상태를 유지한다")
    func repeatedCameraCommandKeepsConfirmedCenterState() {
        let session = MapBoxSession()
        let target = MapBoxCoordinate(latitude: 37.5, longitude: 127)
        session.recordCamera(coordinate: target, zoom: MapBoxFeatureLocationPolicy.cameraZoom)

        session.expectCurrentLocationCamera(target)

        #expect(session.cameraIsCenteredOnCurrentLocation)
    }

    @Test("초기 상태는 요청과 사용자 안내가 없는 재시도 가능 상태다")
    func initialStateIsRetryableAndHasNoOutput() {
        let viewModel = MapBoxFeatureViewModel(provider: RxLocationProvider())

        #expect(viewModel.state == .idle)
        #expect(!viewModel.isLoading)
        #expect(viewModel.authorizationMessage == nil)
        #expect(viewModel.alert == nil)
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.requestCount == 0)
    }

    @Test("화면 활성화 연결은 같은 세션에서 자동 요청을 한 번만 시작한다")
    func automaticRequestStartsOncePerSession() {
        let session = MapBoxSession()
        let firstProvider = RxLocationProvider()
        let recreatedProvider = RxLocationProvider()
        let firstViewModel = MapBoxFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapBoxFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        #expect(firstProvider.locationRequestCount == 1)
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)

        let independentSession = MapBoxSession()
        #expect(independentSession.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        #expect(recreatedProvider.locationRequestCount == 1)
        firstViewModel.cancel()
        recreatedViewModel.cancel()
    }

    @Test("수동 요청은 같은 세션의 최초 자동 요청 권리를 소모하지 않는다")
    func manualRequestDoesNotConsumeAutomaticRequest() {
        let session = MapBoxSession()
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)

        session.startManually(viewModel.moveToCurrentLocation)
        provider.succeed(MapBoxCoordinate(latitude: 37.5, longitude: 127))

        #expect(session.startAutomatically(viewModel.moveToCurrentLocation))
        #expect(session.requestCount == 2)
        #expect(viewModel.requestCount == 2)
        #expect(provider.locationRequestCount == 2)

        #expect(!session.startAutomatically(viewModel.moveToCurrentLocation))
        #expect(provider.locationRequestCount == 2)
        viewModel.cancel()
    }

    @Test("자동 요청이 권한 거부로 끝나도 같은 세션의 재진입은 반복하지 않는다")
    func deniedAutomaticRequestIsNotRepeatedAfterReentry() {
        let session = MapBoxSession()
        let firstProvider = RxLocationProvider(authorization: .denied)
        let recreatedProvider = RxLocationProvider()
        let firstViewModel = MapBoxFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapBoxFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        #expect(firstViewModel.state == .authorizationDenied)

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        #expect(firstProvider.locationRequestCount == 0)
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("자동 요청이 위치 실패로 끝나도 같은 세션의 재진입은 반복하지 않는다")
    func failedAutomaticRequestIsNotRepeatedAfterReentry() {
        let session = MapBoxSession()
        let firstProvider = RxLocationProvider()
        let recreatedProvider = RxLocationProvider()
        let firstViewModel = MapBoxFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapBoxFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        firstProvider.fail(MapBoxLocationError.unavailable)
        #expect(firstViewModel.state == .failed)

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        #expect(firstProvider.locationRequestCount == 1)
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("자동 요청 성공 뒤 같은 세션의 재진입은 반복하지 않는다")
    func successfulAutomaticRequestIsNotRepeatedAfterReentry() {
        let session = MapBoxSession()
        let firstProvider = RxLocationProvider()
        let recreatedProvider = RxLocationProvider()
        let firstViewModel = MapBoxFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapBoxFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        firstProvider.succeed(MapBoxCoordinate(latitude: 37.5, longitude: 127))
        #expect(firstViewModel.cameraCommand != nil)

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("자동 요청 timeout 뒤 같은 세션의 재진입은 반복하지 않는다")
    func timedOutAutomaticRequestIsNotRepeatedAfterReentry() async throws {
        let session = MapBoxSession()
        let firstProvider = RxLocationProvider()
        let recreatedProvider = RxLocationProvider()
        let firstViewModel = MapBoxFeatureViewModel(
            provider: firstProvider,
            timeout: .milliseconds(1)
        )
        let recreatedViewModel = MapBoxFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        try await Task.sleep(for: .milliseconds(30))
        #expect(firstViewModel.alert?.kind == .timeout)

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("허용된 권한은 권한 요청 없이 위치를 조회한다")
    func authorizedStatusSkipsAuthorizationRequest() {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        #expect(provider.authorizationRequestCount == 0)
        #expect(provider.locationRequestCount == 1)
        #expect(viewModel.requestCount == 1)
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("권한 미결정이면 응답을 기다린 뒤 위치를 조회한다")
    func undeterminedAuthorizationIsResolvedFirst() {
        let provider = RxLocationProvider(authorization: .notDetermined)
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        #expect(viewModel.state == .requestingAuthorization)
        #expect(provider.authorizationRequestCount == 1)
        #expect(provider.locationRequestCount == 0)
        provider.resolveAuthorization(.authorized)
        #expect(provider.locationRequestCount == 1)
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("권한 거부는 위치를 조회하지 않고 인라인 메시지를 만든다")
    func deniedDoesNotRequestLocation() {
        let provider = RxLocationProvider(authorization: .denied)
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        #expect(provider.authorizationRequestCount == 0)
        #expect(provider.locationRequestCount == 0)
        #expect(viewModel.state == .authorizationDenied)
        #expect(viewModel.authorizationMessage != nil)
        #expect(!viewModel.isLoading)
    }

    @Test("권한 요청의 거부 응답도 위치를 조회하지 않는다")
    func deniedAuthorizationResponseDoesNotRequestLocation() {
        let provider = RxLocationProvider(authorization: .notDetermined)
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        provider.resolveAuthorization(.denied)
        #expect(viewModel.state == .authorizationDenied)
        #expect(provider.locationRequestCount == 0)

        viewModel.moveToCurrentLocation()
        #expect(viewModel.state == .authorizationDenied)
        #expect(provider.authorizationRequestCount == 1)
        #expect(provider.locationRequestCount == 0)
    }

    @Test("권한 요청 실패는 카메라를 유지하고 재시도 성공까지 처리한다")
    func authorizationFailurePreservesCameraAndRetrySucceeds() {
        let provider = RxLocationProvider(authorization: .notDetermined)
        let viewModel = MapBoxFeatureViewModel(provider: provider)

        provider.authorization = .authorized
        viewModel.moveToCurrentLocation()
        let previousCoordinate = MapBoxCoordinate(latitude: 37.5, longitude: 127)
        provider.succeed(previousCoordinate)
        let previousCommand = viewModel.cameraCommand

        provider.authorization = .notDetermined
        viewModel.moveToCurrentLocation()
        #expect(provider.authorizationRequestCount == 1)

        provider.failAuthorization(MapBoxLocationError.unavailable)

        #expect(viewModel.state == .failed)
        #expect(viewModel.alert?.kind == .failure)
        #expect(!viewModel.isLoading)
        #expect(provider.locationRequestCount == 1)
        #expect(viewModel.cameraCommand == previousCommand)

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        #expect(provider.authorizationRequestCount == 2)
        #expect(viewModel.state == .requestingAuthorization)
        #expect(viewModel.alert == nil)

        provider.resolveAuthorization(.authorized)
        #expect(provider.locationRequestCount == 2)
        let retryCoordinate = MapBoxCoordinate(latitude: 37.6, longitude: 127.1)
        provider.succeed(retryCoordinate)
        #expect(viewModel.state == .located)
        #expect(viewModel.cameraCommand?.coordinate == retryCoordinate)
        #expect(viewModel.cameraCommand?.commandID != previousCommand?.commandID)
    }

    @Test("연속 권한 요청 실패는 매번 새 alert를 만들고 input stream을 유지한다")
    func repeatedAuthorizationFailurePublishesFreshAlerts() {
        let provider = RxLocationProvider(authorization: .notDetermined)
        let viewModel = MapBoxFeatureViewModel(provider: provider)

        viewModel.moveToCurrentLocation()
        provider.failAuthorization(MapBoxLocationError.unavailable)
        let firstAlertID = viewModel.alert?.id

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        provider.failAuthorization(MapBoxLocationError.unavailable)

        #expect(provider.authorizationRequestCount == 2)
        #expect(viewModel.state == .failed)
        #expect(viewModel.alert?.kind == .failure)
        #expect(viewModel.alert?.id != firstAlertID)
        #expect(!viewModel.isLoading)
    }

    @Test("권한 거부 뒤 외부에서 허용되면 버튼 재시도로 위치를 조회한다")
    func retryAfterAuthorizationBecomesGrantedRequestsLocation() {
        let provider = RxLocationProvider(authorization: .denied)
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        #expect(viewModel.state == .authorizationDenied)

        provider.authorization = .authorized
        viewModel.moveToCurrentLocation()

        #expect(provider.authorizationRequestCount == 0)
        #expect(provider.locationRequestCount == 1)
        #expect(viewModel.authorizationMessage == nil)
        #expect(viewModel.state == .locating)
        let coordinate = MapBoxCoordinate(latitude: 37.5, longitude: 127)
        provider.succeed(coordinate)
        #expect(viewModel.state == .located)
        #expect(viewModel.cameraCommand?.coordinate == coordinate)
    }

    @Test("Core Location 권한 상태를 빠짐없이 Feature 권한으로 변환한다")
    func coreLocationAuthorizationMappingCoversEveryKnownStatus() {
        #expect(CoreMapboxLocationProvider.authorization(from: .notDetermined) == .notDetermined)
        #expect(CoreMapboxLocationProvider.authorization(from: .authorizedWhenInUse) == .authorized)
        #expect(CoreMapboxLocationProvider.authorization(from: .authorizedAlways) == .authorized)
        #expect(CoreMapboxLocationProvider.authorization(from: .denied) == .denied)
        #expect(CoreMapboxLocationProvider.authorization(from: .restricted) == .denied)
    }

    @Test("권한 응답 대기 중 연속 입력도 flatMapFirst가 하나만 유지한다")
    func concurrentInputWhileAuthorizingIsIgnored() {
        let provider = RxLocationProvider(authorization: .notDetermined)
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        viewModel.moveToCurrentLocation()
        viewModel.moveToCurrentLocation()
        #expect(provider.authorizationRequestCount == 1)
        #expect(provider.locationRequestCount == 0)
        #expect(viewModel.state == .requestingAuthorization)
        viewModel.cancel()
    }

    @Test("flatMapFirst는 요청 중 입력을 무시하고 같은 좌표에도 새 명령을 만든다")
    func successPublishesFreshCommandsAndIgnoresConcurrentInput() {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        let coordinate = MapBoxCoordinate(latitude: 37.5, longitude: 127)
        viewModel.moveToCurrentLocation()
        viewModel.moveToCurrentLocation()
        #expect(provider.locationRequestCount == 1)
        provider.succeed(coordinate)
        let firstCommand = viewModel.cameraCommand
        #expect(firstCommand?.coordinate == coordinate)
        viewModel.moveToCurrentLocation()
        provider.succeed(coordinate)
        #expect(provider.locationRequestCount == 2)
        #expect(viewModel.cameraCommand?.coordinate == coordinate)
        #expect(viewModel.cameraCommand?.commandID != firstCommand?.commandID)
        #expect(viewModel.requestCount == 2)
    }

    @Test("잘못된 좌표는 실패 alert를 만들고 카메라를 유지한다")
    func invalidCoordinateFailsWithoutCameraCommand() {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        provider.succeed(MapBoxCoordinate(latitude: 91, longitude: 127))
        #expect(viewModel.state == .failed)
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.alert?.kind == .failure)
        #expect(!viewModel.isLoading)
    }

    @Test("경도 범위 초과와 유한하지 않은 좌표를 모두 거부한다", arguments: [
        MapBoxCoordinate(latitude: 0, longitude: 181),
        MapBoxCoordinate(latitude: .nan, longitude: 0),
        MapBoxCoordinate(latitude: 0, longitude: .infinity),
        MapBoxCoordinate(latitude: -.infinity, longitude: 0),
    ])
    func nonFiniteAndOutOfRangeCoordinatesFail(
        coordinate: MapBoxCoordinate
    ) {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        provider.succeed(coordinate)
        #expect(viewModel.state == .failed)
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.alert?.kind == .failure)
    }

    @Test("유효 좌표의 경계값은 카메라 명령을 만든다")
    func coordinateBoundariesAreAccepted() {
        let coordinates = [
            MapBoxCoordinate(latitude: -90, longitude: -180),
            MapBoxCoordinate(latitude: 90, longitude: 180),
        ]
        for coordinate in coordinates {
            let provider = RxLocationProvider()
            let viewModel = MapBoxFeatureViewModel(provider: provider)
            viewModel.moveToCurrentLocation()
            provider.succeed(coordinate)
            #expect(viewModel.state == .located)
            #expect(viewModel.cameraCommand?.coordinate == coordinate)
            #expect(viewModel.alert == nil)
        }
    }

    @Test("위치 서비스 오류는 일반 실패로 정규화하고 기존 카메라 명령을 유지한다")
    func serviceFailurePreservesPreviousCameraCommand() {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        let coordinate = MapBoxCoordinate(latitude: 37.5, longitude: 127)
        viewModel.moveToCurrentLocation()
        provider.succeed(coordinate)
        let previousCommand = viewModel.cameraCommand

        viewModel.moveToCurrentLocation()
        provider.fail(MapBoxLocationError.servicesDisabled)

        #expect(viewModel.state == .failed)
        #expect(viewModel.cameraCommand == previousCommand)
        #expect(viewModel.alert?.kind == .failure)
        #expect(!viewModel.isLoading)
    }

    @Test("일시적 위치 부재 뒤 버튼 재시도는 새 위치로 이동한다")
    func retryAfterTemporaryLocationUnavailabilitySucceeds() {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)

        viewModel.moveToCurrentLocation()
        provider.fail(MapBoxLocationError.unavailable)

        #expect(viewModel.state == .failed)
        #expect(viewModel.alert?.kind == .failure)
        #expect(viewModel.cameraCommand == nil)
        #expect(!viewModel.isLoading)

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        let coordinate = MapBoxCoordinate(latitude: 37.6, longitude: 127.1)
        provider.succeed(coordinate)

        #expect(viewModel.state == .located)
        #expect(viewModel.alert == nil)
        #expect(viewModel.cameraCommand?.coordinate == coordinate)
        #expect(viewModel.cameraCommand?.commandID != nil)
        #expect(viewModel.requestCount == 2)
        #expect(provider.locationRequestCount == 2)
    }

    @Test("연속 위치 실패는 새 alert를 만들고 재시도를 허용한다")
    func repeatedFailurePublishesFreshAlertAndAllowsRetry() {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        provider.fail(MapBoxLocationError.unavailable)
        let firstAlertID = viewModel.alert?.id
        #expect(viewModel.state == .failed)
        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        provider.fail(MapBoxLocationError.unavailable)
        #expect(provider.locationRequestCount == 2)
        #expect(viewModel.alert?.kind == .failure)
        #expect(viewModel.alert?.id != firstAlertID)
        #expect(!viewModel.isLoading)
    }

    @Test("연속 timeout은 매번 새 alert를 만들고 재시도를 허용한다")
    func repeatedTimeoutPublishesFreshAlertAndAllowsRetry() async throws {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(
            provider: provider,
            timeout: .milliseconds(1)
        )

        viewModel.moveToCurrentLocation()
        try await Task.sleep(for: .milliseconds(30))
        let firstAlertID = viewModel.alert?.id
        #expect(viewModel.alert?.kind == .timeout)

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        try await Task.sleep(for: .milliseconds(30))

        #expect(provider.locationRequestCount == 2)
        #expect(viewModel.state == .failed)
        #expect(viewModel.alert?.kind == .timeout)
        #expect(viewModel.alert?.id != firstAlertID)
        #expect(!viewModel.isLoading)
        #expect(viewModel.cameraCommand == nil)
    }

    @Test("위치가 오지 않으면 timeout alert를 표시하고 요청을 dispose한다")
    func timeoutEndsLoadingAndDisposesRequest() async throws {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider, timeout: .milliseconds(1))
        let coordinate = MapBoxCoordinate(latitude: 37.5, longitude: 127)
        viewModel.moveToCurrentLocation()
        provider.succeed(coordinate)
        let previousCommand = viewModel.cameraCommand

        viewModel.moveToCurrentLocation()
        try await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.state == .failed)
        #expect(viewModel.alert?.kind == .timeout)
        #expect(!viewModel.isLoading)
        #expect(provider.wasDisposed)
        #expect(viewModel.cameraCommand == previousCommand)

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        #expect(provider.locationRequestCount == 3)
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("dispose 뒤 늦은 결과를 막고 재시도를 허용한다")
    func disposeBlocksLateResultAndAllowsRetry() {
        let provider = RxLocationProvider()
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        let lateObserver = provider.currentLocationObserver
        viewModel.cancel()
        lateObserver?(.success(MapBoxCoordinate(latitude: 1, longitude: 1)))
        #expect(provider.wasDisposed)
        #expect(provider.cancelCount == 1)
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.state == .idle)
        #expect(viewModel.alert == nil)
        viewModel.moveToCurrentLocation()
        #expect(provider.locationRequestCount == 2)
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("권한 요청 중 cancel은 구독을 dispose하고 UI 이벤트를 만들지 않는다")
    func cancellationWhileAuthorizingProducesNoUserFacingError() {
        let provider = RxLocationProvider(authorization: .notDetermined)
        let viewModel = MapBoxFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        let lateObserver = provider.currentAuthorizationObserver
        viewModel.cancel()
        lateObserver?(.success(.authorized))
        #expect(provider.authorizationWasDisposed)
        #expect(provider.cancelCount == 1)
        #expect(provider.locationRequestCount == 0)
        #expect(viewModel.state == .idle)
        #expect(viewModel.authorizationMessage == nil)
        #expect(viewModel.alert == nil)
        #expect(viewModel.cameraCommand == nil)
    }

    @Test("ViewModel 수명 종료는 실행 중인 위치 subscription을 dispose한다")
    func deinitializationDisposesInFlightLocationRequest() {
        let provider = RxLocationProvider()
        var viewModel: MapBoxFeatureViewModel? = MapBoxFeatureViewModel(provider: provider)
        weak var weakViewModel = viewModel
        viewModel?.moveToCurrentLocation()
        let lateObserver = provider.currentLocationObserver

        viewModel = nil
        lateObserver?(.success(MapBoxCoordinate(latitude: 37.5, longitude: 127)))

        #expect(weakViewModel == nil)
        #expect(provider.wasDisposed)
    }
}

@MainActor
private final class RxLocationProvider: MapboxLocationProviding {
    var authorization: MapBoxAuthorization
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0
    private(set) var cancelCount = 0
    private(set) var wasDisposed = false
    private(set) var authorizationWasDisposed = false
    private var authorizationObserver: ((SingleEvent<MapBoxAuthorization>) -> Void)?
    private var locationObserver: ((SingleEvent<MapBoxCoordinate>) -> Void)?
    var currentAuthorizationObserver: ((SingleEvent<MapBoxAuthorization>) -> Void)? { authorizationObserver }
    var currentLocationObserver: ((SingleEvent<MapBoxCoordinate>) -> Void)? { locationObserver }

    /// 초기 권한 상태로 테스트 제공자를 만듭니다.
    /// - Parameter authorization: 최초 권한 확인에서 반환할 상태입니다.
    init(
        authorization: MapBoxAuthorization = .authorized
    ) {
        self.authorization = authorization
    }

    func authorizationStatus() -> MapBoxAuthorization { authorization }

    func requestAuthorization() -> Single<MapBoxAuthorization> {
        authorizationRequestCount += 1
        authorizationWasDisposed = false
        return Single.create { [weak self] observer in
            self?.authorizationObserver = observer
            return Disposables.create { [weak self] in
                self?.authorizationWasDisposed = true
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
    /// - Parameter authorization: 권한 요청에서 반환할 상태입니다.
    func resolveAuthorization(
        _ authorization: MapBoxAuthorization
    ) {
        self.authorization = authorization
        authorizationObserver?(.success(authorization))
        authorizationObserver = nil
    }

    /// 권한 요청을 오류로 끝냅니다.
    /// - Parameter error: 권한 요청에서 반환할 오류입니다.
    func failAuthorization(
        _ error: Error
    ) {
        authorizationObserver?(.failure(error))
        authorizationObserver = nil
    }

    /// 위치 요청을 성공시킵니다.
    /// - Parameter coordinate: 반환할 좌표입니다.
    func succeed(
        _ coordinate: MapBoxCoordinate
    ) {
        locationObserver?(.success(coordinate))
        locationObserver = nil
    }

    /// 위치 요청을 실패시킵니다.
    /// - Parameter error: 반환할 오류입니다.
    func fail(
        _ error: Error
    ) {
        locationObserver?(.failure(error))
        locationObserver = nil
    }
}
