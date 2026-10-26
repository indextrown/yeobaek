import ComposableArchitecture
import Foundation

/// 기존 MapKit 화면의 표현을 보존하는 현재 위치 기능 기본 정책입니다.
public enum MapFeatureLocationPolicy {
    /// 구현 전 화면에서 사용하던 위도·경도 범위입니다.
    public static let cameraSpan = 0.18

    /// 별도 제품 수치가 정해질 때까지 양쪽 구현에 동일하게 적용하는 호환 제한 시간입니다.
    public static let compatibilityTimeout: Duration = .seconds(10)

    /// 카메라 중심이 목표 좌표와 같다고 판단하는 위도·경도 허용 오차입니다.
    static let centerTolerance = 0.000_1
}

/// View가 지도 카메라를 이동하도록 전달하는 일회성 명령입니다.
public struct MapFeatureCameraCommand: Equatable, Sendable {
    public let coordinate: MapFeatureCoordinate
    public let commandID: UUID
}

/// MapKit 지도 화면의 현재 위치 이동과 카메라 상태를 관리하는 Reducer입니다.
///
/// Store가 앱 실행 동안 유지되므로 지도 제공자를 바꿨다가 돌아와도
/// 자동 위치 요청 여부와 마지막 카메라 위치가 보존됩니다.
@Reducer
public struct MapKitFeature {
    @ObservableState
    public struct State: Equatable {
        public enum Status: Equatable, Sendable {
            case idle
            case requestingAuthorization
            case locating
            case located
            case authorizationDenied
            case failed
        }

        public enum FailureKind: Equatable, Sendable {
            case failure
            case timeout
        }

        public var status: Status = .idle
        public var cameraCommand: MapFeatureCameraCommand?
        public var cameraCoordinate = MapFeatureCoordinate(
            latitude: 37.5665,
            longitude: 126.9780
        )
        public var cameraSpan = MapFeatureLocationPolicy.cameraSpan
        public var cameraIsCenteredOnCurrentLocation = false
        public var currentLocationTarget: MapFeatureCoordinate?
        public var didStartAutomatically = false
        public var requestCount = 0
        public var failureKind: FailureKind?
        @Presents public var alert: AlertState<Action.Alert>?

        public var isLoading: Bool {
            status == .requestingAuthorization || status == .locating
        }

        public var authorizationMessage: String? {
            status == .authorizationDenied ? "위치 권한이 없어 현재 위치를 확인할 수 없습니다." : nil
        }

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case onDisappear
        case currentLocationButtonTapped
        case authorizationResponse(MapFeatureAuthorization)
        case locationResponse(Result<MapFeatureCoordinate, MapFeatureLocationError>)
        case cameraChanged(MapFeatureCoordinate, span: Double)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable, Sendable {}
    }

    enum CancelID { case location }

    let timeout: Duration

