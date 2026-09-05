import Foundation
import RxCocoa
import RxRelay
import RxSwift

/// 기존 Mapbox 화면의 표현을 보존하는 현재 위치 기능 기본 정책입니다.
public enum MapBoxFeatureLocationPolicy {
    /// 구현 전 화면에서 사용하던 카메라 확대 수준입니다.
    public static let cameraZoom = 10.5

    /// 별도 제품 수치가 정해질 때까지 동일하게 적용하는 위치 조회 제한 시간입니다.
    public static let compatibilityTimeout: RxTimeInterval = .seconds(10)
}

/// 지도 화면에 전달할 현재 위치 카메라 명령입니다.
public struct MapBoxCameraCommand: Equatable, Sendable {
    /// 카메라가 이동할 중심 좌표입니다.
    public let coordinate: MapBoxCoordinate

    /// 같은 좌표로 이동하는 명령도 구분하는 식별자입니다.
    public let commandID: UUID
}

/// 사용자에게 표시할 위치 조회 오류입니다.
public struct MapBoxAlert: Identifiable, Equatable, Sendable {
    /// 위치 조회 오류의 표시 종류입니다.
    public enum Kind: Equatable, Sendable {
        case failure
        case timeout
    }

    /// 같은 오류가 반복되어도 새 알림으로 구분하는 식별자입니다.
    public let id: UUID

    /// 일반 실패와 시간 초과를 구분하는 종류입니다.
    public let kind: Kind

    /// 사용자에게 표시할 오류 안내 문구입니다.
    public let message: String
}

/// 화면 입력을 위치 조회 흐름으로 변환하고 UIKit이 구독할 출력을 제공합니다.
public final class MapBoxFeatureViewModel {
    /// 현재 위치 요청의 진행 상태입니다.
    public enum State: Equatable {
        case idle
        case requestingAuthorization
        case locating
        case located
        case authorizationDenied
        case failed
    }

    /// ViewController가 ViewModel에 전달하는 화면 이벤트입니다.
    public struct Input {
        /// 앱 수명에서 허용된 최초 화면 등장 이벤트입니다.
        public let viewDidAppear: Observable<Void>

        /// 사용자가 현재 위치 버튼을 누른 이벤트입니다.
        public let currentLocationTapped: Observable<Void>

        /// 지도 화면이 사라진 이벤트입니다.
        public let viewDidDisappear: Observable<Void>

        /// ViewModel이 처리할 화면 입력 스트림을 만듭니다.
        ///
        /// - Parameters:
        ///   - viewDidAppear: 앱 수명에서 허용된 최초 화면 등장 이벤트입니다.
        ///   - currentLocationTapped: 사용자가 현재 위치 버튼을 누른 이벤트입니다.
        ///   - viewDidDisappear: 지도 화면이 사라진 이벤트입니다.
        public init(
            viewDidAppear: Observable<Void>,
            currentLocationTapped: Observable<Void>,
            viewDidDisappear: Observable<Void>
        ) {
            self.viewDidAppear = viewDidAppear
            self.currentLocationTapped = currentLocationTapped
            self.viewDidDisappear = viewDidDisappear
        }
    }

    /// ViewController가 구독해 화면에 반영하는 Rx 출력입니다.
    public struct Output {
        /// 로딩과 권한 메시지를 결정하는 위치 요청 상태입니다.
        public let state: Driver<State>

        /// 지도 중심을 현재 위치로 이동시키는 일회성 명령입니다.
        public let cameraCommand: Signal<MapBoxCameraCommand>

        /// 한 번만 표시할 위치 오류 알림입니다.
        public let alert: Signal<MapBoxAlert>
    }

    /// Rx 위치 요청에서 화면 상태로 변환하기 위한 내부 이벤트입니다.
    private enum Event {
        case requestingAuthorization
        case locating
        case denied
        case located(MapBoxCoordinate)
        case failed(Bool)
    }

    /// 위치 권한과 현재 좌표를 RxSwift 타입으로 제공하는 객체입니다.
    private let provider: any MapboxLocationProviding

    /// 단일 위치 조회가 완료되기를 기다리는 최대 시간입니다.
    private let timeout: RxTimeInterval

    /// 최신 화면 상태를 보관하고 새 구독자에게 즉시 전달합니다.
    private let stateRelay = BehaviorRelay<State>(value: .idle)

    /// 새로운 카메라 이동 명령만 화면에 전달합니다.
    private let cameraCommandRelay = PublishRelay<MapBoxCameraCommand>()

    /// 새로운 위치 오류 알림만 화면에 전달합니다.
    private let alertRelay = PublishRelay<MapBoxAlert>()

    /// 현재 Input과 Output을 연결한 Rx 구독의 수명을 관리합니다.
    private var transformDisposeBag = DisposeBag()

    /// 취소 시 로딩 상태인지 판단하기 위한 마지막 상태입니다.
    private var state: State = .idle

    /// ViewModel이 처리한 현재 위치 요청 횟수입니다.
    private var requestCount = 0

    /// RxSwift 위치 흐름을 관리하는 ViewModel을 만듭니다.
    ///
    /// - Parameters:
    ///   - provider: Rx 권한과 위치를 제공할 객체입니다.
    ///   - timeout: 단일 위치 조회 제한 시간입니다.
    @MainActor
    public init(
        provider: any MapboxLocationProviding,
        timeout: RxTimeInterval = MapBoxFeatureLocationPolicy.compatibilityTimeout
    ) {
        self.provider = provider
        self.timeout = timeout
    }

