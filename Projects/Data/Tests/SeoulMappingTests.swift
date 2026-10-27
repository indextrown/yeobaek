import Domain
import Foundation
import Testing
@testable import Data

@Suite("서울 실시간 응답 변환")
struct SeoulMappingTests {
    @Test("실시간 인구 응답은 혼잡도, 인구 범위와 12시간 예측으로 바뀐다")
    func populationResponseMapsSnapshotAndForecasts() throws {
        let response = try JSONDecoder().decode(
            SeoulPopulationResponseDTO.self,
            from: Fixture.data("citydata_ppltn-POI001")
        )

        let snapshot = try #require(try response.toDomain().first)

        #expect(snapshot.placeID == "POI001")
        #expect(snapshot.level == .relaxed)
        #expect(snapshot.population == PopulationRange(minimum: 3_500, maximum: 4_000))
        #expect(snapshot.forecasts.count == 12)
        #expect(snapshot.forecasts == snapshot.forecasts.sorted { $0.time < $1.time })
    }

    @Test("오류 응답은 API 오류 코드로 실패한다")
    func errorResponseThrowsAPIError() throws {
        let response = try JSONDecoder().decode(
            SeoulPopulationResponseDTO.self,
            from: Fixture.data("citydata_ppltn-error")
        )

        #expect(throws: SeoulPopulationMappingError.self) {
            try response.toDomain()
        }
    }

    @Test("실시간 통합 응답은 장소 상세의 모든 묶음으로 바뀐다")
    func cityDataResponseMapsDetail() throws {
        let response = try JSONDecoder().decode(
            SeoulCityDataResponseDTO.self,
            from: Fixture.data("citydata-POI009")
        )

        let detail = try response.toDomain()

        #expect(detail.placeID == "POI009")
        #expect(detail.snapshot.population == PopulationRange(minimum: 20_000, maximum: 22_000))
        #expect(detail.snapshot.forecasts.count == 12)
        #expect(detail.demographics?.maleRate == 51.5)
        #expect(detail.demographics?.ageRates.count == 8)
        #expect(detail.demographics?.nonResidentRate == 77.9)
        #expect(detail.transitFlow?.subwayStationCount == 4)
        #expect(detail.transitFlow?.subwayBoarding == PopulationRange(minimum: 4_600, maximum: 4_700))
        #expect(detail.transitFlow?.busAlighting == PopulationRange(minimum: 450, maximum: 500))
        #expect(detail.commerce?.activity == "분주한")
        #expect(detail.commerce?.categories.isEmpty == false)
        #expect(detail.subwayArrivals.first?.stationName == "경복궁")
        #expect(detail.roadStatus == "서행")
        #expect(detail.parkingLotCount == 29)
        #expect(detail.weather?.temperature == 17.4)
        #expect(detail.weather?.fineDust == "좋음")
        #expect(detail.events.count == 15)
    }
}

@Suite("번들 장소 저장소")
struct BundledPlaceRepositoryTests {
    @Test("서울시 주요 121장소와 경계를 공식 분류로 읽는다")
    func catalogContainsAllPlacesWithCategories() async throws {
        let catalog = try await BundledPlaceRepository().fetchCatalog()

        #expect(catalog.places.count == 121)
        #expect(catalog.areas.count == 121)
        #expect(catalog.places.allSatisfy { $0.category != nil && $0.labelCoordinate != nil })
        #expect(catalog.areas.allSatisfy { !$0.polygons.isEmpty })

        let gwanghwamun = try #require(catalog.places.first { $0.id == "POI009" })
        #expect(gwanghwamun.name == "광화문·덕수궁")
        #expect(gwanghwamun.category == .heritage)
        #expect(catalog.places.filter { $0.category == .denselyPopulated }.count == 48)
    }
}

enum Fixture {
    /// 테스트 번들의 JSON 응답을 읽습니다.
    ///
    /// - Parameter name: 확장자를 뺀 파일 이름입니다.
    /// - Returns: 파일 내용입니다.
    /// - Throws: 파일이 없으면 오류가 발생합니다.
    static func data(
        _ name: String
    ) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
