import ComposableArchitecture
import Domain
import Foundation

/// 지도 위 홈 시트와 목록·상세 이동을 관리하는 Reducer입니다.
///
/// 장소 121곳의 혼잡도를 한 번 받아 단계별 분포와 붐비는 순서를 보여 주고,
/// 받은 결과를 목록 화면에도 그대로 전달합니다.
@Reducer
public struct CrowdHomeFeature {
    @Reducer(state: .equatable, .sendable, action: .sendable)
    public enum Path {
        case list(PlaceListFeature)
        case detail(PlaceDetailFeature)
    }

    @ObservableState
    public struct State: Equatable {
        public var places: [Place] = []
        public var snapshots: [Place.ID: CrowdSnapshot] = [:]
        public var failedPlaceIDs: Set<Place.ID> = []
        public var category: PlaceCategory?
        public var didStartLoading = false
        public var catalogErrorMessage: String?
        public var path = StackState<Path.State>()

        /// 선택한 분류에 속한 장소입니다.
        var scopedPlaces: [Place] {
            places.filter { category == nil || $0.category == category }
        }

        /// 아직 응답이 오지 않은 장소가 있으면 `true`입니다.
        public var isLoading: Bool {
            didStartLoading && catalogErrorMessage == nil
                && snapshots.count + failedPlaceIDs.count < places.count
        }

        /// 단계별 장소 수입니다.
        var levelCounts: [CrowdRanking.LevelCount] {
            CrowdRanking.counts(scopedPlaces, snapshots: snapshots)
        }

        /// 혼잡도를 받은 장소를 붐비는 순서로 정렬한 목록입니다.
        var rankedPlaces: [Place] {
            CrowdRanking.sorted(scopedPlaces, snapshots: snapshots, by: .crowding)
                .filter { snapshots[$0.id] != nil }
        }

        /// 지금 붐비는 순서로 세 곳입니다.
        var topPlaces: [Place] {
            Array(rankedPlaces.prefix(3))
        }

        /// 받은 혼잡도 중 가장 최근 원천 데이터 기준 시각입니다.
        public var latestObservedAt: Date? {
            snapshots.values.map(\.observedAt).max()
        }

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case catalogResponse(Result<PlaceCatalog, any Error>)
        case snapshotResponse(Place.ID, Result<CrowdSnapshot, any Error>)
        case categoryTapped(PlaceCategory?)
        case searchTapped
        case showAllTapped
        case placeTapped(Place.ID)
        case retryTapped
        case path(StackActionOf<Path>)
    }

    @Dependency(\.crowdClient) var crowdClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didStartLoading else { return .none }
                state.didStartLoading = true
                return .run { [crowdClient] send in
                    await send(.catalogResponse(Result { try await crowdClient.catalog() }))
                }

            case let .catalogResponse(.success(catalog)):
                state.places = catalog.places
                return loadSnapshots(for: catalog.places.map(\.id))

            case .catalogResponse(.failure):
                state.catalogErrorMessage = "장소 목록을 읽지 못했어요."
                return .none

            case let .snapshotResponse(placeID, .success(snapshot)):
                state.snapshots[placeID] = snapshot
                state.failedPlaceIDs.remove(placeID)
                for id in state.path.ids {
                    state.path[id: id, case: \.list]?.snapshots[placeID] = snapshot
                }
                return .none

            case let .snapshotResponse(placeID, .failure):
                state.failedPlaceIDs.insert(placeID)
                return .none

            case let .categoryTapped(category):
                state.category = category
                return .none

            case .searchTapped, .showAllTapped:
                state.path.append(.list(PlaceListFeature.State(
                    places: state.places,
                    snapshots: state.snapshots,
                    category: state.category
                )))
                return .none

            case let .placeTapped(placeID):
                openDetail(placeID, in: &state)
                return .none

            case .retryTapped:
                let failed = Array(state.failedPlaceIDs)
                state.failedPlaceIDs = []
                return loadSnapshots(for: failed)

            case let .path(.element(_, action: .list(.delegate(.openDetail(placeID))))):
                openDetail(placeID, in: &state)
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    /// 장소 상세 화면을 엽니다. 목록에 없는 장소 코드는 무시합니다.
    ///
    /// - Parameters:
    ///   - placeID: 열 장소 코드입니다.
    ///   - state: 이동 경로를 바꿀 화면 상태입니다.
    private func openDetail(
        _ placeID: Place.ID,
        in state: inout State
    ) {
        guard let place = state.places.first(where: { $0.id == placeID }) else { return }
        state.path.append(.detail(PlaceDetailFeature.State(place: place, snapshot: state.snapshots[placeID])))
    }

    /// 장소마다 혼잡도를 요청합니다. 동시 요청 수와 캐시는 저장소가 관리합니다.
    ///
    /// - Parameter placeIDs: 요청할 장소 코드입니다.
    /// - Returns: 장소별 응답을 보내는 effect입니다.
    private func loadSnapshots(
        for placeIDs: [Place.ID]
    ) -> Effect<Action> {
        guard !placeIDs.isEmpty else { return .none }
        return .run { [crowdClient] send in
            await withTaskGroup(of: Void.self) { group in
                for placeID in placeIDs {
                    group.addTask {
                        await send(.snapshotResponse(placeID, Result { try await crowdClient.snapshot(placeID) }))
                    }
                }
            }
        }
    }
}
