import ComposableArchitecture
import CrowdPresentation
import Domain

/// 121곳을 분류, 검색, 정렬로 살펴보는 목록 화면입니다.
@Reducer
public struct PlaceListFeature {
    @ObservableState
    public struct State: Equatable {
        public var places: [Place]
        public var snapshots: [Place.ID: CrowdSnapshot]
        public var category: PlaceCategory?
        var sort: CrowdRanking.Sort = .crowding
        public var searchText = ""

        /// 분류와 검색어를 적용하고 정렬한 장소입니다.
        var visiblePlaces: [Place] {
            let keyword = searchText.trimmingCharacters(in: .whitespaces)
            let filtered = places.filter { place in
                (category == nil || place.category == category)
                    && (keyword.isEmpty || place.name.localizedStandardContains(keyword))
            }
            return CrowdRanking.sorted(filtered, snapshots: snapshots, by: sort)
        }

        /// 목록 상태를 만듭니다.
        ///
        /// - Parameters:
        ///   - places: 표시할 장소입니다.
        ///   - snapshots: 장소 코드별 혼잡도입니다.
        ///   - category: 처음 선택할 분류입니다. `nil`이면 전체입니다.
        public init(
            places: [Place],
            snapshots: [Place.ID: CrowdSnapshot],
            category: PlaceCategory? = nil
        ) {
            self.places = places
            self.snapshots = snapshots
            self.category = category
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case categoryTapped(PlaceCategory?)
        case sortToggled
        case placeTapped(Place.ID)
        case delegate(Delegate)

        public enum Delegate: Equatable, Sendable {
            case openDetail(Place.ID)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .categoryTapped(category):
                state.category = category
                return .none

            case .sortToggled:
                state.sort = state.sort == .crowding ? .population : .crowding
                return .none

            case let .placeTapped(placeID):
                return .send(.delegate(.openDetail(placeID)))

            case .delegate:
                return .none
            }
        }
    }
}
