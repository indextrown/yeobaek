import Domain
import Foundation

public enum BundledPlaceRepositoryError: Error, Equatable, Sendable {
    case resourceNotFound
}

/// 앱에 포함한 서울시 주요 121장소 영역 GeoJSON을 읽는 저장소입니다.
///
/// 원본: 서울 열린데이터광장 `서울시 주요 121장소 영역.zip`, `서울시 주요 121장소 목록.xlsx`
public struct BundledPlaceRepository: PlaceRepository {
    private let data: @Sendable () throws -> Data

    /// Data 모듈 번들의 `SeoulPlaces.geojson`을 읽는 저장소를 만듭니다.
    public init() {
        self.init {
            guard let url = Bundle.module.url(forResource: "SeoulPlaces", withExtension: "geojson") else {
                throw BundledPlaceRepositoryError.resourceNotFound
            }
            return try Data(contentsOf: url)
        }
    }

    /// 테스트에서 GeoJSON 원문을 주입할 수 있게 저장소를 만듭니다.
    ///
    /// - Parameter data: GeoJSON 원문을 반환하는 클로저입니다.
    init(
        data: @escaping @Sendable () throws -> Data
    ) {
        self.data = data
    }

    /// GeoJSON을 장소와 경계로 변환합니다.
    ///
    /// - Returns: 장소 코드 순서의 장소와 경계입니다.
    /// - Throws: 자료가 없거나 형식이 올바르지 않으면 발생하는 오류입니다.
    public func fetchCatalog() async throws -> PlaceCatalog {
        try loadCatalog()
    }

    /// 앱 시작 조립처럼 비동기 문맥이 아닌 곳에서 GeoJSON을 바로 읽습니다.
    ///
    /// - Returns: 장소 코드 순서의 장소와 경계입니다.
    /// - Throws: 자료가 없거나 형식이 올바르지 않으면 발생하는 오류입니다.
    public func loadCatalog() throws -> PlaceCatalog {
        let collection = try JSONDecoder().decode(PlaceFeatureCollection.self, from: data())
        var places: [Place] = []
        var areas: [AreaGeometry] = []
        for feature in collection.features {
            let properties = feature.properties
            places.append(Place(
                id: properties.code,
                name: properties.name,
                category: PlaceCategory(rawValue: properties.category),
                labelCoordinate: properties.label.count == 2
                    ? GeoCoordinate(latitude: properties.label[1], longitude: properties.label[0])
                    : nil
            ))
            areas.append(AreaGeometry(placeID: properties.code, polygons: feature.geometry.polygons))
        }
        return PlaceCatalog(places: places, areas: areas)
    }
}

private struct PlaceFeatureCollection: Decodable {
    let features: [PlaceFeature]
}

private struct PlaceFeature: Decodable {
    let properties: Properties
    let geometry: Geometry

    struct Properties: Decodable {
        let code: String
        let name: String
        let category: String
        let label: [Double]
    }

    /// `Polygon`과 `MultiPolygon`만 지원합니다. 좌표 순서는 GeoJSON 표준의 [경도, 위도]입니다.
    struct Geometry: Decodable {
        let polygons: [GeoPolygon]

        /// GeoJSON 도형을 Domain 다각형 목록으로 디코딩합니다.
        ///
        /// - Parameter decoder: geometry 객체를 읽는 디코더입니다.
        /// - Throws: 지원하지 않는 도형이거나 좌표 형식이 올바르지 않으면 디코딩 오류가 발생합니다.
        init(
            from decoder: Decoder
        ) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            let rawPolygons: [[[[Double]]]]
            switch type {
            case "Polygon":
                rawPolygons = [try container.decode([[[Double]]].self, forKey: .coordinates)]
            case "MultiPolygon":
                rawPolygons = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "지원하지 않는 도형입니다: \(type)"
                )
            }
            polygons = rawPolygons.compactMap { rings in
                let coordinates = rings.map { ring in
                    ring.compactMap { point in
                        point.count >= 2 ? GeoCoordinate(latitude: point[1], longitude: point[0]) : nil
                    }
                }
                guard let exterior = coordinates.first else { return nil }
                return GeoPolygon(exteriorRing: exterior, interiorRings: Array(coordinates.dropFirst()))
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case coordinates
        }
    }
}