    /// Core Location 제공자와 기본 제한 시간으로 ViewModel을 만듭니다.
    @MainActor
    public convenience init() {
#if DEBUG
        if ProcessInfo.processInfo.environment["UITEST_LOCATION_SCENARIO"] == "success" {
            self.init(provider: MapBoxUITestLocationProvider())
            return
        }
#endif
        self.init(provider: CoreMapboxLocationProvider())
    }

    /// 화면 입력을 위치 조회 흐름에 연결하고 출력 스트림을 반환합니다.
    ///
    /// - Parameter input: 화면 생명주기와 사용자 입력 스트림입니다.
    /// - Returns: UIKit 화면이 구독할 상태와 명령 스트림입니다.
    @MainActor
    public func transform(
        input: Input
    ) -> Output {
        transformDisposeBag = DisposeBag()
        let disappearance = input.viewDidDisappear.share()

        Observable.merge(
            input.viewDidAppear,
            input.currentLocationTapped
        )
        .flatMapFirst { [weak self] _ -> Observable<Event> in
            guard let self else { return .empty() }
            return self.requestEvents()
                .take(until: disappearance)
        }
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] event in
            self?.apply(event)
        })
        .disposed(by: transformDisposeBag)

        disappearance
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                self?.handleDisappearance()
            })
            .disposed(by: transformDisposeBag)

        return Output(
            state: stateRelay
                .asDriver()
                .distinctUntilChanged(),
            cameraCommand: cameraCommandRelay.asSignal(),
            alert: alertRelay.asSignal()
        )
    }

    /// RxSwift 오류가 timeout 종료를 뜻하는지 확인합니다.
    ///
    /// - Parameter error: 위치 stream에서 종료를 발생시킨 오류입니다.
    /// - Returns: timeout 오류이면 `true`입니다.
    private static func isTimeout(
        _ error: Error
    ) -> Bool {
        guard let rxError = error as? RxError,
              case .timeout = rxError else { return false }
        return true
    }
}

@MainActor
private extension MapBoxFeatureViewModel {
    /// 현재 권한부터 단일 위치 결과까지를 화면 이벤트로 변환합니다.
    ///
    /// - Returns: 한 번의 현재 위치 요청에서 발생하는 화면 이벤트입니다.
    private func requestEvents() -> Observable<Event> {
        requestCount += 1
        let authorization = provider.authorizationStatus()
        let authorizationEvents: Observable<MapBoxAuthorization>
        if authorization == .notDetermined {
            authorizationEvents = Observable.concat([
                .just(.notDetermined),
                provider.requestAuthorization().asObservable(),
            ])
        } else {
            authorizationEvents = .just(authorization)
        }

        return authorizationEvents
            .flatMap { [weak self] authorization -> Observable<Event> in
                guard let self else { return .empty() }
                switch authorization {
                case .notDetermined:
                    return .just(.requestingAuthorization)
                case .denied:
                    return .just(.denied)
                case .authorized:
                    return Observable.concat([
                        .just(.locating),
                        self.provider.requestLocation()
                            .timeout(self.timeout, scheduler: MainScheduler.instance)
                            .asObservable()
                            .map { $0.isValid ? .located($0) : .failed(false) },
                    ])
                }
            }
            .catch { error in
                .just(.failed(Self.isTimeout(error)))
            }
    }

    /// Rx 이벤트를 사용자에게 보이는 상태로 반영합니다.
    ///
    /// - Parameter event: 현재 요청에서 발생한 이벤트입니다.
    private func apply(
        _ event: Event
    ) {
        switch event {
        case .requestingAuthorization:
            updateState(.requestingAuthorization)
        case .locating:
            updateState(.locating)
        case .denied:
            updateState(.authorizationDenied)
        case .located(let coordinate):
            cameraCommandRelay.accept(
                MapBoxCameraCommand(
                    coordinate: coordinate,
                    commandID: UUID()
                )
            )
            updateState(.located)
        case .failed(let timedOut):
            updateState(.failed)
            alertRelay.accept(
                MapBoxAlert(
                    id: UUID(),
                    kind: timedOut ? .timeout : .failure,
                    message: timedOut
                        ? "현재 위치를 확인하는 데 시간이 오래 걸립니다. 다시 시도해 주세요."
                        : "현재 위치를 확인하지 못했습니다. 다시 시도해 주세요."
                )
            )
        }
    }

    /// 현재 상태를 저장하고 Output 구독자에게 전달합니다.
    ///
    /// - Parameter newState: 새로 반영할 위치 요청 상태입니다.
    func updateState(
        _ newState: State
    ) {
        state = newState
        stateRelay.accept(newState)
    }

    /// 진행 중인 위치 요청을 취소하고 로딩 상태를 초기화합니다.
    func handleDisappearance() {
        provider.cancel()
        if state == .requestingAuthorization || state == .locating {
            updateState(.idle)
        }
    }
}

#if DEBUG
@MainActor
private final class MapBoxUITestLocationProvider: MapboxLocationProviding {
    func authorizationStatus() -> MapBoxAuthorization {
        .authorized
    }

    func requestAuthorization() -> Single<MapBoxAuthorization> {
        .just(.authorized)
    }

    func requestLocation() -> Single<MapBoxCoordinate> {
        Single.just(
            MapBoxCoordinate(
                latitude: 37.5547,
                longitude: 126.9707
            )
        )
        .delay(.milliseconds(300), scheduler: MainScheduler.instance)
    }

    func cancel() {}
}
#endif
