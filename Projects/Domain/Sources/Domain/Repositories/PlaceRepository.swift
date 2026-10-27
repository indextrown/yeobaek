/// 장소 목록과 각 장소의 경계를 함께 담은 값입니다.
public struct PlaceCatalog: Equatable, Sendable {
    public let places: [Place]
    public let areas: [AreaGeometry]

    /// 같은 장소 코드로 연결되는 장소와 경계를 저장합니다.
    ///
    /// - Parameters:
    ///   - places: 화면에 표시할 장소 목록입니다.
    ///   - areas: 장소 코드로 연결되는 경계 목록입니다.
    public init(
        places: [Place],
        areas: [AreaGeometry]
    ) {
        self.places = places
        self.areas = areas
    }
}

public protocol PlaceRepository: Sendable {
    /// 혼잡도를 제공하는 장소와 경계를 조회합니다.
    ///
    /// - Returns: 장소 목록과 경계입니다.
    /// - Throws: 장소 자료를 읽지 못하면 발생하는 오류입니다.
    func fetchCatalog() async throws -> PlaceCatalog
}

public protocol PlaceDetailRepository: Sendable {
    /// 장소 상세 화면에 필요한 실시간 정보를 조회합니다.
    ///
    /// - Parameter placeID: 조회할 장소의 고유 코드입니다.
    /// - Returns: 혼잡도, 교통, 상권, 날씨, 행사를 포함한 상세 정보입니다.
    /// - Throws: 조회에 실패하거나 요청이 취소되면 발생하는 오류입니다.
    func fetchDetail(
        for placeID: Place.ID
    ) async throws -> PlaceDetail
}
