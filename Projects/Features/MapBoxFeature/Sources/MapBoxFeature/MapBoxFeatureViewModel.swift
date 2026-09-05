import Foundation
import RxSwift

/// 기존 Mapbox 화면의 표현을 보존하는 현재 위치 기능 기본 정책입니다.
public enum MapBoxFeatureLocationPolicy {
    /// 구현 전 화면에서 사용하던 카메라 확대 수준입니다.
    public static let cameraZoom = 10.5

    /// 별도 제품 수치가 정해질 때까지 양쪽 구현에 동일하게 적용하는 호환 제한 시간입니다.
    public static let compatibilityTimeout: RxTimeInterval = .seconds(10)
}

public struct MapBoxCameraCommand: Equatable, Sendable {
    public let coordinate: MapBoxCoordinate
    public let commandID: UUID
}

public struct MapBoxAlert: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case failure, timeout }
    public let id: UUID
    public let kind: Kind
    public let message: String
}

@MainActor
public final class MapBoxFeatureViewModel {
    public enum State: Equatable { case idle, requestingAuthorization, locating, located, authorizationDenied, failed }
    private enum Event { case requestingAuthorization, locating, denied, located(MapBoxCoordinate), failed(Bool) }

    public private(set) var state: State = .idle {
        didSet { stateSubject.onNext(state) }
    }
    public private(set) var cameraCommand: MapBoxCameraCommand? {
        didSet {
            if let cameraCommand {
                cameraCommandSubject.onNext(cameraCommand)
            }
        }
    }
    public private(set) var alert: MapBoxAlert? {
        didSet { alertSubject.onNext(alert) }
    }
    public private(set) var requestCount = 0
    public var authorizationMessage: String? { state == .authorizationDenied ? "위치 권한이 없어 현재 위치를 확인할 수 없습니다." : nil }
    public var isLoading: Bool { state == .requestingAuthorization || state == .locating }

    /// 화면 상태를 UIKit에 전달하는 오류 없는 Rx 스트림입니다.
    public var stateObservable: Observable<State> {
        stateSubject
            .asObservable()
            .distinctUntilChanged()
    }

    /// 새로운 카메라 이동 명령만 UIKit에 전달하는 Rx 스트림입니다.
    public var cameraCommandObservable: Observable<MapBoxCameraCommand> {
        cameraCommandSubject.asObservable()
    }

    /// 표시하거나 닫아야 할 알림을 UIKit에 전달하는 Rx 스트림입니다.
    public var alertObservable: Observable<MapBoxAlert?> {
        alertSubject.asObservable()
    }

    private let provider: any MapboxLocationProviding
    private let timeout: RxTimeInterval
    private let input = PublishSubject<Void>()
    private let stateSubject = BehaviorSubject<State>(value: .idle)
    private let cameraCommandSubject = PublishSubject<MapBoxCameraCommand>()
    private let alertSubject = BehaviorSubject<MapBoxAlert?>(value: nil)
    private var disposeBag = DisposeBag()
    private var isBound = false

    /// RxSwift 위치 흐름을 관리하는 ViewModel을 만듭니다.
    ///
    /// - Parameters:
    ///   - provider: Rx 권한과 위치를 제공할 객체입니다.
    ///   - timeout: 단일 위치 조회 제한 시간입니다.
    public init(
        provider: any MapboxLocationProviding,
        timeout: RxTimeInterval = MapBoxFeatureLocationPolicy.compatibilityTimeout
    ) {
        self.provider = provider
        self.timeout = timeout
        bind()
    }

    /// Core Location 제공자와 제품 수치 확정 전 임시 제한 시간으로 ViewModel을 만듭니다.
    public convenience init() {
#if DEBUG
        if ProcessInfo.processInfo.environment["UITEST_LOCATION_SCENARIO"] == "success" {
            self.init(provider: MapBoxUITestLocationProvider())
            return
        }
#endif
        self.init(provider: CoreMapboxLocationProvider())
    }

    public func moveToCurrentLocation() {
        if !isBound { bind() }
        input.onNext(())
    }

    public func cancel() {
        disposeBag = DisposeBag()
        isBound = false
        provider.cancel()
        if isLoading { state = .idle }
    }

    public func dismissAlert() { alert = nil }

    private func bind() {
        guard !isBound else { return }
        isBound = true
        input
            .flatMapFirst { [weak self] _ -> Observable<Event> in
                guard let self else { return .empty() }
                return self.requestEvents()
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in self?.apply(event) })
            .disposed(by: disposeBag)
    }

    private func requestEvents() -> Observable<Event> {
        requestCount += 1
        alert = nil
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
                case .notDetermined: return .just(.requestingAuthorization)
                case .denied: return .just(.denied)
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
            .catch { error in .just(.failed(Self.isTimeout(error))) }
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

    /// Rx 이벤트를 사용자에게 보이는 상태로 반영합니다.
    ///
    /// - Parameter event: 현재 요청에서 발생한 이벤트입니다.
    private func apply(
        _ event: Event
    ) {
        switch event {
        case .requestingAuthorization: state = .requestingAuthorization
        case .locating: state = .locating
        case .denied: state = .authorizationDenied
        case .located(let coordinate):
            cameraCommand = MapBoxCameraCommand(coordinate: coordinate, commandID: UUID())
            state = .located
        case .failed(let timedOut):
            state = .failed
            alert = MapBoxAlert(
                id: UUID(),
                kind: timedOut ? .timeout : .failure,
                message: timedOut
                    ? "현재 위치를 확인하는 데 시간이 오래 걸립니다. 다시 시도해 주세요."
                    : "현재 위치를 확인하지 못했습니다. 다시 시도해 주세요."
            )
        }
    }
}

#if DEBUG
@MainActor
private final class MapBoxUITestLocationProvider: MapboxLocationProviding {
    func authorizationStatus() -> MapBoxAuthorization { .authorized }

    func requestAuthorization() -> Single<MapBoxAuthorization> { .just(.authorized) }

    func requestLocation() -> Single<MapBoxCoordinate> {
        Single.just(MapBoxCoordinate(latitude: 37.5547, longitude: 126.9707))
            .delay(.milliseconds(300), scheduler: MainScheduler.instance)
    }

    func cancel() {}
}
#endif
