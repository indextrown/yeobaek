import CoreLocation
import Foundation
import Testing
@testable import MapFeature

@MainActor
@Suite("MapKit 현재 위치 ViewModel")
struct MapFeatureViewModelTests {
    @Test("현재 위치 이동은 기존 MapKit 화면의 확대 수준을 보존한다")
    func cameraPolicyPreservesExistingMapPresentation() {
        #expect(MapFeatureLocationPolicy.cameraSpan == 0.18)
        #expect(MapFeatureLocationPolicy.compatibilityTimeoutNanoseconds == 10_000_000_000)
    }

    @Test("실제 MapKit 카메라 callback이 목표 좌표에 도달해야 현재 위치 중심으로 표시한다")
    func cameraCallbackConfirmsCurrentLocationAndPersistsManualCamera() {
        let session = MapFeatureSession()
        let target = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        session.expectCurrentLocationCamera(target)

        session.recordCamera(
            coordinate: MapFeatureCoordinate(latitude: 37.6, longitude: 127.1),
            span: 0.12
        )
        #expect(!session.cameraIsCenteredOnCurrentLocation)
        #expect(session.cameraCoordinate == MapFeatureCoordinate(latitude: 37.6, longitude: 127.1))
        #expect(session.cameraSpan == 0.12)

        session.recordCamera(coordinate: target, span: MapFeatureLocationPolicy.cameraSpan)
        #expect(session.cameraIsCenteredOnCurrentLocation)
    }

    @Test("이미 실제 카메라가 목표 좌표에 있으면 같은 위치 명령도 중심 상태를 유지한다")
    func repeatedCameraCommandKeepsConfirmedCenterState() {
        let session = MapFeatureSession()
        let target = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        session.recordCamera(coordinate: target, span: MapFeatureLocationPolicy.cameraSpan)

        session.expectCurrentLocationCamera(target)

        #expect(session.cameraIsCenteredOnCurrentLocation)
    }

