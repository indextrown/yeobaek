import ComposableArchitecture
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
                state.errorMessage = "상세 정보를 불러오지 못했어요."
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

/// 상세 화면이 원천 값으로 계산하는 표시 규칙입니다.
enum PlaceInsight {
    /// 최근 30분 대중교통 승하차로 본 사람 흐름입니다.
    enum Flow: Equatable, Sendable {
        /// 내리는 사람이 타는 사람보다 20% 넘게 많습니다.
        case gathering
        /// 타는 사람이 내리는 사람보다 20% 넘게 많습니다.
        case leaving
        /// 차이가 작습니다.
        case steady
    }

    /// 지하철과 버스의 승하차 합계를 비교합니다.
    ///
    /// - Parameter flow: 최근 30분 승하차 인원입니다.
    /// - Returns: 흐름이며, 승하차 정보가 없으면 `nil`입니다.
    static func flow(
        _ flow: TransitFlow
    ) -> Flow? {
        let boarding = CrowdFormat.midpoint(flow.subwayBoarding) + CrowdFormat.midpoint(flow.busBoarding)
        let alighting = CrowdFormat.midpoint(flow.subwayAlighting) + CrowdFormat.midpoint(flow.busAlighting)
        guard boarding + alighting > 0 else { return nil }
        if alighting > boarding * 1.2 { return .gathering }
        if boarding > alighting * 1.2 { return .leaving }
        return .steady
    }

    /// 예측 중 인구가 가장 적은 시간대를 찾습니다. 같으면 더 이른 시간입니다.
    ///
    /// - Parameter forecasts: 시간 순서의 예측입니다.
    /// - Returns: 가장 한산한 예측이며, 인구 정보가 없으면 `nil`입니다.
    static func quietest(
        _ forecasts: [CrowdForecast]
    ) -> CrowdForecast? {
        forecasts
            .filter { $0.population != nil }
            .min { CrowdFormat.midpoint($0.population) < CrowdFormat.midpoint($1.population) }
    }
}