    @Dependency(\.continuousClock) var clock
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.uuid) var uuid

    /// 위치 조회 제한 시간을 지정해 Reducer를 만듭니다.
    ///
    /// - Parameter timeout: 위치 응답을 기다릴 최대 시간입니다.
    public init(
        timeout: Duration = MapFeatureLocationPolicy.compatibilityTimeout
    ) {
        self.timeout = timeout
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didStartAutomatically else { return .none }
                state.didStartAutomatically = true
                return startRequest(&state)

            case .onDisappear:
                if state.isLoading { state.status = .idle }
                return .cancel(id: CancelID.location)

            case .currentLocationButtonTapped:
                return startRequest(&state)

            case let .authorizationResponse(authorization):
                guard state.status == .requestingAuthorization else { return .none }
                guard authorization == .authorized else {
                    state.status = .authorizationDenied
                    return .none
                }
                state.status = .locating
                return locate()

            case let .locationResponse(.success(coordinate)):
                guard state.status == .locating else { return .none }
                guard coordinate.isValid else {
                    fail(&state, error: .invalidCoordinate)
                    return .none
                }
                state.status = .located
                state.cameraCommand = MapFeatureCameraCommand(
                    coordinate: coordinate,
                    commandID: uuid()
                )
                // View가 카메라 명령을 수락한 즉시 중심 상태를 반영하고,
                // 이후 실제 카메라 callback이 사용자 이동 여부를 다시 확정합니다.
                state.currentLocationTarget = coordinate
                state.cameraCoordinate = coordinate
                state.cameraSpan = MapFeatureLocationPolicy.cameraSpan
                state.cameraIsCenteredOnCurrentLocation = true
                return .none

            case let .locationResponse(.failure(error)):
                guard state.isLoading else { return .none }
                fail(&state, error: error)
                return .none

            case let .cameraChanged(coordinate, span):
                state.cameraCoordinate = coordinate
                state.cameraSpan = span
                state.cameraIsCenteredOnCurrentLocation = state.currentLocationTarget.map {
                    Self.isSameCenter($0, coordinate)
                } ?? false
                return .none

            case .alert(.dismiss):
                state.failureKind = nil
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// 진행 중인 요청이 없으면 권한 상태에 따라 위치 요청을 시작합니다.
    ///
    /// - Parameter state: 요청 상태를 갱신할 화면 상태입니다.
    /// - Returns: 권한 요청 또는 위치 조회 effect입니다.
    private func startRequest(
        _ state: inout State
    ) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.requestCount += 1
        state.alert = nil
        state.failureKind = nil

        switch locationClient.authorizationStatus() {
        case .authorized:
            state.status = .locating
            return locate()
        case .denied:
            state.status = .authorizationDenied
            return .none
        case .notDetermined:
            state.status = .requestingAuthorization
            return .run { [locationClient] send in
                await send(.authorizationResponse(try await locationClient.requestAuthorization()))
            } catch: { error, send in
                await send(.locationResponse(.failure(Self.normalized(error))))
            }
            .cancellable(id: CancelID.location, cancelInFlight: true)
        }
    }

    /// 위치 요청과 제한 시간을 경쟁시켜 먼저 끝난 결과를 전달합니다.
    ///
    /// - Returns: 위치 응답을 보내는 취소 가능한 effect입니다.
    private func locate() -> Effect<Action> {
        .run { [locationClient, clock, timeout] send in
            let coordinate = try await withThrowingTaskGroup(of: MapFeatureCoordinate.self) { group in
                group.addTask { try await locationClient.requestLocation() }
                group.addTask {
                    try await clock.sleep(for: timeout)
                    throw MapFeatureLocationError.timedOut
                }
                defer { group.cancelAll() }
                return try await group.next()!
            }
            await send(.locationResponse(.success(coordinate)))
        } catch: { error, send in
            await send(.locationResponse(.failure(Self.normalized(error))))
        }
        .cancellable(id: CancelID.location, cancelInFlight: true)
    }

    /// 실패 상태와 사용자 안내 alert를 설정합니다.
    ///
    /// - Parameters:
    ///   - state: 실패를 반영할 화면 상태입니다.
    ///   - error: 요청을 종료한 오류입니다.
    private func fail(
        _ state: inout State,
        error: MapFeatureLocationError
    ) {
        state.status = .failed
        let kind: State.FailureKind = error == .timedOut ? .timeout : .failure
        state.failureKind = kind
        state.alert = Self.failureAlert(kind)
    }

    /// 위치 조회 실패 종류에 맞는 alert를 만듭니다.
    ///
    /// - Parameter kind: 일반 실패 또는 제한 시간 초과입니다.
    /// - Returns: 확인 버튼 하나를 가진 실패 안내 alert입니다.
    static func failureAlert(
        _ kind: State.FailureKind
    ) -> AlertState<Action.Alert> {
        AlertState {
            TextState("위치 조회 실패")
        } actions: {
            ButtonState(role: .cancel) { TextState("확인") }
        } message: {
            switch kind {
            case .timeout:
                TextState("현재 위치를 확인하는 데 시간이 오래 걸립니다. 다시 시도해 주세요.")
            case .failure:
                TextState("현재 위치를 확인하지 못했습니다. 다시 시도해 주세요.")
            }
        }
    }

    /// 외부 오류를 화면에서 구분하는 위치 오류로 변환합니다.
    ///
    /// - Parameter error: 권한 요청이나 위치 조회가 던진 오류입니다.
    /// - Returns: 정의된 위치 오류이며, 알 수 없는 오류는 `.unavailable`입니다.
    private static func normalized(
        _ error: any Error
    ) -> MapFeatureLocationError {
        error as? MapFeatureLocationError ?? .unavailable
    }

    /// 두 좌표가 허용 오차 안에서 같은 중심인지 확인합니다.
    ///
    /// - Parameters:
    ///   - lhs: 비교할 첫 번째 좌표입니다.
    ///   - rhs: 비교할 두 번째 좌표입니다.
    /// - Returns: 위도와 경도 차이가 모두 허용 오차 이내이면 `true`입니다.
    static func isSameCenter(
        _ lhs: MapFeatureCoordinate,
        _ rhs: MapFeatureCoordinate
    ) -> Bool {
        abs(lhs.latitude - rhs.latitude) <= MapFeatureLocationPolicy.centerTolerance
            && abs(lhs.longitude - rhs.longitude) <= MapFeatureLocationPolicy.centerTolerance
    }
}