    @Test("초기 상태는 요청과 사용자 안내가 없는 재시도 가능 상태다")
    func initialStateIsRetryableAndHasNoOutput() {
        let viewModel = MapFeatureViewModel(provider: AsyncLocationProvider())

        #expect(viewModel.state == .idle)
        #expect(!viewModel.isLoading)
        #expect(viewModel.authorizationMessage == nil)
        #expect(viewModel.alert == nil)
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.requestCount == 0)
    }

    @Test("화면 활성화 연결은 같은 세션에서 자동 요청을 한 번만 시작한다")
    func automaticRequestStartsOncePerSession() async {
        let session = MapFeatureSession()
        let firstProvider = AsyncLocationProvider()
        let recreatedProvider = AsyncLocationProvider()
        let firstViewModel = MapFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        await firstProvider.waitForLocationRequest()
        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(firstProvider.locationRequestCount == 1)
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)

        let independentSession = MapFeatureSession()
        #expect(independentSession.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        await recreatedProvider.waitForLocationRequest()
        firstViewModel.cancel()
        recreatedViewModel.cancel()
    }

    @Test("수동 요청은 같은 세션의 최초 자동 요청 권리를 소모하지 않는다")
    func manualRequestDoesNotConsumeAutomaticRequest() async {
        let session = MapFeatureSession()
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)

        session.startManually(viewModel.moveToCurrentLocation)
        await provider.waitForLocationRequest()
        provider.succeed(MapFeatureCoordinate(latitude: 37.5, longitude: 127))
        await eventually { viewModel.state == .located }

        #expect(session.startAutomatically(viewModel.moveToCurrentLocation))
        await provider.waitForLocationRequest(count: 2)
        #expect(session.requestCount == 2)
        #expect(viewModel.requestCount == 2)

        #expect(!session.startAutomatically(viewModel.moveToCurrentLocation))
        #expect(provider.locationRequestCount == 2)
        viewModel.cancel()
    }

    @Test("자동 요청이 권한 거부로 끝나도 같은 세션의 재진입은 반복하지 않는다")
    func deniedAutomaticRequestIsNotRepeatedAfterReentry() async {
        let session = MapFeatureSession()
        let firstProvider = AsyncLocationProvider(authorization: .denied)
        let recreatedProvider = AsyncLocationProvider()
        let firstViewModel = MapFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        await eventually { firstViewModel.state == .authorizationDenied }

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(firstProvider.locationRequestCount == 0)
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("자동 요청이 위치 실패로 끝나도 같은 세션의 재진입은 반복하지 않는다")
    func failedAutomaticRequestIsNotRepeatedAfterReentry() async {
        let session = MapFeatureSession()
        let firstProvider = AsyncLocationProvider()
        let recreatedProvider = AsyncLocationProvider()
        let firstViewModel = MapFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        await firstProvider.waitForLocationRequest()
        firstProvider.fail(MapFeatureLocationError.unavailable)
        await eventually { firstViewModel.state == .failed }

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(firstProvider.locationRequestCount == 1)
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("자동 요청 성공 뒤 같은 세션의 재진입은 반복하지 않는다")
    func successfulAutomaticRequestIsNotRepeatedAfterReentry() async {
        let session = MapFeatureSession()
        let firstProvider = AsyncLocationProvider()
        let recreatedProvider = AsyncLocationProvider()
        let firstViewModel = MapFeatureViewModel(provider: firstProvider)
        let recreatedViewModel = MapFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        await firstProvider.waitForLocationRequest()
        firstProvider.succeed(MapFeatureCoordinate(latitude: 37.5, longitude: 127))
        await eventually { firstViewModel.cameraCommand != nil }

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("자동 요청 timeout 뒤 같은 세션의 재진입은 반복하지 않는다")
    func timedOutAutomaticRequestIsNotRepeatedAfterReentry() async {
        let session = MapFeatureSession()
        let firstProvider = AsyncLocationProvider()
        let recreatedProvider = AsyncLocationProvider()
        let firstViewModel = MapFeatureViewModel(
            provider: firstProvider,
            timeoutNanoseconds: 1_000_000
        )
        let recreatedViewModel = MapFeatureViewModel(provider: recreatedProvider)

        #expect(session.startAutomatically(firstViewModel.moveToCurrentLocation))
        await firstProvider.waitForLocationRequest()
        await eventually { firstViewModel.alert?.kind == .timeout }

        #expect(!session.startAutomatically(recreatedViewModel.moveToCurrentLocation))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(recreatedProvider.locationRequestCount == 0)
        #expect(!recreatedViewModel.isLoading)
        #expect(recreatedViewModel.cameraCommand == nil)
        #expect(recreatedViewModel.alert == nil)
    }

    @Test("허용된 권한은 권한 요청 없이 위치를 조회한다")
    func authorizedStatusSkipsAuthorizationRequest() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        #expect(provider.authorizationRequestCount == 0)
        #expect(provider.locationRequestCount == 1)
        #expect(viewModel.requestCount == 1)
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("권한 미결정이면 응답을 기다린 뒤 위치를 조회한다")
    func undeterminedAuthorizationIsResolvedFirst() async {
        let provider = AsyncLocationProvider(authorization: .notDetermined)
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 1 }
        #expect(viewModel.state == .requestingAuthorization)
        #expect(provider.locationRequestCount == 0)
        provider.resolveAuthorization(.authorized)
        await provider.waitForLocationRequest()
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("권한 거부는 위치를 조회하지 않고 인라인 메시지를 만든다")
    func deniedDoesNotRequestLocation() async {
        let provider = AsyncLocationProvider(authorization: .denied)
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await eventually { viewModel.state == .authorizationDenied }
        #expect(provider.authorizationRequestCount == 0)
        #expect(provider.locationRequestCount == 0)
        #expect(viewModel.authorizationMessage != nil)
        #expect(!viewModel.isLoading)
    }

    @Test("권한 요청의 거부 응답도 위치를 조회하지 않는다")
    func deniedAuthorizationResponseDoesNotRequestLocation() async {
        let provider = AsyncLocationProvider(authorization: .notDetermined)
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 1 }
        provider.resolveAuthorization(.denied)
        await eventually { viewModel.state == .authorizationDenied }
        #expect(provider.locationRequestCount == 0)

        viewModel.moveToCurrentLocation()
        await eventually { viewModel.state == .authorizationDenied }
        #expect(provider.authorizationRequestCount == 1)
        #expect(provider.locationRequestCount == 0)
    }

    @Test("권한 요청 실패는 카메라를 유지하고 재시도 성공까지 처리한다")
    func authorizationFailurePreservesCameraAndRetrySucceeds() async {
        let provider = AsyncLocationProvider(authorization: .notDetermined)
        let viewModel = MapFeatureViewModel(provider: provider)

        provider.authorization = .authorized
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        let previousCoordinate = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        provider.succeed(previousCoordinate)
        await eventually { viewModel.state == .located }
        let previousCommand = viewModel.cameraCommand

        provider.authorization = .notDetermined
        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 1 }

        provider.failAuthorization(MapFeatureLocationError.unavailable)
        await eventually { viewModel.state == .failed }

        #expect(viewModel.alert?.kind == .failure)
        #expect(!viewModel.isLoading)
        #expect(provider.locationRequestCount == 1)
        #expect(viewModel.cameraCommand == previousCommand)

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 2 }
        #expect(viewModel.state == .requestingAuthorization)
        #expect(viewModel.alert == nil)

        provider.resolveAuthorization(.authorized)
        await provider.waitForLocationRequest(count: 2)
        let retryCoordinate = MapFeatureCoordinate(latitude: 37.6, longitude: 127.1)
        provider.succeed(retryCoordinate)
        await eventually { viewModel.state == .located }
        #expect(viewModel.cameraCommand?.coordinate == retryCoordinate)
        #expect(viewModel.cameraCommand?.commandID != previousCommand?.commandID)
    }

    @Test("연속 권한 요청 실패는 매번 새 alert를 만들고 재시도를 허용한다")
    func repeatedAuthorizationFailurePublishesFreshAlerts() async {
        let provider = AsyncLocationProvider(authorization: .notDetermined)
        let viewModel = MapFeatureViewModel(provider: provider)

        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 1 }
        provider.failAuthorization(MapFeatureLocationError.unavailable)
        await eventually { viewModel.state == .failed }
        let firstAlertID = viewModel.alert?.id

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 2 }
        provider.failAuthorization(MapFeatureLocationError.unavailable)
        await eventually {
            guard let alertID = viewModel.alert?.id else { return false }
            return alertID != firstAlertID
        }

        #expect(viewModel.state == .failed)
        #expect(viewModel.alert?.kind == .failure)
        #expect(!viewModel.isLoading)
    }

    @Test("권한 거부 뒤 외부에서 허용되면 버튼 재시도로 위치를 조회한다")
    func retryAfterAuthorizationBecomesGrantedRequestsLocation() async {
        let provider = AsyncLocationProvider(authorization: .denied)
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await eventually { viewModel.state == .authorizationDenied }

        provider.authorization = .authorized
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()

        #expect(provider.authorizationRequestCount == 0)
        #expect(provider.locationRequestCount == 1)
        #expect(viewModel.authorizationMessage == nil)
        #expect(viewModel.state == .locating)
        let coordinate = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        provider.succeed(coordinate)
        await eventually { viewModel.state == .located }
        #expect(viewModel.cameraCommand?.coordinate == coordinate)
    }

    @Test("Core Location 권한 상태를 빠짐없이 Feature 권한으로 변환한다")
    func coreLocationAuthorizationMappingCoversEveryKnownStatus() {
        #expect(CoreMapLocationProvider.authorization(from: .notDetermined) == .notDetermined)
        #expect(CoreMapLocationProvider.authorization(from: .authorizedWhenInUse) == .authorized)
        #expect(CoreMapLocationProvider.authorization(from: .authorizedAlways) == .authorized)
        #expect(CoreMapLocationProvider.authorization(from: .denied) == .denied)
        #expect(CoreMapLocationProvider.authorization(from: .restricted) == .denied)
    }

    @Test("continuation 설치 전에 취소된 Core Location 요청은 즉시 종료된다")
    func cancellationBeforeContinuationInstallationFinishesImmediately() async {
        let provider = CoreMapLocationProvider()
        let task = Task { @MainActor in
            try await provider.requestAuthorization()
        }

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("취소된 요청이 권한 상태를 반환했습니다.")
        } catch is CancellationError {
            // 예상한 취소 종료입니다.
        } catch {
            Issue.record("예상하지 못한 오류로 종료했습니다: \(error)")
        }
    }

    @Test("권한 응답 대기 중 연속 입력도 하나의 권한 요청만 유지한다")
    func concurrentInputWhileAuthorizingIsIgnored() async {
        let provider = AsyncLocationProvider(authorization: .notDetermined)
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 1 }
        viewModel.moveToCurrentLocation()
        viewModel.moveToCurrentLocation()
        await Task.yield()
        #expect(provider.authorizationRequestCount == 1)
        #expect(provider.locationRequestCount == 0)
        #expect(viewModel.state == .requestingAuthorization)
        viewModel.cancel()
    }

    @Test("요청 중 입력은 무시하고 같은 좌표에도 새 카메라 명령을 만든다")
    func successPublishesFreshCommandsAndIgnoresConcurrentInput() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)
        let coordinate = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        viewModel.moveToCurrentLocation()
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        #expect(provider.locationRequestCount == 1)
        provider.succeed(coordinate)
        await eventually { viewModel.state == .located }
        let firstCommand = viewModel.cameraCommand
        #expect(firstCommand?.coordinate == coordinate)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 2)
        provider.succeed(coordinate)
        await eventually { viewModel.cameraCommand?.commandID != firstCommand?.commandID }
        #expect(viewModel.cameraCommand?.coordinate == coordinate)
        #expect(viewModel.requestCount == 2)
    }

    @Test("잘못된 좌표는 실패 alert를 만들고 카메라를 유지한다")
    func invalidCoordinateFailsWithoutCameraCommand() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        provider.succeed(MapFeatureCoordinate(latitude: 91, longitude: 127))
        await eventually { viewModel.state == .failed }
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.alert?.kind == .failure)
        #expect(!viewModel.isLoading)
    }

    @Test("경도 범위 초과와 유한하지 않은 좌표를 모두 거부한다", arguments: [
        MapFeatureCoordinate(latitude: 0, longitude: 181),
        MapFeatureCoordinate(latitude: .nan, longitude: 0),
        MapFeatureCoordinate(latitude: 0, longitude: .infinity),
        MapFeatureCoordinate(latitude: -.infinity, longitude: 0),
    ])
    func nonFiniteAndOutOfRangeCoordinatesFail(
        coordinate: MapFeatureCoordinate
    ) async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        provider.succeed(coordinate)
        await eventually { viewModel.state == .failed }
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.alert?.kind == .failure)
    }

    @Test("유효 좌표의 경계값은 카메라 명령을 만든다")
    func coordinateBoundariesAreAccepted() async {
        let coordinates = [
            MapFeatureCoordinate(latitude: -90, longitude: -180),
            MapFeatureCoordinate(latitude: 90, longitude: 180),
        ]
        for coordinate in coordinates {
            let provider = AsyncLocationProvider()
            let viewModel = MapFeatureViewModel(provider: provider)
            viewModel.moveToCurrentLocation()
            await provider.waitForLocationRequest()
            provider.succeed(coordinate)
            await eventually { viewModel.state == .located }
            #expect(viewModel.cameraCommand?.coordinate == coordinate)
            #expect(viewModel.alert == nil)
        }
    }

    @Test("위치 서비스 오류는 일반 실패로 정규화하고 기존 카메라 명령을 유지한다")
    func serviceFailurePreservesPreviousCameraCommand() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)
        let coordinate = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        provider.succeed(coordinate)
        await eventually { viewModel.state == .located }
        let previousCommand = viewModel.cameraCommand

        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 2)
        provider.fail(MapFeatureLocationError.servicesDisabled)
        await eventually { viewModel.state == .failed }

        #expect(viewModel.cameraCommand == previousCommand)
        #expect(viewModel.alert?.kind == .failure)
        #expect(!viewModel.isLoading)
    }

    @Test("일시적 위치 부재 뒤 버튼 재시도는 새 위치로 이동한다")
    func retryAfterTemporaryLocationUnavailabilitySucceeds() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)

        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        provider.fail(MapFeatureLocationError.unavailable)
        await eventually { viewModel.state == .failed }

        #expect(viewModel.alert?.kind == .failure)
        #expect(viewModel.cameraCommand == nil)
        #expect(!viewModel.isLoading)

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 2)
        let coordinate = MapFeatureCoordinate(latitude: 37.6, longitude: 127.1)
        provider.succeed(coordinate)
        await eventually { viewModel.state == .located }

        #expect(viewModel.alert == nil)
        #expect(viewModel.cameraCommand?.coordinate == coordinate)
        #expect(viewModel.cameraCommand?.commandID != nil)
        #expect(viewModel.requestCount == 2)
    }

    @Test("연속 위치 실패는 새 alert를 만들고 재시도를 허용한다")
    func repeatedFailurePublishesFreshAlertAndAllowsRetry() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        provider.fail(MapFeatureLocationError.unavailable)
        await eventually { viewModel.state == .failed }
        let firstAlertID = viewModel.alert?.id
        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 2)
        provider.fail(MapFeatureLocationError.unavailable)
        await eventually { viewModel.alert != nil }
        #expect(viewModel.alert?.kind == .failure)
        #expect(viewModel.alert?.id != firstAlertID)
        #expect(!viewModel.isLoading)
    }

    @Test("연속 timeout은 매번 새 alert를 만들고 재시도를 허용한다")
    func repeatedTimeoutPublishesFreshAlertAndAllowsRetry() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(
            provider: provider,
            timeoutNanoseconds: 1_000_000
        )

        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        await eventually { viewModel.alert?.kind == .timeout }
        let firstAlertID = viewModel.alert?.id

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 2)
        await eventually {
            guard let alert = viewModel.alert else { return false }
            return alert.kind == .timeout && alert.id != firstAlertID
        }

        #expect(viewModel.state == .failed)
        #expect(!viewModel.isLoading)
        #expect(viewModel.cameraCommand == nil)
    }

    @Test("위치가 오지 않으면 timeout alert를 표시하고 요청을 취소한다")
    func timeoutEndsLoadingAndCancelsRequest() async {
        let provider = AsyncLocationProvider()
        let viewModel = MapFeatureViewModel(provider: provider, timeoutNanoseconds: 1_000_000)
        let coordinate = MapFeatureCoordinate(latitude: 37.5, longitude: 127)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        provider.succeed(coordinate)
        await eventually { viewModel.state == .located }
        let previousCommand = viewModel.cameraCommand

        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 2)
        await eventually { viewModel.alert?.kind == .timeout }
        #expect(viewModel.state == .failed)
        #expect(!viewModel.isLoading)
        #expect(provider.cancelCount >= 1)
        #expect(viewModel.cameraCommand == previousCommand)

        viewModel.dismissAlert()
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 3)
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("취소는 provider에 전달되고 늦은 결과를 막으며 재시도를 허용한다")
    func cancellationBlocksLateResultAndAllowsRetry() async {
        let provider = AsyncLocationProvider(ignoresCancellation: true)
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        viewModel.cancel()
        provider.succeed(MapFeatureCoordinate(latitude: 1, longitude: 1))
        await Task.yield()
        #expect(provider.cancelCount >= 1)
        #expect(viewModel.cameraCommand == nil)
        #expect(viewModel.state == .idle)
        #expect(viewModel.alert == nil)
        viewModel.moveToCurrentLocation()
        await provider.waitForLocationRequest(count: 2)
        #expect(viewModel.state == .locating)
        viewModel.cancel()
    }

    @Test("권한 요청 취소는 provider에 전달되고 UI 이벤트를 만들지 않는다")
    func cancellationWhileAuthorizingProducesNoUserFacingError() async {
        let provider = AsyncLocationProvider(
            authorization: .notDetermined,
            ignoresCancellation: true
        )
        let viewModel = MapFeatureViewModel(provider: provider)
        viewModel.moveToCurrentLocation()
        await eventually { provider.authorizationRequestCount == 1 }
        viewModel.cancel()
        provider.resolveAuthorization(.authorized)
        await Task.yield()
        #expect(provider.cancelCount >= 1)
        #expect(provider.locationRequestCount == 0)
        #expect(viewModel.state == .idle)
        #expect(viewModel.authorizationMessage == nil)
        #expect(viewModel.alert == nil)
        #expect(viewModel.cameraCommand == nil)
    }

    @Test("ViewModel 수명 종료는 실행 중인 위치 요청을 취소한다")
    func deinitializationCancelsInFlightLocationRequest() async {
        let provider = AsyncLocationProvider()
        var viewModel: MapFeatureViewModel? = MapFeatureViewModel(provider: provider)
        weak var weakViewModel = viewModel

        viewModel?.moveToCurrentLocation()
        await provider.waitForLocationRequest()
        viewModel = nil
        await eventually {
            weakViewModel == nil && provider.cancelCount >= 1
        }

        #expect(weakViewModel == nil)
        #expect(provider.cancelCount >= 1)
    }
}

