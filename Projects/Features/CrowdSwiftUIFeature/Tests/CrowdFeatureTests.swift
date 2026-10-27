import ComposableArchitecture
import CrowdPresentation
import Domain
import Foundation
import Testing
@testable import CrowdSwiftUIFeature

private let observedAt = Date(timeIntervalSince1970: 1_793_029_500)
private let gwanghwamun = Place(id: "POI009", name: "광화문·덕수궁", category: .heritage)
private let daerim = Place(id: "POI023", name: "대림역", category: .denselyPopulated)
private let catalog = PlaceCatalog(places: [gwanghwamun, daerim], areas: [])

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

private struct TestFailure: Error {}

@MainActor
@Suite("혼잡도 홈")
struct CrowdHomeFeatureTests {
    @Test("화면 등장은 장소 목록과 모든 장소의 혼잡도를 한 번만 불러온다")
    func onAppearLoadsCatalogAndSnapshotsOnce() async {
        let store = TestStore(initialState: CrowdHomeFeature.State()) {
            CrowdHomeFeature()
        } withDependencies: {
            $0.crowdClient.catalog = { catalog }
            $0.crowdClient.snapshot = { id in id == "POI023" ? snapshot(id, .busy, 16_000) : snapshot(id, .relaxed, 7_000) }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) { $0.didStartLoading = true }
        await store.receive(\.catalogResponse.success) { $0.places = catalog.places }
        await store.skipReceivedActions()

        #expect(store.state.snapshots.count == 2)
        #expect(!store.state.isLoading)
        #expect(store.state.topPlaces.map(\.id) == ["POI023", "POI009"])
        #expect(store.state.levelCounts.first { $0.level == .busy }?.count == 1)
        #expect(store.state.latestObservedAt == observedAt)

        await store.send(.onAppear)
    }

    @Test("실패한 장소는 정보 없음으로 세고 다시 불러오기로 재요청한다")
    func failedSnapshotsCanBeRetried() async {
        let shouldFail = LockIsolated(true)
        var state = CrowdHomeFeature.State()
        state.places = catalog.places
        state.didStartLoading = true
        let store = TestStore(initialState: state) {
            CrowdHomeFeature()
        } withDependencies: {
            $0.crowdClient.snapshot = { id in
                if shouldFail.value { throw TestFailure() }
                return snapshot(id, .relaxed, 7_000)
            }
        }

        await store.send(.snapshotResponse("POI009", .failure(TestFailure()))) {
            $0.failedPlaceIDs = ["POI009"]
        }
        #expect(store.state.levelCounts.first { $0.level == .unknown }?.count == 2)

        shouldFail.setValue(false)
        await store.send(.retryTapped) { $0.failedPlaceIDs = [] }
        await store.receive(\.snapshotResponse) {
            $0.snapshots["POI009"] = snapshot("POI009", .relaxed, 7_000)
        }
    }

    @Test("분류를 고르면 요약과 붐비는 순이 그 분류만 계산한다")
    func categoryScopesSummary() async {
        var state = CrowdHomeFeature.State()
        state.places = catalog.places
        state.snapshots = ["POI009": snapshot("POI009", .relaxed, 7_000), "POI023": snapshot("POI023", .busy, 16_000)]
        let store = TestStore(initialState: state) { CrowdHomeFeature() }

        await store.send(.categoryTapped(.heritage)) { $0.category = .heritage }

        #expect(store.state.topPlaces.map(\.id) == ["POI009"])
        #expect(store.state.levelCounts.reduce(0) { $0 + $1.count } == 1)
    }

    @Test("전체 보기는 받은 혼잡도와 선택한 분류로 목록을 연다")
    func showAllPushesList() async {
        var state = CrowdHomeFeature.State()
        state.places = catalog.places
        state.snapshots = ["POI009": snapshot("POI009", .relaxed, 7_000)]
        state.category = .heritage
        let store = TestStore(initialState: state) { CrowdHomeFeature() }

        await store.send(.showAllTapped) {
            $0.path[id: 0] = .list(PlaceListFeature.State(
                places: catalog.places,
                snapshots: ["POI009": snapshot("POI009", .relaxed, 7_000)],
                category: .heritage
            ))
        }
    }

    @Test("목록이 열린 뒤 도착한 혼잡도도 목록에 반영한다")
    func lateSnapshotUpdatesOpenList() async {
        var state = CrowdHomeFeature.State()
        state.places = catalog.places
        state.path.append(.list(PlaceListFeature.State(places: catalog.places, snapshots: [:])))
        let store = TestStore(initialState: state) { CrowdHomeFeature() }

        await store.send(.snapshotResponse("POI023", .success(snapshot("POI023", .busy, 16_000)))) {
            $0.snapshots["POI023"] = snapshot("POI023", .busy, 16_000)
            $0.path[id: 0, case: \.list]?.snapshots["POI023"] = snapshot("POI023", .busy, 16_000)
        }
    }

    @Test("지도·시트·목록에서 고른 장소는 상세를 열고 모르는 코드는 무시한다")
    func placeSelectionOpensDetail() async {
        var state = CrowdHomeFeature.State()
        state.places = catalog.places
        state.snapshots = ["POI023": snapshot("POI023", .busy, 16_000)]
        state.path.append(.list(PlaceListFeature.State(places: catalog.places, snapshots: state.snapshots)))
        let store = TestStore(initialState: state) { CrowdHomeFeature() }

        await store.send(.placeTapped("MOCK-1"))
        await store.send(.path(.element(id: 0, action: .list(.delegate(.openDetail("POI023")))))) {
            $0.path[id: 1] = .detail(PlaceDetailFeature.State(place: daerim, snapshot: snapshot("POI023", .busy, 16_000)))
        }
    }

