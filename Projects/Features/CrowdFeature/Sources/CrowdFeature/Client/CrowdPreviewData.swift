import Domain
import Foundation

/// SwiftUI Preview와 테스트에서 쓰는 예시 값입니다.
///
/// 2026-10-26 서울 실시간 도시데이터 실제 응답에서 가져온 값입니다.
enum CrowdPreviewData {
    static let observedAt = Date(timeIntervalSince1970: 1_793_029_500)

    static let catalog = PlaceCatalog(
        places: [
            Place(id: "POI009", name: "광화문·덕수궁", category: .heritage),
            Place(id: "POI023", name: "대림역", category: .denselyPopulated),
            Place(id: "POI044", name: "오목교역·목동운동장", category: .denselyPopulated),
            Place(id: "POI007", name: "홍대 관광특구", category: .touristZone),
            Place(id: "POI068", name: "성수카페거리", category: .commercialDistrict),
            Place(id: "POI091", name: "남산공원", category: .park),
        ],
        areas: []
    )

    static let snapshots: [Place.ID: CrowdSnapshot] = [
        "POI009": snapshot("POI009", .relaxed, 7_000, 7_500),
        "POI023": snapshot("POI023", .busy, 16_000, 18_000),
        "POI044": snapshot("POI044", .relaxed, 64_000, 66_000),
        "POI007": snapshot("POI007", .relaxed, 44_000, 46_000),
        "POI068": snapshot("POI068", .relaxed, 12_000, 14_000),
        "POI091": snapshot("POI091", .relaxed, 5_500, 6_000),
    ]

    static let detail = PlaceDetail(
        placeID: "POI009",
        snapshot: CrowdSnapshot(
            placeID: "POI009",
            level: .relaxed,
            population: PopulationRange(minimum: 20_000, maximum: 22_000),
            message: "사람이 몰려있을 가능성이 낮고 붐빔은 거의 느껴지지 않아요. 도보 이동이 자유로워요.",
            observedAt: observedAt,
            forecasts: [16_000, 10_000, 6_500, 4_500, 3_000, 2_500, 2_000, 2_500, 2_500, 3_000, 5_000, 10_000]
                .enumerated()
                .map { index, minimum in
                    CrowdForecast(
                        time: observedAt.addingTimeInterval(Double(index + 1) * 3_600),
                        level: .relaxed,
                        population: PopulationRange(minimum: minimum, maximum: minimum + 1_000)
                    )
                }
        ),
        demographics: PlaceDemographics(
            maleRate: 51.5,
            femaleRate: 48.5,
            ageRates: zip(stride(from: 0, through: 70, by: 10), [0.6, 2.7, 19.8, 23.2, 23.9, 18.5, 8.0, 3.2])
                .map { PlaceDemographics.AgeRate(decade: $0, rate: $1) },
            nonResidentRate: 77.9
        ),
        transitFlow: TransitFlow(
            subwayStationCount: 4,
            subwayBoarding: PopulationRange(minimum: 4_600, maximum: 4_700),
            subwayAlighting: PopulationRange(minimum: 750, maximum: 800),
            busStopCount: 41,
            busBoarding: PopulationRange(minimum: 1_000, maximum: 1_100),
            busAlighting: PopulationRange(minimum: 450, maximum: 500)
        ),
        commerce: CommerceSummary(
            activity: "분주한",
            categories: [
                .init(name: "일식/중식/양식", activity: "분주한"),
                .init(name: "기타요식", activity: "바쁜"),
                .init(name: "한식", activity: "보통"),
            ]
        ),
        subwayArrivals: [
            SubwayArrival(stationName: "경복궁", line: "3호선", direction: "오금행 - 안국방면", message: "경복궁 진입"),
            SubwayArrival(stationName: "경복궁", line: "3호선", direction: "대화행 - 독립문방면", message: "전역 출발"),
        ],
        roadStatus: "서행",
        parkingLotCount: 29,
        weather: WeatherSummary(
            temperature: 17.4,
            sky: "구름많음",
            precipitationMessage: "비 또는 눈 소식이 없어요.",
            fineDust: "좋음",
            ultraFineDust: "좋음"
        ),
        events: [
            PlaceEvent(name: "[세종문화회관] 에너미", period: "2026-10-26~2026-11-14", venue: "세종문화회관 세종M씨어터", url: nil),
        ]
    )

    /// 예시 혼잡도를 만듭니다.
    ///
    /// - Parameters:
    ///   - placeID: 장소 코드입니다.
    ///   - level: 혼잡도 단계입니다.
    ///   - minimum: 최소 인원입니다.
    ///   - maximum: 최대 인원입니다.
    /// - Returns: 예시 혼잡도입니다.
    private static func snapshot(
        _ placeID: Place.ID,
        _ level: CongestionLevel,
        _ minimum: Int,
        _ maximum: Int
    ) -> CrowdSnapshot {
        CrowdSnapshot(
            placeID: placeID,
            level: level,
            population: PopulationRange(minimum: minimum, maximum: maximum),
            observedAt: observedAt
        )
    }
}
