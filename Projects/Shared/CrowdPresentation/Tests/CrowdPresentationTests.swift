import Domain
import Foundation
import Testing
@testable import CrowdPresentation

private let observedAt = Date(timeIntervalSince1970: 1_793_029_500)
private let gwanghwamun = Place(id: "POI009", name: "광화문·덕수궁", category: .heritage)
private let daerim = Place(id: "POI023", name: "대림역", category: .denselyPopulated)
private let ojeong = Place(id: "POI044", name: "오목교역·목동운동장", category: .denselyPopulated)

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

@Suite("혼잡도 화면 공통 규칙")
struct CrowdPresentationTests {
    private let snapshots = [
        "POI023": snapshot("POI023", .busy, 16_000),
        "POI044": snapshot("POI044", .relaxed, 64_000),
    ]

    @Test("붐비는 순은 단계, 인구 순이고 정보 없는 장소는 뒤에 둔다")
    func crowdingSortPutsUnknownLast() {
        let sorted = CrowdRanking.sorted([gwanghwamun, daerim, ojeong], snapshots: snapshots, by: .crowding)
        #expect(sorted.map(\.id) == ["POI023", "POI044", "POI009"])
        let byPopulation = CrowdRanking.sorted([gwanghwamun, daerim, ojeong], snapshots: snapshots, by: .population)
        #expect(byPopulation.map(\.id) == ["POI044", "POI023", "POI009"])
    }

    @Test("받지 못한 장소는 정보 없음으로 센다")
    func countsTreatMissingAsUnknown() {
        let counts = CrowdRanking.counts([gwanghwamun, daerim, ojeong], snapshots: snapshots)
        #expect(counts.map(\.level) == [.relaxed, .normal, .busy, .crowded, .unknown])
        #expect(counts.map(\.count) == [1, 0, 1, 0, 1])
    }

    @Test("요약 문구는 가장 붐비는 단계를 기준으로 만든다")
    func summaryUsesBusiestLevel() {
        let counts = CrowdRanking.counts([gwanghwamun, daerim, ojeong], snapshots: snapshots)
        #expect(CrowdSummaryText.make(counts: counts, isLoading: false, loadedCount: 2, totalCount: 3, catalogError: nil) == "대부분 한산해요. 1곳이 약간 붐벼요.")
        #expect(CrowdSummaryText.make(counts: counts, isLoading: true, loadedCount: 2, totalCount: 3, catalogError: nil) == "혼잡도를 불러오는 중이에요 (2/3)")
        #expect(CrowdSummaryText.make(counts: counts, isLoading: false, loadedCount: 0, totalCount: 3, catalogError: CrowdCopy.catalogFailed) == CrowdCopy.catalogFailed)
    }

    @Test("타는 사람이 20% 넘게 많으면 빠지는 중, 내리는 사람이 많으면 모이는 중이다")
    func flowInsight() {
        let leaving = TransitFlow(
            subwayStationCount: 4,
            subwayBoarding: PopulationRange(minimum: 4_600, maximum: 4_700),
            subwayAlighting: PopulationRange(minimum: 750, maximum: 800),
            busStopCount: 0,
            busBoarding: nil,
            busAlighting: nil
        )
        #expect(PlaceInsight.flow(leaving) == .leaving)
        #expect(CrowdCopy.flowBadge(.leaving) == "빠지는 중")
        let empty = TransitFlow(subwayStationCount: 0, subwayBoarding: nil, subwayAlighting: nil, busStopCount: 0, busBoarding: nil, busAlighting: nil)
        #expect(PlaceInsight.flow(empty) == nil)
    }

    @Test("가장 한산한 예측은 인구 가운데 값이 가장 작은 이른 시간이다")
    func quietestForecast() throws {
        let forecasts = [3_000, 1_000, 1_000, 5_000].enumerated().map { index, minimum in
            CrowdForecast(
                time: observedAt.addingTimeInterval(Double(index + 1) * 3_600),
                level: .relaxed,
                population: PopulationRange(minimum: minimum, maximum: minimum + 500)
            )
        }
        let quietest = try #require(PlaceInsight.quietest(forecasts))
        #expect(quietest.time == forecasts[1].time)
    }

    @Test("표시 문구는 두 화면 구현이 같은 형식을 쓴다")
    func copyFormats() {
        #expect(CrowdFormat.population(PopulationRange(minimum: 16_000, maximum: 18_000)) == "16,000~18,000명")
        #expect(CrowdFormat.population(nil) == "정보 없음")
        #expect(CrowdCopy.placeSubtitle(daerim, snapshot: snapshots["POI023"]) == "인구밀집지역 · 추정 16,000~18,000명")
        #expect(CrowdCopy.placeSubtitle(gwanghwamun, snapshot: nil) == "고궁·문화유산 · 불러오는 중")
        #expect(CrowdCopy.homeTitle(category: nil, placeCount: 121) == "서울 주요 121곳")
        #expect(CrowdCopy.homeTitle(category: .park, placeCount: 121) == "공원")
        #expect(CrowdCopy.ageTitle(0) == "10세 미만")
        #expect(CrowdCopy.percent(23.24) == "23.2%")
    }

    @Test("시트 버튼 여백은 기본 높이까지만 따라간다")
    func sheetControlsInset() {
        #expect(CrowdSheetLayout.controlsInset(forSheetHeight: CrowdSheetLayout.collapsedHeight) == CrowdSheetLayout.collapsedHeight + 16)
        #expect(CrowdSheetLayout.controlsInset(forSheetHeight: 600) == CrowdSheetLayout.mediumHeight + 16)
    }
}
