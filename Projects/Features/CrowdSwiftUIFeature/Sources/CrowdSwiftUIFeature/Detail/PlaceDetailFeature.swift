import ComposableArchitecture
import CrowdPresentation
import Domain
import Foundation

/// 장소 하나의 현재 혼잡도, 예측, 흐름, 주변 정보를 보여 주는 상세 화면입니다.
@Reducer
public struct PlaceDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public let place: Place
        /// 목록에서 이미 받은 혼잡도입니다. 상세를 받기 전에도 맨 위 요약을 보여 줍니다.
        public var snapshot: CrowdSnapshot?
        public var detail: PlaceDetail?
        public var isLoading = false
        public var errorMessage: String?

        /// 상세 상태를 만듭니다.
        ///
        /// - Parameters:
        ///   - place: 보여 줄 장소입니다.
        ///   - snapshot: 이미 받은 혼잡도입니다. 없으면 `nil`입니다.
        public init(
            place: Place,
            snapshot: CrowdSnapshot? = nil
        ) {
            self.place = place
            self.snapshot = snapshot
        }
    }

    public enum Action: Sendable {
        case onAppear
        case retryTapped
        case detailResponse(Result<PlaceDetail, any Error>)
    }

    @Dependency(\.crowdClient) var crowdClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.detail == nil, !state.isLoading else { return .none }
                return load(&state)

            case .retryTapped:
                return load(&state)

            case let .detailResponse(.success(detail)):
                state.isLoading = false
                state.errorMessage = nil
                state.detail = detail
                state.snapshot = detail.snapshot
                return .none

            case .detailResponse(.failure):
                state.isLoading = false
                state.errorMessage = CrowdCopy.detailFailed
                return .none
            }
        }
    }

    /// 상세 조회를 시작합니다.
    ///
    /// - Parameter state: 조회 상태를 바꿀 화면 상태입니다.
    /// - Returns: 상세 응답을 보내는 effect입니다.
    private func load(
        _ state: inout State
    ) -> Effect<Action> {
        state.isLoading = true
        state.errorMessage = nil
        let placeID = state.place.id
        return .run { [crowdClient] send in
            await send(.detailResponse(Result { try await crowdClient.detail(placeID) }))
        }
    }
}