    @Test("요약 문구는 가장 붐비는 단계를 기준으로 만든다")
    func summaryTextUsesBusiestLevel() {
        let counts: ([CongestionLevel: Int]) -> [CrowdRanking.LevelCount] = { values in
            [.relaxed, .normal, .busy, .crowded, .unknown].map { CrowdRanking.LevelCount(level: $0, count: values[$0] ?? 0) }
        }
        #expect(CrowdSummaryText.make(counts: counts([.relaxed: 120, .busy: 1]), isLoading: false, loadedCount: 121, totalCount: 121, catalogError: nil) == "대부분 한산해요. 1곳이 약간 붐벼요.")
        #expect(CrowdSummaryText.make(counts: counts([.crowded: 2]), isLoading: false, loadedCount: 2, totalCount: 2, catalogError: nil) == "붐비는 곳이 2곳 있어요.")
        #expect(CrowdSummaryText.make(counts: counts([:]), isLoading: true, loadedCount: 3, totalCount: 121, catalogError: nil) == "혼잡도를 불러오는 중이에요 (3/121)")
    }
}

@MainActor
@Suite("장소 목록")
struct PlaceListFeatureTests {
    @Test("분류, 검색, 정렬을 적용하고 정보 없는 장소는 뒤에 둔다")
    func filtersSearchesAndSorts() async {
        let ojeong = Place(id: "POI044", name: "오목교역·목동운동장", category: .denselyPopulated)
        let store = TestStore(initialState: PlaceListFeature.State(
            places: [gwanghwamun, daerim, ojeong],
            snapshots: ["POI023": snapshot("POI023", .busy, 16_000), "POI044": snapshot("POI044", .relaxed, 64_000)]
        )) { PlaceListFeature() }

        #expect(store.state.visiblePlaces.map(\.id) == ["POI023", "POI044", "POI009"])
        await store.send(.sortToggled) { $0.sort = .population }
        #expect(store.state.visiblePlaces.map(\.id) == ["POI044", "POI023", "POI009"])
        await store.send(.categoryTapped(.heritage)) { $0.category = .heritage }
        #expect(store.state.visiblePlaces.map(\.id) == ["POI009"])
        await store.send(.categoryTapped(nil)) { $0.category = nil }
        await store.send(.binding(.set(\.searchText, "대림"))) { $0.searchText = "대림" }
        #expect(store.state.visiblePlaces.map(\.id) == ["POI023"])
        await store.send(.placeTapped("POI023"))
        await store.receive(\.delegate)
    }
}

@MainActor
@Suite("장소 상세")
struct PlaceDetailFeatureTests {
    @Test("상세를 불러오면 혼잡도도 상세 기준으로 바꾼다")
    func loadsDetail() async {
        let detail = CrowdPreviewData.detail
        let store = TestStore(initialState: PlaceDetailFeature.State(place: gwanghwamun)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.crowdClient.detail = { _ in detail }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.detailResponse.success) {
            $0.isLoading = false
            $0.detail = detail
            $0.snapshot = detail.snapshot
        }
        await store.send(.onAppear)
    }

    @Test("실패하면 안내를 보여 주고 다시 시도할 수 있다")
    func failureCanBeRetried() async {
        let shouldFail = LockIsolated(true)
        let store = TestStore(initialState: PlaceDetailFeature.State(place: gwanghwamun)) {
            PlaceDetailFeature()
        } withDependencies: {
            $0.crowdClient.detail = { _ in
                if shouldFail.value { throw TestFailure() }
                return CrowdPreviewData.detail
            }
        }

        await store.send(.onAppear) { $0.isLoading = true }
        await store.receive(\.detailResponse.failure) {
            $0.isLoading = false
            $0.errorMessage = "상세 정보를 불러오지 못했어요."
        }
        shouldFail.setValue(false)
        await store.send(.retryTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.receive(\.detailResponse.success) {
            $0.isLoading = false
            $0.detail = CrowdPreviewData.detail
            $0.snapshot = CrowdPreviewData.detail.snapshot
        }
    }

    @Test("승하차 비교로 모이는지 빠지는지 정한다")
    func flowInsight() throws {
        let flow = try #require(CrowdPreviewData.detail.transitFlow)
        #expect(PlaceInsight.flow(flow) == .leaving)
        let gathering = TransitFlow(
            subwayStationCount: 1,
            subwayBoarding: PopulationRange(minimum: 100, maximum: 100),
            subwayAlighting: PopulationRange(minimum: 500, maximum: 500),
            busStopCount: 0,
            busBoarding: nil,
            busAlighting: nil
        )
        #expect(PlaceInsight.flow(gathering) == .gathering)
    }

    @Test("가장 한산한 예측 시간을 찾는다")
    func quietestForecast() throws {
        let quietest = try #require(PlaceInsight.quietest(CrowdPreviewData.detail.snapshot.forecasts))
        #expect(quietest.population?.minimum == 2_000)
    }
}
