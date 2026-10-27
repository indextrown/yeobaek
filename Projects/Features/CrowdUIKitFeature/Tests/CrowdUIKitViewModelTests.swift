import CrowdPresentation
import Domain
import Foundation
import Testing
@testable import CrowdUIKitFeature

private let observedAt = Date(timeIntervalSince1970: 1_793_029_500)
private let gwanghwamun = Place(id: "POI009", name: "광화문·덕수궁", category: .heritage)
private let daerim = Place(id: "POI023", name: "대림역", category: .denselyPopulated)

/// 테스트용 혼잡도를 만듭니다.
///
/// - Parameters:
///   - placeID: 장소 코드입니다.
///   - level: 혼잡도 단계입니다.
///   - minimum: 최소 인원입니다.
/// - Returns: 최대 인원이 최소보다 2,000명 많은 혼잡도입니다.
private func snapshot(
    _ placeID: Place.ID,
    _ level: CongestionLevel,
    _ minimum: Int
) -> CrowdSnapshot {
    CrowdSnapshot(
        placeID: placeID,
        level: level,
        population: PopulationRange(minimum: minimum, maximum: minimum + 2_000),
        observedAt: observedAt
    )
}

private struct StubPlaces: PlaceRepository {
    func fetchCatalog() async throws -> PlaceCatalog {
        PlaceCatalog(places: [gwanghwamun, daerim], areas: [])
    }
}

private struct StubCrowd: CrowdRepository {
    func fetchSnapshot(
        for placeID: Place.ID
    ) async throws -> CrowdSnapshot {
        guard placeID == "POI023" else { throw CrowdRepositoryError.unavailable }
        return snapshot(placeID, .busy, 16_000)
    }
}

@MainActor
@Suite("UIKit 버전 상태와 ViewModel")
struct CrowdUIKitViewModelTests {
    @Test("상태 저장소는 장소 목록과 혼잡도를 불러오고 실패한 장소를 기록한다")
    func storeLoadsCatalogAndSnapshots() async throws {
        let store = CrowdSnapshotStore(placeRepository: StubPlaces(), crowdRepository: StubCrowd())
        store.loadIfNeeded()
        for _ in 0..<100 where store.currentState.isLoading || store.currentState.places.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.currentState.places.map(\.id) == ["POI009", "POI023"])
        #expect(store.currentState.snapshots["POI023"]?.level == .busy)
        #expect(store.currentState.failedPlaceIDs == ["POI009"])
    }

    @Test("홈 표시 데이터는 SwiftUI 버전과 같은 제목, 요약, 순서를 만든다")
    func homeViewDataMatchesSharedRules() {
        var state = CrowdSnapshotStore.State()
        state.places = [gwanghwamun, daerim]
        state.snapshots = ["POI023": snapshot("POI023", .busy, 16_000), "POI009": snapshot("POI009", .relaxed, 7_000)]
        state.didStartLoading = true

        let data = CrowdHomeViewModel.viewData(state: state, category: nil)

        #expect(data.title == "서울 주요 2곳")
        #expect(data.summary == "대부분 한산해요. 1곳이 약간 붐벼요.")
        #expect(data.rankedRows.map(\.id) == ["POI023", "POI009"])
        #expect(data.freshness == CrowdCopy.freshness(observedAt))

        let heritage = CrowdHomeViewModel.viewData(state: state, category: .heritage)
        #expect(heritage.title == "고궁·문화유산")
        #expect(heritage.rankedRows.map(\.id) == ["POI009"])
    }

    @Test("목록 표시 데이터는 분류, 검색, 정렬을 적용한다")
    func listViewDataFiltersAndSorts() {
        var state = CrowdSnapshotStore.State()
        state.places = [gwanghwamun, daerim]
        state.snapshots = ["POI023": snapshot("POI023", .busy, 16_000), "POI009": snapshot("POI009", .relaxed, 70_000)]

        let crowding = PlaceListViewModel.viewData(state: state, category: nil, search: "", sort: .crowding)
        #expect(crowding.rows.map(\.id) == ["POI023", "POI009"])
        #expect(crowding.countText == "2곳")
        #expect(crowding.searchPlaceholder == "2곳 중에서 찾기")

        let population = PlaceListViewModel.viewData(state: state, category: nil, search: "", sort: .population)
        #expect(population.rows.map(\.id) == ["POI009", "POI023"])
        #expect(population.sortTitle == "인구 많은 순")

        let searched = PlaceListViewModel.viewData(state: state, category: nil, search: "대림", sort: .crowding)
        #expect(searched.rows.map(\.id) == ["POI023"])
    }
}