@MainActor
private final class AsyncLocationProvider: MapLocationProviding {
    var authorization: MapFeatureAuthorization
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0
    private(set) var cancelCount = 0
    private let ignoresCancellation: Bool
    private var authorizationContinuation: CheckedContinuation<MapFeatureAuthorization, Error>?
    private var locationContinuation: CheckedContinuation<MapFeatureCoordinate, Error>?

    /// 초기 권한 상태로 테스트 제공자를 만듭니다.
    /// - Parameters:
    ///   - authorization: 최초 권한 확인에서 반환할 상태입니다.
    ///   - ignoresCancellation: 취소 뒤에도 늦은 완료를 전달할지 여부입니다.
    init(
        authorization: MapFeatureAuthorization = .authorized,
        ignoresCancellation: Bool = false
    ) {
        self.authorization = authorization
        self.ignoresCancellation = ignoresCancellation
    }

    func authorizationStatus() -> MapFeatureAuthorization { authorization }

    func requestAuthorization() async throws -> MapFeatureAuthorization {
        authorizationRequestCount += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { authorizationContinuation = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    func requestLocation() async throws -> MapFeatureCoordinate {
        locationRequestCount += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { locationContinuation = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel() }
        }
    }

    func cancel() {
        cancelCount += 1
        guard !ignoresCancellation else { return }
        authorizationContinuation?.resume(throwing: CancellationError())
        authorizationContinuation = nil
        locationContinuation?.resume(throwing: CancellationError())
        locationContinuation = nil
    }

    /// 권한 요청을 지정한 상태로 끝냅니다.
    /// - Parameter authorization: 권한 요청에서 반환할 상태입니다.
    func resolveAuthorization(
        _ authorization: MapFeatureAuthorization
    ) {
        self.authorization = authorization
        authorizationContinuation?.resume(returning: authorization)
        authorizationContinuation = nil
    }

    /// 권한 요청을 오류로 끝냅니다.
    /// - Parameter error: 권한 요청에서 반환할 오류입니다.
    func failAuthorization(
        _ error: Error
    ) {
        authorizationContinuation?.resume(throwing: error)
        authorizationContinuation = nil
    }

    /// 위치 요청을 성공시킵니다.
    /// - Parameter coordinate: 반환할 좌표입니다.
    func succeed(
        _ coordinate: MapFeatureCoordinate
    ) {
        locationContinuation?.resume(returning: coordinate)
        locationContinuation = nil
    }

    /// 위치 요청을 실패시킵니다.
    /// - Parameter error: 반환할 오류입니다.
    func fail(
        _ error: Error
    ) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    /// 누적 위치 요청 횟수에 도달할 때까지 기다립니다.
    /// - Parameter count: 기다릴 요청 횟수입니다.
    func waitForLocationRequest(
        count: Int = 1
    ) async {
        await eventually { self.locationRequestCount >= count }
    }
}

/// 조건이 충족될 때까지 비동기 작업에 실행 기회를 줍니다.
/// - Parameter condition: 완료 여부를 반환하는 조건입니다.
@MainActor
private func eventually(
    _ condition: @escaping @MainActor () -> Bool
) async {
    for _ in 0..<10_000 where !condition() { await Task.yield() }
    #expect(condition())
}
