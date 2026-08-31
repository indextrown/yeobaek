public struct AreaGeometry: Equatable, Sendable {
    public let placeID: Place.ID
    public let polygons: [GeoPolygon]

    /// 장소 코드와 해당 장소의 경계를 구성하는 다각형을 연결합니다.
    ///
    /// - Parameters:
    ///   - placeID: 경계가 속한 장소의 고유 코드입니다.
    ///   - polygons: 장소 영역을 구성하는 다각형 목록입니다. 서로 떨어진 영역도 포함할 수 있습니다.
    public init(
        placeID: Place.ID,
        polygons: [GeoPolygon]
    ) {
        self.placeID = placeID
        self.polygons = polygons
    }
}

/// 장소 영역 자료의 닫힌 경계입니다. 내부 경계는 영역에서 제외되는 빈 공간을 나타냅니다.
public struct GeoPolygon: Equatable, Sendable {
    public let exteriorRing: [GeoCoordinate]
    public let interiorRings: [[GeoCoordinate]]

    /// 다각형의 외곽 경계와 내부에서 제외할 영역을 저장합니다.
    ///
    /// - Parameters:
    ///   - exteriorRing: 닫힌 외곽 경계를 순서대로 구성하는 좌표입니다.
    ///   - interiorRings: 내부에서 제외할 영역의 닫힌 경계 목록입니다. 빈 배열이면 제외 영역이 없습니다.
    public init(
        exteriorRing: [GeoCoordinate],
        interiorRings: [[GeoCoordinate]] = []
    ) {
        self.exteriorRing = exteriorRing
        self.interiorRings = interiorRings
    }
}
